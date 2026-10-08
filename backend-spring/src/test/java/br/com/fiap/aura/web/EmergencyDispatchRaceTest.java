package br.com.fiap.aura.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.fiap.aura.domain.Emergency;
import br.com.fiap.aura.repository.EmergencyRepository;
import br.com.fiap.aura.service.EmergencyService;
import br.com.fiap.aura.service.FcmService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
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
 * A janela entre "o estado virou {@code dispatched}" e "o push respondeu", reproduzida <b>sem
 * depender de relógio nem de carga</b>.
 *
 * <p>O defeito que este teste prende: o disparo virava o estado num {@code UPDATE} e só gravava
 * {@code dispatchedAt}/{@code notifiedCount} depois do FCM. Sob carga, o polling da tela caía nessa
 * fresta e lia {@code dispatched} sem {@code dispatchedAt} e com zero aparelhos — e o servidor dizia
 * à Maria "não consegui avisar a Ana" enquanto o aviso ainda estava saindo. Aqui a fresta é aberta
 * de propósito: o envio do aviso principal fica preso num {@link CountDownLatch} até o teste soltar,
 * e tudo que um leitor veria nesse meio-tempo é verificado.
 *
 * <p>Transporte <b>real</b> simulado no espião ({@code transportReal() = true}): é o cenário em que o
 * defeito mentia. Com transporte simulado a fala já é "não consigo avisar daqui" por outro motivo,
 * honesto, e esconderia o problema.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
@TestPropertySource(properties = {
        "aura.sos.cancel-window-seconds=3600",
        "aura.sos.min-interval-seconds=1",
        "aura.sos.sweep-millis=600000"
})
class EmergencyDispatchRaceTest {

    private static final long ESPERA_SEGUNDOS = 10;

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private EmergencyService emergencies;
    @Autowired private EmergencyRepository repository;

    @SpyBean private FcmService fcm;

    /** O envio do aviso principal entrou no FCM e está parado. */
    private CountDownLatch envioComecou;
    /** O teste deixa o FCM responder. */
    private CountDownLatch liberaEnvio;

    @BeforeEach
    void prendeOAvisoPrincipal() {
        envioComecou = new CountDownLatch(1);
        liberaEnvio = new CountDownLatch(1);
        doReturn(true).when(fcm).transportReal();
        doAnswer(inv -> {
            FcmService.PushMessage msg = inv.getArgument(0);
            if ("sos".equals(msg.data().get("kind"))) {
                envioComecou.countDown();
                assertThat(liberaEnvio.await(ESPERA_SEGUNDOS, TimeUnit.SECONDS))
                        .as("o teste não liberou o envio").isTrue();
            }
            return new FcmService.PushResult("fcm-" + UUID.randomUUID(), 1, false);
        }).when(fcm).send(any());
    }

    @AfterEach
    void solta() {
        liberaEnvio.countDown();   // nunca deixa uma thread presa para o próximo teste
        reset(fcm);
    }

