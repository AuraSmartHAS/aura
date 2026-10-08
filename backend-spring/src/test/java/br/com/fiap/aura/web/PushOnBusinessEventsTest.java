package br.com.fiap.aura.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.fiap.aura.domain.HomeMember;
import br.com.fiap.aura.domain.Signal;
import br.com.fiap.aura.domain.enums.HomeMemberRole;
import br.com.fiap.aura.domain.enums.SignalSource;
import br.com.fiap.aura.domain.enums.SignalType;
import br.com.fiap.aura.repository.HomeMemberRepository;
import br.com.fiap.aura.repository.SignalRepository;
import br.com.fiap.aura.service.FcmService;
import br.com.fiap.aura.web.error.ApiException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.SpyBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

/**
 * Pushes por evento de negócio: pedido que avança e recomendação nova avisam o dono da casa —
 * depois do commit, sem fator clínico no texto, sem avisar quem acabou de agir e sem que uma
 * falha do FCM desfaça a ação.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
class PushOnBusinessEventsTest {

    private static final String[] FATORES_CLINICOS = {
        "queda", "risco", "banheiro", "barra", "Parkinson", "escore", "remédio", "medicamento", "Levodopa"
    };

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper json;

    @Autowired
    private HomeMemberRepository members;

    @Autowired
    private SignalRepository signals;

    /** Espião: o transporte continua simulado (sem credencial), mas cada envio é contado. */
    @SpyBean
    private FcmService fcm;

    @BeforeEach
    void limpaInvocacoes() {
        clearInvocations(fcm);
    }

    @AfterEach
    void restauraTransporte() {
        reset(fcm);
    }

    // ------------------------------------------------------------------ apoio

    private JsonNode body(MvcResult res) throws Exception {
        return json.readTree(res.getResponse().getContentAsString(StandardCharsets.UTF_8));
    }

    private record Conta(String auth, UUID userId) { }

    private Conta signup(String email) throws Exception {
        JsonNode res = body(mvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"aura1234","role":"cuidadora","name":"Ana"}"""
                                .formatted(email)))
                .andExpect(status().isCreated())
                .andReturn());
        String auth = "Bearer " + res.get("token").asText();
        mvc.perform(post("/api/v1/consent").header("Authorization", auth)).andExpect(status().isCreated());
        return new Conta(auth, UUID.fromString(res.get("userId").asText()));
    }

    private String adminAuth() throws Exception {
        return "Bearer " + body(mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"admin@aura.com\",\"password\":\"aura1234\"}"))
                .andExpect(status().isOk())
                .andReturn()).get("token").asText();
    }

    private String casaDe(String auth) throws Exception {
        return body(mvc.perform(post("/api/v1/homes").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"patientName":"Maria S.","cep":"01310100","label":"Casa da Maria"}"""))
                .andExpect(status().isCreated())
                .andReturn()).get("homeId").asText();
    }

    private void registraAparelho(String auth, String token) throws Exception {
        mvc.perform(post("/api/v1/notifications/register-token").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"fcmToken":"%s"}""".formatted(token)))
                .andExpect(status().isOk());
    }

    private Conta membroDa(String homeId, String email) throws Exception {
        Conta membro = signup(email);
        members.save(HomeMember.builder().homeId(UUID.fromString(homeId)).userId(membro.userId())
                .role(HomeMemberRole.CUIDADORA).build());
        return membro;
    }

    private String recomenda(String auth, String homeId) throws Exception {
        return body(mvc.perform(post("/api/v1/recommendations").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s"}""".formatted(homeId)))
                .andExpect(status().isCreated())
                .andReturn()).get("recommendationId").asText();
    }

    private String aprova(String auth, String recId) throws Exception {
        return body(mvc.perform(post("/api/v1/recommendations/{id}/approve", recId).header("Authorization", auth))
                .andExpect(status().isCreated())
                .andReturn()).get("orderId").asText();
    }

    private List<FcmService.PushMessage> avisosEnviados(int quantos) {
        ArgumentCaptor<FcmService.PushMessage> captor = ArgumentCaptor.forClass(FcmService.PushMessage.class);
        verify(fcm, times(quantos)).send(captor.capture());
        return captor.getAllValues();
    }

    private static void semFatorClinico(FcmService.PushMessage aviso) {
        for (String fator : FATORES_CLINICOS) {
            assertThat(aviso.title()).doesNotContainIgnoringCase(fator);
            assertThat(aviso.body()).doesNotContainIgnoringCase(fator);
        }
    }

    // ------------------------------------------------------------------ testes

    @Test
    @DisplayName("admin avança o pedido: o dono recebe ORDER com o pedido no deep link")
    void avancoDoPedidoAvisaODono() throws Exception {
        Conta ana = signup("push-evento-pedido@aura.com");
        String homeId = casaDe(ana.auth());
        registraAparelho(ana.auth(), "token-da-ana-pedido");
        String orderId = aprova(ana.auth(), recomenda(ana.auth(), homeId));
        clearInvocations(fcm);

        mvc.perform(post("/api/v1/orders/{id}/advance", orderId).header("Authorization", adminAuth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stage").value("sourcing"));

        FcmService.PushMessage aviso = avisosEnviados(1).get(0);
        assertThat(aviso.deviceToken()).isEqualTo("token-da-ana-pedido");
        assertThat(aviso.highPriority()).isFalse();
        assertThat(aviso.data())
                .containsEntry("kind", "order")
                .containsEntry("homeId", homeId)
                .containsEntry("orderId", orderId)
                .containsEntry("stage", "sourcing");
        assertThat(aviso.body()).isEqualTo("O pedido da casa da Maria está sendo separado. Toque para acompanhar.");
        semFatorClinico(aviso);
    }

    @Test
    @DisplayName("FCM recusando o aviso não desfaz o avanço do pedido")
    void falhaDoFcmNaoDesfazAAcao() throws Exception {
        Conta ana = signup("push-evento-falha@aura.com");
        String homeId = casaDe(ana.auth());
        registraAparelho(ana.auth(), "token-revogado-da-ana");
        String orderId = aprova(ana.auth(), recomenda(ana.auth(), homeId));
        doThrow(ApiException.unprocessable("PUSH_FAILED", "token revogado")).when(fcm).send(any());

        mvc.perform(post("/api/v1/orders/{id}/advance", orderId).header("Authorization", adminAuth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stage").value("sourcing"));

        mvc.perform(get("/api/v1/orders/{id}", orderId).header("Authorization", ana.auth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stage").value("sourcing"));
    }

    @Test
    @DisplayName("quem age não recebe aviso da própria ação; outro membro da casa gera aviso ao dono")
    void recomendacaoNovaAvisaODonoSoQuandoOutroAgiu() throws Exception {
        Conta ana = signup("push-evento-rec-dona@aura.com");
        String homeId = casaDe(ana.auth());
        registraAparelho(ana.auth(), "token-da-ana-recomendacao");

        // a própria Ana pede: ela já está vendo a recomendação na tela
        recomenda(ana.auth(), homeId);
        verify(fcm, never()).send(any());

        // a recomendação pendente do mesmo item é reaproveitada: nada nasce, nada avisa
        Conta bruno = membroDa(homeId, "push-evento-rec-bruno@aura.com");
        recomenda(bruno.auth(), homeId);
        verify(fcm, never()).send(any());
    }

    @Test
    @DisplayName("reposição materializada pela régua avisa o dono uma vez, com a recomendação no deep link")
    void reposicaoAvisaUmaVezPorItem() throws Exception {
        Conta ana = signup("push-evento-repo@aura.com");
        String homeId = casaDe(ana.auth());
        registraAparelho(ana.auth(), "token-da-ana-reposicao");
        String medId = body(mvc.perform(post("/api/v1/homes/{homeId}/medications", homeId)
                        .header("Authorization", ana.auth())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Levodopa e Carbidopa","schedule":["08:00","20:00"],"stockDoses":8}"""))
                .andExpect(status().isCreated())
                .andReturn()).get("id").asText();
        for (int d = 21; d >= 1; d--) {
            for (int i = 0; i < 2; i++) {
                Map<String, Object> value = new LinkedHashMap<>();
                value.put("medicationId", medId);
                value.put("taken", true);
                signals.save(Signal.builder().homeId(UUID.fromString(homeId)).type(SignalType.ADHERENCE)
                        .source(SignalSource.SELF_REPORT).value(value)
                        .capturedAt(Instant.now().minus(d, ChronoUnit.DAYS).plus(i, ChronoUnit.HOURS))
                        .build());
            }
        }
        Conta bruno = membroDa(homeId, "push-evento-repo-bruno@aura.com");
        clearInvocations(fcm);

        String recId = body(mvc.perform(post("/api/v1/homes/{homeId}/replenishment/check", homeId)
                        .header("Authorization", bruno.auth()))
                .andExpect(status().isOk())
                .andReturn()).get(0).get("recommendationId").asText();

        FcmService.PushMessage aviso = avisosEnviados(1).get(0);
        assertThat(aviso.deviceToken()).isEqualTo("token-da-ana-reposicao");
        assertThat(aviso.data())
                .containsEntry("kind", "recommendation")
                .containsEntry("homeId", homeId)
                .containsEntry("recommendationId", recId);
        semFatorClinico(aviso);

        // o check seguinte reaproveita a pendente: nenhum aviso novo
        mvc.perform(post("/api/v1/homes/{homeId}/replenishment/check", homeId).header("Authorization", bruno.auth()))
                .andExpect(status().isOk());
        // recusada, a régua adia; mesmo que renascesse, o período por item segura o segundo aviso
        mvc.perform(post("/api/v1/recommendations/{id}/reject", recId).header("Authorization", ana.auth()))
                .andExpect(status().isOk());
        mvc.perform(post("/api/v1/homes/{homeId}/replenishment/check", homeId).header("Authorization", bruno.auth()))
                .andExpect(status().isOk());
        verify(fcm, times(1)).send(any());
    }
}
