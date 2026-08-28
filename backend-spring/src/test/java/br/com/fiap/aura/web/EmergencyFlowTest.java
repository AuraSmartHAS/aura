package br.com.fiap.aura.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.fiap.aura.domain.HomeMember;
import br.com.fiap.aura.domain.enums.HomeMemberRole;
import br.com.fiap.aura.repository.EmergencyRepository;
import br.com.fiap.aura.repository.HomeMemberRepository;
import br.com.fiap.aura.service.EmergencyService;
import br.com.fiap.aura.service.FcmService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.UUID;
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
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

/**
 * SOS e fluxo de crise (C3) — o contrato inteiro, de forma determinística.
 *
 * <p><b>Por que a janela vale 3600s aqui:</b> nenhum teste desta classe pode depender de o relógio
 * de parede cruzar a janela no meio da execução. Com uma hora de janela, o disparo automático
 * <i>nunca</i> acontece por trás do teste, e os testes que precisam do disparo chamam
 * {@link EmergencyService#dispatchIfDue} — que é <b>exatamente</b> o método que o cronômetro do
 * servidor chama, não um caminho paralelo escrito para o teste. Que o cronômetro de verdade esteja
 * ligado e use os 5 segundos de produção é o que {@code EmergencySchedulerTest} prova, com relógio
 * real.
 *
 * <p><b>Por que cada teste cria a própria casa:</b> o teto por hora da mitigação de abuso conta
 * emergências por casa. Casa compartilhada entre testes tornaria o resultado dependente da ordem
 * de execução — e um teste de segurança que passa por ordem de execução não prova nada.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
@TestPropertySource(properties = {
        "aura.sos.cancel-window-seconds=3600",
        "aura.sos.escalate-after-seconds=3600",
        "aura.sos.min-interval-seconds=30",
        "aura.sos.max-per-hour=3",
        "aura.sos.sweep-millis=600000"
})
class EmergencyFlowTest {

    /** Palavras que jamais podem aparecer no texto visível de um aviso (privacidade, C2 e C3). */
    private static final String[] FATORES_CLINICOS = {
        "queda", "quase-queda", "risco", "banheiro", "barra", "Parkinson", "tontura",
        "escore", "mobilidade", "remédio", "medicamento"
    };

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper json;

    @Autowired
    private EmergencyService emergencies;

    @Autowired
    private EmergencyRepository emergencyRepository;

    @Autowired
    private HomeMemberRepository members;

    /**
     * Espião, não dublê: {@code transportReal()} continua devolvendo o valor real (falso, sem
     * credencial), o que preserva o cenário do CI — e ao mesmo tempo dá para contar exatamente
     * quantos pushes saíram. "Não enviou nada" só é demonstrável no limite do transporte.
     */
    @SpyBean
    private FcmService fcm;

    @BeforeEach
    void limpaInvocacoes() {
        clearInvocations(fcm);
    }

    // ------------------------------------------------------------------ apoio

    private JsonNode body(MvcResult res) throws Exception {
        return json.readTree(res.getResponse().getContentAsString(StandardCharsets.UTF_8));
    }

    private record Conta(String auth, UUID userId) { }

    private Conta signup(String email, String nome) throws Exception {
        JsonNode res = body(mvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"aura1234","role":"cuidadora","name":"%s"}"""
                                .formatted(email, nome)))
                .andExpect(status().isCreated())
                .andReturn());
        String auth = "Bearer " + res.get("token").asText();
        mvc.perform(post("/api/v1/consent").header("Authorization", auth)).andExpect(status().isCreated());
        return new Conta(auth, UUID.fromString(res.get("userId").asText()));
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

    /** O SOS <b>sem cabeçalho Authorization</b> — é assim que a tela dispara (regra 3). */
    private JsonNode disparaSemSessao(String homeId) throws Exception {
        return body(mvc.perform(post("/api/v1/emergencies")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s","channel":"touch"}""".formatted(homeId)))
                .andExpect(status().isCreated())
                .andReturn());
    }

    private JsonNode cancela(String emergencyId) throws Exception {
        return body(mvc.perform(post("/api/v1/emergencies/{id}/cancel", emergencyId))
                .andExpect(status().isOk())
                .andReturn());
    }

    private JsonNode estado(String emergencyId) throws Exception {
        return body(mvc.perform(get("/api/v1/emergencies/{id}", emergencyId))
                .andExpect(status().isOk())
                .andReturn());
    }

    private List<FcmService.PushMessage> avisosEnviados(int quantos) {
        ArgumentCaptor<FcmService.PushMessage> captor =
                ArgumentCaptor.forClass(FcmService.PushMessage.class);
        verify(fcm, times(quantos)).send(captor.capture());
        return captor.getAllValues();
    }

    // ------------------------------------------------------------------ testes

    @Test
    @DisplayName("registrar responde na hora, agenda o disparo no servidor e não envia nada ainda")
    void registrarRespondeNaHoraEAgendaODisparo() throws Exception {
        Conta ana = signup("sos-registro@aura.com", "Ana");
        String homeId = casaDe(ana.auth());
        registraAparelho(ana.auth(), "token-aparelho-da-ana-registro");

        JsonNode sos = disparaSemSessao(homeId);

        // a emergência existe desde o primeiro instante: é isso que sobrevive ao celular cair da mão
        assertThat(sos.get("state").asText()).isEqualTo("waiting_cancel");
        assertThat(sos.get("emergencyId").asText()).isNotBlank();
        assertThat(sos.get("homeId").asText()).isEqualTo(homeId);
        assertThat(sos.get("recipientCount").asInt()).isEqualTo(1);
        assertThat(sos.get("primaryContactName").asText()).isEqualTo("Ana");
        assertThat(sos.get("deduplicated").asBoolean()).isFalse();
        assertThat(sos.get("throttled").asBoolean()).isFalse();

        // o disparo é do servidor e está no futuro; o cliente só precisa saber QUANDO, não contar
        assertThat(sos.get("cancelWindowSeconds").asInt()).isEqualTo(3600);
        assertThat(java.time.Instant.parse(sos.get("dispatchAt").asText()))
                .isAfter(java.time.Instant.parse(sos.get("createdAt").asText()));

        // e nada saiu ainda: a janela é para isso
        verify(fcm, never()).send(any());
        assertThat(estado(sos.get("emergencyId").asText()).get("dispatchedAt").isNull()).isTrue();

        // o sinal de emergência foi gravado com o tipo EXISTENTE e o evento no JSON (regra 5)
        mvc.perform(get("/api/v1/homes/{id}/signals", homeId)
                        .param("type", "mobility").header("Authorization", ana.auth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].value.event").value("sos"))
                .andExpect(jsonPath("$[0].value.channel").value("touch"))
                .andExpect(jsonPath("$[0].value.authenticated").value(false));
    }

    @Test
    @DisplayName("cancelar dentro da janela NÃO envia o aviso original e gera o aviso de engano")
    void cancelarDentroDaJanelaNaoEnviaNadaEGeraOAvisoDeEngano() throws Exception {
        Conta ana = signup("sos-cancela@aura.com", "Ana");
        String homeId = casaDe(ana.auth());
        registraAparelho(ana.auth(), "token-aparelho-da-ana-cancela");

        String emergencyId = disparaSemSessao(homeId).get("emergencyId").asText();
        JsonNode cancelamento = cancela(emergencyId);

        assertThat(cancelamento.get("withinWindow").asBoolean()).isTrue();
        assertThat(cancelamento.get("state").asText()).isEqualTo("cancelled");
        // o aviso original nunca saiu — este é o gate desta correção
        assertThat(cancelamento.get("alertSent").asBoolean()).isFalse();
        assertThat(cancelamento.get("retractionSent").asBoolean()).isTrue();

        // exatamente UM push saiu, e foi a retração; se aparecer um "sos" aqui, o cancelamento
        // dentro da janela virou apenas um cancelamento DEPOIS do disparo
        List<FcmService.PushMessage> avisos = avisosEnviados(1);
        assertThat(avisos.get(0).data()).containsEntry("kind", "sos_cancelled");
        assertThat(avisos.get(0).body()).isEqualTo("Foi engano, a Maria cancelou. Está tudo bem.");

        // e o disparo agendado não acontece mais, nem depois
        emergencies.dispatchIfDue(UUID.fromString(emergencyId));
        verify(fcm, times(1)).send(any());
        assertThat(estado(emergencyId).get("state").asText()).isEqualTo("cancelled");
        assertThat(estado(emergencyId).get("dispatchedAt").isNull()).isTrue();
    }

    @Test
    @DisplayName("cancelar FORA da janela não desfaz o que já saiu — só acrescenta a retração")
    void cancelarForaDaJanelaNaoDesfazOQueJaSaiu() throws Exception {
        Conta ana = signup("sos-tarde@aura.com", "Ana");
        String homeId = casaDe(ana.auth());
        registraAparelho(ana.auth(), "token-aparelho-da-ana-tarde");

        String emergencyId = disparaSemSessao(homeId).get("emergencyId").asText();

        // o servidor chegou primeiro: é o mesmo ponto de entrada do cronômetro de T+5s
        emergencies.dispatchIfDue(UUID.fromString(emergencyId));
        assertThat(estado(emergencyId).get("state").asText()).isEqualTo("dispatched");

        JsonNode cancelamento = cancela(emergencyId);

        assertThat(cancelamento.get("withinWindow").asBoolean()).isFalse();
        assertThat(cancelamento.get("alertSent").asBoolean()).isTrue();
        assertThat(cancelamento.get("retractionSent").asBoolean()).isTrue();
        // NADA é desfeito: o estado não volta para cancelled e o histórico continua dizendo que saiu
        assertThat(cancelamento.get("state").asText()).isEqualTo("dispatched");

        JsonNode depois = estado(emergencyId);
        assertThat(depois.get("state").asText()).isEqualTo("dispatched");
        assertThat(depois.get("dispatchedAt").isNull()).isFalse();
        assertThat(depois.get("notifiedCount").asInt()).isEqualTo(1);

        // dois pushes: o aviso e a retração — nesta ordem
        List<FcmService.PushMessage> avisos = avisosEnviados(2);
        assertThat(avisos.get(0).data()).containsEntry("kind", "sos");
        assertThat(avisos.get(1).data()).containsEntry("kind", "sos_cancelled");
    }

    @Test
    @DisplayName("sem confirmação, o escalonamento alcança os demais membros da casa")
    void semConfirmacaoOEscalonamentoAlcancaOsDemaisMembros() throws Exception {
        Conta ana = signup("sos-esc-dona@aura.com", "Ana");
        String homeId = casaDe(ana.auth());
        registraAparelho(ana.auth(), "token-da-ana-escalonamento");

        // segundo cuidador da casa, vinculado por home_members — é o C0 que torna isto possível
        Conta filho = signup("sos-esc-filho@aura.com", "Bruno");
        registraAparelho(filho.auth(), "token-do-bruno-escalonamento");
        members.save(HomeMember.builder().homeId(UUID.fromString(homeId)).userId(filho.userId())
                .role(HomeMemberRole.CUIDADORA).build());

        String emergencyId = disparaSemSessao(homeId).get("emergencyId").asText();
        emergencies.dispatchIfDue(UUID.fromString(emergencyId));

        // ninguém confirmou: passado o prazo, o aviso vai para quem ainda não recebeu
        emergencies.escalateIfDue(UUID.fromString(emergencyId));

        JsonNode depois = estado(emergencyId);
        assertThat(depois.get("state").asText()).isEqualTo("escalated");
        assertThat(depois.get("escalated").asBoolean()).isTrue();

        List<FcmService.PushMessage> avisos = avisosEnviados(2);
        // o primeiro foi para a dona; o segundo, o escalonamento, foi para o OUTRO aparelho
        assertThat(avisos.get(0).deviceToken()).isEqualTo("token-da-ana-escalonamento");
        assertThat(avisos.get(1).deviceToken()).isEqualTo("token-do-bruno-escalonamento");
        assertThat(avisos.get(1).data()).containsEntry("kind", "sos_escalated");
        assertThat(avisos.get(1).body())
                .isEqualTo("A Maria pediu ajuda e ninguém confirmou ainda. Toque para abrir.");
    }

    @Test
    @DisplayName("\"estou indo\" fecha o loop e o escalonamento não acontece mais")
    void confirmarParaOEscalonamento() throws Exception {
        Conta ana = signup("sos-ack@aura.com", "Ana");
        String homeId = casaDe(ana.auth());
        registraAparelho(ana.auth(), "token-da-ana-ack");

        Conta filho = signup("sos-ack-filho@aura.com", "Bruno");
        registraAparelho(filho.auth(), "token-do-bruno-ack");
        members.save(HomeMember.builder().homeId(UUID.fromString(homeId)).userId(filho.userId())
                .role(HomeMemberRole.CUIDADORA).build());

        String emergencyId = disparaSemSessao(homeId).get("emergencyId").asText();
        emergencies.dispatchIfDue(UUID.fromString(emergencyId));

        JsonNode ack = body(mvc.perform(post("/api/v1/emergencies/{id}/ack", emergencyId)
                                .header("Authorization", ana.auth()))
                        .andExpect(status().isOk())
                        .andReturn());

        assertThat(ack.get("state").asText()).isEqualTo("acknowledged");
        assertThat(ack.get("acknowledgedByName").asText()).isEqualTo("Ana");
        assertThat(ack.get("escalationStopped").asBoolean()).isTrue();
        assertThat(ack.get("spokenMessage").asText()).isEqualTo("A Ana viu e disse que está indo.");

        // e agora o escalonamento é um no-op: o Bruno não é acordado às 3h por nada
        emergencies.escalateIfDue(UUID.fromString(emergencyId));
        List<FcmService.PushMessage> avisos = avisosEnviados(1);
        assertThat(avisos.get(0).deviceToken()).isEqualTo("token-da-ana-ack");
        assertThat(estado(emergencyId).get("state").asText()).isEqualTo("acknowledged");
        assertThat(estado(emergencyId).get("escalated").asBoolean()).isFalse();
    }

    @Test
    @DisplayName("transporte simulado é reportado como simulado, e a resposta proíbe a promessa")
    void transporteSimuladoEReportadoComoSimulado() throws Exception {
        Conta ana = signup("sos-simulado@aura.com", "Ana");
        String homeId = casaDe(ana.auth());
        registraAparelho(ana.auth(), "token-da-ana-simulado");

        // o CI roda sem credencial do Firebase: é este o cenário, e ele tem de se declarar
        assertThat(fcm.transportReal()).isFalse();

        JsonNode sos = disparaSemSessao(homeId);

        assertThat(sos.get("simulated").asBoolean()).isTrue();
        assertThat(sos.get("transportReal").asBoolean()).isFalse();
        // é este par que impede a tela de dizer "avisei a Ana" sobre um push que não vai sair
        assertThat(sos.get("canPromiseAlert").asBoolean()).isFalse();
        assertThat(sos.get("degradedReason").asText()).isEqualTo("simulated_transport");
        assertThat(sos.get("spokenMessage").asText()).isEqualTo(
                "Não consigo avisar a Ana daqui. Toque no botão grande para ligar para ela.");

        // e continua se declarando depois do disparo, na tela de pós-pedido
        String emergencyId = sos.get("emergencyId").asText();
        emergencies.dispatchIfDue(UUID.fromString(emergencyId));
        JsonNode depois = estado(emergencyId);
        assertThat(depois.get("simulated").asBoolean()).isTrue();
        assertThat(depois.get("canPromiseAlert").asBoolean()).isFalse();
        assertThat(depois.get("degradedReason").asText()).isEqualTo("simulated_transport");
    }

    @Test
    @DisplayName("casa sem aparelho registrado não vira erro: vira aviso impossível de prometer")
    void casaSemAparelhoNaoViraErro() throws Exception {
        Conta ana = signup("sos-sem-aparelho@aura.com", "Ana");
        String homeId = casaDe(ana.auth());
        // de propósito: nenhum register-token

        JsonNode sos = disparaSemSessao(homeId);

        // 201, nunca 422 — negar um pedido de socorro com erro empurraria a decisão para a tela
        assertThat(sos.get("state").asText()).isEqualTo("waiting_cancel");
        assertThat(sos.get("recipientCount").asInt()).isZero();
        assertThat(sos.get("canPromiseAlert").asBoolean()).isFalse();

        emergencies.dispatchIfDue(UUID.fromString(sos.get("emergencyId").asText()));
        assertThat(estado(sos.get("emergencyId").asText()).get("notifiedCount").asInt()).isZero();
        verify(fcm, never()).send(any());
    }

    @Test
    @DisplayName("a mitigação de abuso contém disparos repetidos, e o disparo autenticado passa")
    void mitigacaoDeAbusoContemDisparosRepetidos() throws Exception {
        Conta ana = signup("sos-abuso@aura.com", "Ana");
        String homeId = casaDe(ana.auth());
        registraAparelho(ana.auth(), "token-da-ana-abuso");
        UUID casa = UUID.fromString(homeId);

        // 1) toque repetido (ou flood) devolve a MESMA emergência: nenhuma linha nova, nenhum push
        String primeiro = disparaSemSessao(homeId).get("emergencyId").asText();
        for (int i = 0; i < 4; i++) {
            JsonNode repetido = disparaSemSessao(homeId);
            assertThat(repetido.get("deduplicated").asBoolean()).isTrue();
            assertThat(repetido.get("emergencyId").asText()).isEqualTo(primeiro);
        }
        assertThat(emergencyRepository.countByHomeIdAndCreatedAtGreaterThanEqual(
                casa, java.time.Instant.now().minusSeconds(3600))).isEqualTo(1);
        verify(fcm, never()).send(any());

        // 2) o teto por hora: cada cancelamento fecha a emergência, então o toque seguinte cria
        //    outra de verdade — e é assim que o teto de 3/hora é alcançado
        cancela(primeiro);
        for (int i = 0; i < 2; i++) {
            JsonNode nova = disparaSemSessao(homeId);
            assertThat(nova.get("throttled").asBoolean()).isFalse();
            // emergência cancelada NUNCA é reaproveitada: um pedido de socorro novo é novo
            assertThat(nova.get("deduplicated").asBoolean()).isFalse();
            cancela(nova.get("emergencyId").asText());
        }

        JsonNode contido = disparaSemSessao(homeId);
        assertThat(contido.get("throttled").asBoolean()).isTrue();
        assertThat(contido.get("state").asText()).isEqualTo("throttled");
        assertThat(contido.get("canPromiseAlert").asBoolean()).isFalse();
        assertThat(contido.get("degradedReason").asText()).isEqualTo("throttled");

        // 3) e a assimetria que sustenta o desenho: COM sessão o teto não se aplica
        JsonNode autenticado = body(mvc.perform(post("/api/v1/emergencies")
                                .header("Authorization", ana.auth())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {"homeId":"%s","channel":"voice"}""".formatted(homeId)))
                        .andExpect(status().isCreated())
                        .andReturn());
        assertThat(autenticado.get("throttled").asBoolean()).isFalse();
        assertThat(autenticado.get("state").asText()).isEqualTo("waiting_cancel");

        // o registro do disparo contido existe e é auditável: um SOS real nunca fica invisível
        mvc.perform(get("/api/v1/homes/{id}/signals", homeId)
                        .param("type", "mobility").header("Authorization", ana.auth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.value.throttled == true)]").exists());
    }

    @Test
    @DisplayName("o corpo do aviso de crise não contém fator clínico, e leva a localização em data")
    void corpoSemFatorClinicoComLocalizacao() throws Exception {
        Conta ana = signup("sos-privacidade@aura.com", "Ana");
        String homeId = casaDe(ana.auth());
        registraAparelho(ana.auth(), "token-da-ana-privacidade");

        String emergencyId = disparaSemSessao(homeId).get("emergencyId").asText();
        emergencies.dispatchIfDue(UUID.fromString(emergencyId));

        FcmService.PushMessage aviso = avisosEnviados(1).get(0);

        // o que aparece na tela de bloqueio de quem pegar o celular do sofá
        assertThat(aviso.title()).isEqualTo("AURA · Pedido de ajuda");
        assertThat(aviso.body()).isEqualTo("A Maria pediu ajuda agora. Toque para abrir.");
        assertThat(aviso.title() + " " + aviso.body())
                .doesNotContainIgnoringCase(FATORES_CLINICOS);

        // a localização viaja em data, que NÃO é renderizado na tela de bloqueio — e sem ela o
        // aviso é inútil para quem precisa chegar até lá
        assertThat(aviso.data())
                .containsEntry("kind", "sos")
                .containsEntry("emergencyId", emergencyId)
                .containsEntry("action", "ack")
                .containsKeys("lat", "lng");
        assertThat(aviso.highPriority()).isTrue();
    }

    @Test
    @DisplayName("o \"estou indo\" exige sessão e respeita o isolamento por casa (RN-017)")
    void ackExigeSessaoEIsolamento() throws Exception {
        Conta ana = signup("sos-ack-auth@aura.com", "Ana");
        String homeId = casaDe(ana.auth());
        registraAparelho(ana.auth(), "token-da-ana-ack-auth");
        String emergencyId = disparaSemSessao(homeId).get("emergencyId").asText();

        // disparar e cancelar são abertos; confirmar não é — a confirmação precisa de autor
        mvc.perform(post("/api/v1/emergencies/{id}/ack", emergencyId))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));

        Conta estranha = signup("sos-estranha@aura.com", "Carla");
        mvc.perform(post("/api/v1/emergencies/{id}/ack", emergencyId)
                        .header("Authorization", estranha.auth()))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));

        // e um identificador que não existe é 404, não 500
        mvc.perform(post("/api/v1/emergencies")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s"}""".formatted(UUID.randomUUID())))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));
    }
}