    @Test
    @DisplayName("com o push ainda saindo, o estado é coerente: dispatchedAt gravado e nada de \"não consegui\"")
    void enquantoOAvisoSaiNinguemLeEstadoIncoerente() throws Exception {
        Conta ana = contaComCasaEAparelho("sos-corrida@aura.com");
        UUID id = disparaSemSessao(ana.homeId());
        clearInvocations(fcm);

        CompletableFuture<Void> disparo = CompletableFuture.runAsync(() -> emergencies.dispatchIfDue(id));
        assertThat(envioComecou.await(ESPERA_SEGUNDOS, TimeUnit.SECONDS))
                .as("o disparo não chegou ao FCM").isTrue();

        // --- dentro da fresta: o push está parado no FCM ---
        JsonNode meio = estado(id);
        assertThat(meio.get("state").asText()).isEqualTo("dispatched");
        assertThat(meio.get("dispatchedAt").isNull()).as("dispatched sem dispatchedAt").isFalse();
        assertThat(meio.get("alertInProgress").asBoolean()).isTrue();
        assertThat(meio.get("notifiedCount").isNull()).as("zero aparelhos antes do resultado").isTrue();
        assertThat(meio.get("canPromiseAlert").asBoolean()).isFalse();
        assertThat(meio.get("degradedReason").isNull()).isTrue();
        assertThat(meio.get("spokenMessage").asText())
                .isEqualTo("Estou avisando a Ana.")
                .doesNotContain("Não consegui");

        // a escalada já está agendada a partir do disparo, não do fim do envio
        Emergency gravada = repository.findById(id).orElseThrow();
        assertThat(gravada.getEscalateDueAt()).isEqualTo(gravada.getDispatchedAt().plusSeconds(60));

        // idempotência com o disparo preso: o cronômetro, o varredor e um segundo chamador não
        // disparam de novo
        emergencies.dispatchIfDue(id);
        emergencies.sweep();
        assertThat(disparo).isNotDone();

        // --- o FCM responde ---
        liberaEnvio.countDown();
        disparo.get(ESPERA_SEGUNDOS, TimeUnit.SECONDS);

        JsonNode fim = estado(id);
        assertThat(fim.get("state").asText()).isEqualTo("dispatched");
        assertThat(fim.get("alertInProgress").asBoolean()).isFalse();
        assertThat(fim.get("notifiedCount").asInt()).isEqualTo(1);
        assertThat(fim.get("canPromiseAlert").asBoolean()).isTrue();
        assertThat(Instant.parse(fim.get("dispatchedAt").asText())).isEqualTo(gravada.getDispatchedAt());
        assertThat(fim.get("spokenMessage").asText()).startsWith("Pronto. O aviso saiu para o celular da Ana");
        verify(fcm, times(1)).send(any());
    }

    @Test
    @DisplayName("\"estou indo\" chegado enquanto o push sai não é apagado pelo fim do disparo")
    void confirmacaoDuranteOEnvioNaoEDesfeita() throws Exception {
        Conta ana = contaComCasaEAparelho("sos-corrida-ack@aura.com");
        UUID id = disparaSemSessao(ana.homeId());

        CompletableFuture<Void> disparo = CompletableFuture.runAsync(() -> emergencies.dispatchIfDue(id));
        assertThat(envioComecou.await(ESPERA_SEGUNDOS, TimeUnit.SECONDS)).isTrue();

        mvc.perform(post("/api/v1/emergencies/{id}/ack", id).header("Authorization", ana.auth()))
                .andExpect(status().isOk());

        liberaEnvio.countDown();
        disparo.get(ESPERA_SEGUNDOS, TimeUnit.SECONDS);

        JsonNode fim = estado(id);
        // antes, o save da entidade lida antes do envio regravava "dispatched" por cima do ack
        assertThat(fim.get("state").asText()).isEqualTo("acknowledged");
        assertThat(fim.get("acknowledgedByName").asText()).isEqualTo("Ana");
        assertThat(fim.get("notifiedCount").asInt()).isEqualTo(1);
    }

    // ------------------------------------------------------------------ apoio

    private record Conta(String auth, String homeId) { }

    private Conta contaComCasaEAparelho(String email) throws Exception {
        JsonNode conta = body(mvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"aura1234","role":"cuidadora","name":"Ana"}"""
                                .formatted(email)))
                .andExpect(status().isCreated()).andReturn());
        String auth = "Bearer " + conta.get("token").asText();
        mvc.perform(post("/api/v1/consent").header("Authorization", auth)).andExpect(status().isCreated());
        String homeId = body(mvc.perform(post("/api/v1/homes").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"patientName":"Maria S.","cep":"01310100","label":"Casa da Maria"}"""))
                .andExpect(status().isCreated()).andReturn()).get("homeId").asText();
        mvc.perform(post("/api/v1/notifications/register-token").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"fcmToken":"token-%s"}""".formatted(email)))
                .andExpect(status().isOk());
        return new Conta(auth, homeId);
    }

    private UUID disparaSemSessao(String homeId) throws Exception {
        JsonNode sos = body(mvc.perform(post("/api/v1/emergencies")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s","channel":"touch"}""".formatted(homeId)))
                .andExpect(status().isCreated()).andReturn());
        return UUID.fromString(sos.get("emergencyId").asText());
    }

    private JsonNode estado(UUID id) throws Exception {
        return body(mvc.perform(get("/api/v1/emergencies/{id}", id)).andExpect(status().isOk()).andReturn());
    }

    private JsonNode body(MvcResult res) throws Exception {
        return json.readTree(res.getResponse().getContentAsString(StandardCharsets.UTF_8));
    }
}
