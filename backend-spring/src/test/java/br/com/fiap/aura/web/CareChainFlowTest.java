package br.com.fiap.aura.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.ArrayList;
import java.util.List;
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
 * Percurso completo do produto: cadastro → consentimento → casa → sinal →
 * escore explicável → recomendação → aprovação → pedido entregue.
 * Cobre também o gate LGPD e o isolamento entre pacientes.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
class CareChainFlowTest {

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper json;

    private String signup(String email) throws Exception {
        MvcResult res = mvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"aura1234","role":"cuidadora"}""".formatted(email)))
                .andExpect(status().isCreated())
                .andReturn();
        return json.readTree(res.getResponse().getContentAsString()).get("token").asText();
    }

    private JsonNode body(MvcResult res) throws Exception {
        return json.readTree(res.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8));
    }

    /** Cuidadora consentida com uma casa da Maria — o ponto de partida de quase todo caso. */
    private String homeOf(String auth) throws Exception {
        mvc.perform(post("/api/v1/consent").header("Authorization", auth)).andExpect(status().isCreated());
        return body(mvc.perform(post("/api/v1/homes").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"patientName":"Maria S.","cep":"01310100","label":"Casa da Maria"}"""))
                .andExpect(status().isCreated())
                .andReturn()).get("homeId").asText();
    }

    private List<String> texts(JsonNode array) {
        List<String> out = new ArrayList<>();
        array.forEach(node -> out.add(node.asText()));
        return out;
    }

    @Test
    @DisplayName("fluxo ponta a ponta: risco explicado vira pedido entregue no prazo")
    void endToEnd() throws Exception {
        String token = signup("fluxo@aura.com");
        String auth = "Bearer " + token;

        // sem consentimento, nenhum dado de saúde entra (RN-001)
        mvc.perform(post("/api/v1/homes").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"patientName":"Maria S.","cep":"01310100","label":"Casa da Maria"}"""))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.error.code").value("CONSENT_REQUIRED"));

        mvc.perform(post("/api/v1/consent").header("Authorization", auth))
                .andExpect(status().isCreated());

        String homeId = body(mvc.perform(post("/api/v1/homes").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"patientName":"Maria S.","cep":"01310100","label":"Casa da Maria"}"""))
                .andExpect(status().isCreated())
                .andReturn()).get("homeId").asText();

        // a casa não tem barra de apoio nem piso anti-derrapante
        mvc.perform(put("/api/v1/homes/{id}/checklist", homeId).header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"items":{"grab_bar_bathroom":false,"anti_slip_floor":false}}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.safetyChecklist.anti_slip_floor").value(false));

        // Maria relata uma quase-queda por voz
        mvc.perform(post("/api/v1/signals").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s","type":"mobility","source":"voice",
                                 "value":{"event":"near_fall","place":"bathroom"}}""".formatted(homeId)))
                .andExpect(status().isCreated());

        JsonNode score = body(mvc.perform(post("/api/v1/scores/recompute").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s","dimension":"mobility"}""".formatted(homeId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.level").value("high"))
                .andReturn());

        assertThat(score.get("factors").toString()).contains("near_fall_reported", "no_grab_bar");
        assertThat(score.get("explanation").asText()).contains("NBR 9050");

        JsonNode rec = body(mvc.perform(post("/api/v1/recommendations").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s","scoreId":"%s"}"""
                                .formatted(homeId, score.get("scoreId").asText())))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.sku").value("LM-1566953614"))
                .andReturn());

        // nada de pedido antes da aprovação humana (RN-022)
        mvc.perform(get("/api/v1/homes/{id}/orders", homeId).header("Authorization", auth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));

        String recId = rec.get("recommendationId").asText();
        String orderId = body(mvc.perform(post("/api/v1/recommendations/{id}/approve", recId)
                        .header("Authorization", auth))
                        .andExpect(status().isCreated())
                        .andExpect(jsonPath("$.stage").value("approved"))
                        .andReturn())
                .get("orderId").asText();

        // aprovar de novo é conflito
        mvc.perform(post("/api/v1/recommendations/{id}/approve", recId).header("Authorization", auth))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.error.code").value("CONFLICT"));

        for (String expected : new String[] {"sourcing", "in_route", "delivered"}) {
            mvc.perform(post("/api/v1/orders/{id}/advance", orderId).header("Authorization", auth))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.stage").value(expected));
        }

        mvc.perform(get("/api/v1/orders/{id}", orderId).header("Authorization", auth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stage").value("delivered"))
                .andExpect(jsonPath("$.sla.breached").value(false))
                .andExpect(jsonPath("$.delivery.nodeName").value("Loja Marginal"));
    }

    @Test
    @DisplayName("o pedido devolve a rota da entrega em GeoJSON LineString e a duração estimada (G3)")
    void deliveryRouteAndDuration() throws Exception {
        String auth = "Bearer " + signup("mapa@aura.com");
        mvc.perform(post("/api/v1/consent").header("Authorization", auth)).andExpect(status().isCreated());

        JsonNode home = body(mvc.perform(post("/api/v1/homes").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"patientName":"Maria S.","cep":"01310100","label":"Casa da Maria"}"""))
                .andExpect(status().isCreated())
                .andReturn());

        String recId = body(mvc.perform(post("/api/v1/recommendations").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s"}""".formatted(home.get("homeId").asText())))
                .andExpect(status().isCreated())
                .andReturn()).get("recommendationId").asText();

        String orderId = body(mvc.perform(post("/api/v1/recommendations/{id}/approve", recId)
                        .header("Authorization", auth))
                .andExpect(status().isCreated())
                .andReturn()).get("orderId").asText();

        JsonNode delivery = body(mvc.perform(get("/api/v1/orders/{id}", orderId).header("Authorization", auth))
                        .andExpect(status().isOk())
                        .andExpect(jsonPath("$.delivery.route.type").value("LineString"))
                        .andReturn())
                .get("delivery");

        assertThat(delivery.get("durationS").asInt()).isPositive();

        JsonNode coordinates = delivery.get("route").get("coordinates");
        assertThat(coordinates.size()).isBetween(5, 8);

        // GeoJSON é [lng, lat]: em São Paulo a longitude fica na casa dos -46 e a latitude na dos -23
        for (JsonNode point : coordinates) {
            assertThat(point.size()).isEqualTo(2);
            assertThat(point.get(0).asDouble()).isBetween(-47.0, -46.0);
            assertThat(point.get(1).asDouble()).isBetween(-24.0, -23.0);
        }

        // o cliente lê o primeiro ponto como o nó logístico e o último como a casa
        JsonNode destination = coordinates.get(coordinates.size() - 1);
        assertThat(destination.get(0).asDouble()).isEqualTo(home.get("lng").asDouble());
        assertThat(destination.get(1).asDouble()).isEqualTo(home.get("lat").asDouble());
        assertThat(coordinates.get(0).get(0).asDouble()).isNotEqualTo(home.get("lng").asDouble());
    }

    @Test
    @DisplayName("a recomendação chega com preço, instalação, norma e os fatores em português (C1)")
    void recommendationCarriesPriceInstallationAndLabels() throws Exception {
        String auth = "Bearer " + signup("contrato@aura.com");
        String homeId = homeOf(auth);

        mvc.perform(put("/api/v1/homes/{id}/checklist", homeId).header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"items":{"grab_bar_bathroom":false,"anti_slip_floor":true}}"""))
                .andExpect(status().isOk());

        mvc.perform(post("/api/v1/signals").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s","type":"mobility","source":"voice",
                                 "value":{"event":"near_fall"}}""".formatted(homeId)))
                .andExpect(status().isCreated());

        JsonNode score = body(mvc.perform(post("/api/v1/scores/recompute").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s","dimension":"mobility"}""".formatted(homeId)))
                .andExpect(status().isOk())
                .andReturn());

        assertThat(texts(score.get("factorLabels")))
                .containsExactly("quase-queda relatada", "ausência de barra de apoio");

        JsonNode rec = body(mvc.perform(post("/api/v1/recommendations").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s","scoreId":"%s"}"""
                                .formatted(homeId, score.get("scoreId").asText())))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.price").value(129.90))
                .andExpect(jsonPath("$.installable").value(true))
                .andExpect(jsonPath("$.installationIncluded").value(false))
                .andExpect(jsonPath("$.installationPrice").value(149.90))
                .andExpect(jsonPath("$.normRef").value("NBR 9050"))
                .andReturn());

        // listas paralelas: um rótulo por fator, na mesma ordem — nenhuma tela traduz código
        assertThat(rec.get("factorLabels").size()).isEqualTo(rec.get("factors").size());
        assertThat(texts(rec.get("factorLabels")))
                .containsExactly("quase-queda relatada", "ausência de barra de apoio");
        assertThat(rec.get("reason").asText())
                .isEqualTo("Recomendamos Kit 2 Barras de Apoio 60cm porque houve quase-queda relatada "
                        + "e ausência de barra de apoio (NBR 9050).");

        // a listagem da casa devolve o mesmo contrato do POST — a tela não precisa de segunda fonte
        mvc.perform(get("/api/v1/homes/{id}/recommendations", homeId).header("Authorization", auth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].price").value(129.90))
                .andExpect(jsonPath("$[0].installationPrice").value(149.90))
                .andExpect(jsonPath("$[0].factorLabels[0]").value("quase-queda relatada"));
    }

    @Test
    @DisplayName("sem scoreId a recomendação continua coerente e a frase degrada sem fator solto (C1)")
    void recommendationWithoutScoreDegrades() throws Exception {
        String auth = "Bearer " + signup("semescore@aura.com");
        String homeId = homeOf(auth);

        JsonNode rec = body(mvc.perform(post("/api/v1/recommendations").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s"}""".formatted(homeId)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.factors.length()").value(0))
                .andExpect(jsonPath("$.factorLabels.length()").value(0))
                .andExpect(jsonPath("$.price").value(129.90))
                .andExpect(jsonPath("$.installable").value(true))
                .andExpect(jsonPath("$.normRef").value("NBR 9050"))
                .andReturn());

        // sem fator não há o que compor: sobra a frase curta inteira, nunca um "porque houve ." solto
        assertThat(rec.get("reason").asText())
                .isEqualTo("Kit 2 Barras de Apoio 60cm reduz risco de queda/acidente (NBR 9050).")
                .doesNotContain("porque houve");
    }

    @Test
    @DisplayName("casa de outra cuidadora responde 403, não 404 (RN-017)")
    void isolationBetweenPatients() throws Exception {
        String owner = "Bearer " + signup("dona@aura.com");
        String stranger = "Bearer " + signup("estranha@aura.com");

        mvc.perform(post("/api/v1/consent").header("Authorization", owner)).andExpect(status().isCreated());
        String homeId = body(mvc.perform(post("/api/v1/homes").header("Authorization", owner)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"patientName":"Maria S.","cep":"01310100"}"""))
                .andReturn()).get("homeId").asText();

        mvc.perform(get("/api/v1/homes/{id}", homeId).header("Authorization", stranger))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
    }

    @Test
    @DisplayName("sem token: 401 no envelope padrão; a Torre de Controle exige admin")
    void authAndRbac() throws Exception {
        mvc.perform(get("/api/v1/catalog"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));

        String cuidadora = "Bearer " + signup("semops@aura.com");
        mvc.perform(get("/api/v1/ops/kpis").header("Authorization", cuidadora))
                .andExpect(status().isForbidden());

        MvcResult login = mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"admin@aura.com","password":"aura1234"}"""))
                .andExpect(status().isOk())
                .andReturn();
        String adminToken = body(login).get("token").asText();

        mvc.perform(get("/api/v1/ops/kpis").header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fillRate").value(1.0));
    }

    @Test
    @DisplayName("validação de payload devolve VALIDATION_ERROR com o campo culpado")
    void validation() throws Exception {
        mvc.perform(post("/api/v1/auth/signup").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"nao-e-email","password":"123"}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.error.details.password").exists());
    }

    @Test
    @DisplayName("exclusão LGPD: apaga a casa com seus dados e a conta do titular")
    void lgpdDeletion() throws Exception {
        String auth = "Bearer " + signup("apagar@aura.com");
        mvc.perform(post("/api/v1/consent").header("Authorization", auth)).andExpect(status().isCreated());

        String homeId = body(mvc.perform(post("/api/v1/homes").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"patientName":"Maria S.","cep":"01310100"}"""))
                .andReturn()).get("homeId").asText();

        mvc.perform(post("/api/v1/signals").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s","type":"mobility","source":"voice",
                                 "value":{"event":"near_fall"}}""".formatted(homeId)))
                .andExpect(status().isCreated());

        mvc.perform(delete("/api/v1/homes/{id}", homeId).header("Authorization", auth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ok").value(true));

        // a casa some de verdade, e com ela os sinais observados
        mvc.perform(get("/api/v1/homes/{id}", homeId).header("Authorization", auth))
                .andExpect(status().isNotFound());

        mvc.perform(delete("/api/v1/auth/me").header("Authorization", auth))
                .andExpect(status().isOk());

        // sem conta, não há login
        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"apagar@aura.com","password":"aura1234"}"""))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    @DisplayName("página de status (Thymeleaf) e health respondem sem autenticação")
    void publicSurfaces() throws Exception {
        mvc.perform(get("/api/v1/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ok"));

        mvc.perform(get("/"))
                .andExpect(status().isOk())
                .andExpect(result -> assertThat(result.getResponse().getContentAsString())
                        .contains("AURA Care-Chain API", "Swagger"));
    }
}
