package br.com.fiap.aura.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.fiap.aura.domain.Recommendation;
import br.com.fiap.aura.repository.RecommendationRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

/**
 * O motor de recomendação conhece os pedidos: item já pedido não é recomendado de novo, e a
 * aprovação não cria um segundo pedido para o que já está a caminho. Item durável (barra, piso)
 * fica "em andamento" até a instalação — entregue e não instalado, o risco continua de pé.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
class OrderInFlightTest {

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper json;

    @Autowired
    private RecommendationRepository recommendations;

    private JsonNode body(MvcResult res) throws Exception {
        return json.readTree(res.getResponse().getContentAsString(StandardCharsets.UTF_8));
    }

    private String signup(String email) throws Exception {
        MvcResult res = mvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"aura1234","role":"cuidadora"}""".formatted(email)))
                .andExpect(status().isCreated())
                .andReturn();
        return "Bearer " + body(res).get("token").asText();
    }

    private String adminAuth() throws Exception {
        MvcResult res = mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"admin@aura.com\",\"password\":\"aura1234\"}"))
                .andExpect(status().isOk())
                .andReturn();
        return "Bearer " + body(res).get("token").asText();
    }

    /** Cuidadora consentida com casa: o chão do cenário. Devolve {auth, homeId}. */
    private String[] cuidadoraComCasa(String email) throws Exception {
        String auth = signup(email);
        mvc.perform(post("/api/v1/consent").header("Authorization", auth)).andExpect(status().isCreated());
        String homeId = body(mvc.perform(post("/api/v1/homes").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"patientName":"Maria S.","cep":"01310100","label":"Casa da Maria"}"""))
                .andExpect(status().isCreated())
                .andReturn()).get("homeId").asText();
        return new String[] {auth, homeId};
    }

    private JsonNode recomenda(String auth, String homeId) throws Exception {
        return body(mvc.perform(post("/api/v1/recommendations").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"homeId\":\"%s\"}".formatted(homeId)))
                .andExpect(status().isCreated())
                .andReturn());
    }

    private String aprova(String auth, String recId) throws Exception {
        return body(mvc.perform(post("/api/v1/recommendations/{id}/approve", recId).header("Authorization", auth))
                .andExpect(status().isCreated())
                .andReturn()).get("orderId").asText();
    }

    private void avanca(String orderId, int vezes) throws Exception {
        String admin = adminAuth();
        for (int i = 0; i < vezes; i++) {
            mvc.perform(post("/api/v1/orders/{id}/advance", orderId).header("Authorization", admin))
                    .andExpect(status().isOk());
        }
    }

    private JsonNode lista(String auth, String homeId) throws Exception {
        return body(mvc.perform(get("/api/v1/homes/{id}/recommendations", homeId).header("Authorization", auth))
                .andExpect(status().isOk())
                .andReturn());
    }

    @Test
    @DisplayName("pedir a recomendação do mesmo risco duas vezes devolve a mesma, não duas")
    void recomendarEIdempotente() throws Exception {
        String[] ana = cuidadoraComCasa("inflight-idem@aura.com");

        JsonNode primeira = recomenda(ana[0], ana[1]);
        JsonNode segunda = recomenda(ana[0], ana[1]);

        assertThat(segunda.get("recommendationId").asText()).isEqualTo(primeira.get("recommendationId").asText());
        assertThat(segunda.get("status").asText()).isEqualTo("recommended");
        assertThat(lista(ana[0], ana[1])).hasSize(1);
    }

    @Test
    @DisplayName("item pedido: recomendar de novo devolve a aprovada com o pedido, sem criar outra")
    void itemJaPedidoNaoEhRecomendadoDeNovo() throws Exception {
        String[] ana = cuidadoraComCasa("inflight-pedido@aura.com");
        JsonNode rec = recomenda(ana[0], ana[1]);
        String orderId = aprova(ana[0], rec.get("recommendationId").asText());

        JsonNode denovo = recomenda(ana[0], ana[1]);

        assertThat(denovo.get("recommendationId").asText()).isEqualTo(rec.get("recommendationId").asText());
        assertThat(denovo.get("status").asText()).isEqualTo("approved");
        assertThat(denovo.get("orderInProgress").get("orderId").asText()).isEqualTo(orderId);
        assertThat(denovo.get("orderInProgress").get("stage").asText()).isEqualTo("approved");

        JsonNode todas = lista(ana[0], ana[1]);
        assertThat(todas).hasSize(1);
        assertThat(todas.get(0).get("orderInProgress").get("orderId").asText()).isEqualTo(orderId);
    }

    @Test
    @DisplayName("durável fica em andamento até a instalação: entregue ainda bloqueia, instalado libera")
    void duravelSoLiberaNaInstalacao() throws Exception {
        String[] ana = cuidadoraComCasa("inflight-duravel@aura.com");
        JsonNode rec = recomenda(ana[0], ana[1]);
        String orderId = aprova(ana[0], rec.get("recommendationId").asText());

        avanca(orderId, 3); // sourcing, in_route, delivered
        JsonNode entregue = recomenda(ana[0], ana[1]);
        assertThat(entregue.get("recommendationId").asText()).isEqualTo(rec.get("recommendationId").asText());
        assertThat(entregue.get("orderInProgress").get("stage").asText()).isEqualTo("delivered");

        avanca(orderId, 1); // installed
        JsonNode livre = recomenda(ana[0], ana[1]);
        assertThat(livre.get("recommendationId").asText()).isNotEqualTo(rec.get("recommendationId").asText());
        assertThat(livre.get("status").asText()).isEqualTo("recommended");
        assertThat(livre.get("orderInProgress").isNull()).isTrue();
    }

    @Test
    @DisplayName("aprovar o que já está a caminho é 409 ORDER_IN_PROGRESS e não cria segundo pedido")
    void aprovacaoDuplicadaEhBarrada() throws Exception {
        String[] ana = cuidadoraComCasa("inflight-409@aura.com");
        JsonNode rec = recomenda(ana[0], ana[1]);
        String orderId = aprova(ana[0], rec.get("recommendationId").asText());

        // tela antiga / segundo aparelho: uma recomendação aberta do mesmo item que ainda não sabia do pedido
        Recommendation velha = recommendations.save(Recommendation.builder()
                .homeId(UUID.fromString(ana[1])).sku(rec.get("sku").asText())
                .reason("Recomendação anterior ao pedido.").build());

        MvcResult res = mvc.perform(post("/api/v1/recommendations/{id}/approve", velha.getId())
                        .header("Authorization", ana[0]))
                .andExpect(status().isConflict())
                .andReturn();

        JsonNode erro = body(res).get("error");
        assertThat(erro.get("code").asText()).isEqualTo("ORDER_IN_PROGRESS");
        assertThat(erro.get("details").get("orderId").asText()).isEqualTo(orderId);
        assertThat(body(mvc.perform(get("/api/v1/homes/{id}/orders", ana[1]).header("Authorization", ana[0]))
                .andReturn())).hasSize(1);
    }

    @Test
    @DisplayName("ao aprovar, as outras pendentes do mesmo item ficam obsoletas e saem da lista")
    void aprovarAposentaAsPendentesDuplicadas() throws Exception {
        String[] ana = cuidadoraComCasa("inflight-limpeza@aura.com");
        JsonNode rec = recomenda(ana[0], ana[1]);
        Recommendation duplicada = recommendations.save(Recommendation.builder()
                .homeId(UUID.fromString(ana[1])).sku(rec.get("sku").asText())
                .reason("Duplicada de antes da regra.").build());

        aprova(ana[0], rec.get("recommendationId").asText());

        JsonNode todas = lista(ana[0], ana[1]);
        assertThat(todas).hasSize(1);
        assertThat(todas.get(0).get("recommendationId").asText()).isEqualTo(rec.get("recommendationId").asText());
        assertThat(recommendations.findById(duplicada.getId()).orElseThrow().getStatus()).isEqualTo("superseded");

        // e a obsoleta não pode ser aprovada depois que o pedido terminar
        mvc.perform(post("/api/v1/recommendations/{id}/approve", duplicada.getId()).header("Authorization", ana[0]))
                .andExpect(status().isConflict());
    }
}
