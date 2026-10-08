package br.com.fiap.aura.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withServerError;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import br.com.fiap.aura.web.error.ApiException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

/** O token de voz contra um ElevenLabs dublado: a chave sai no header, nunca na URL nem na resposta. */
class VoiceServiceTest {

    private static final String BASE = "https://eleven.test";

    private MockRestServiceServer server;

    private VoiceService service(String apiKey, String agentId) {
        RestClient.Builder builder = RestClient.builder();
        server = MockRestServiceServer.bindTo(builder).build();
        return new VoiceService(apiKey, agentId, BASE, builder);
    }

    @Test
    @DisplayName("devolve o token do ElevenLabs e manda a chave só no header xi-api-key")
    void devolveOToken() {
        VoiceService voice = service("sk-segredo", "agent-42");
        server.expect(requestTo(BASE + "/v1/convai/conversation/token?agent_id=agent-42"))
                .andExpect(header("xi-api-key", "sk-segredo"))
                .andRespond(withSuccess("{\"token\":\"tok-123\"}", MediaType.APPLICATION_JSON));

        assertThat(voice.conversationToken()).isEqualTo("tok-123");
        server.verify();
    }

    @Test
    @DisplayName("sem chave ou sem agente responde 503 VOICE_NOT_CONFIGURED e nem chama o ElevenLabs")
    void semConfiguracao() {
        VoiceService semChave = service("", "agent-42");
        assertThatThrownBy(semChave::conversationToken)
                .isInstanceOfSatisfying(ApiException.class, e -> {
                    assertThat(e.getCode()).isEqualTo("VOICE_NOT_CONFIGURED");
                    assertThat(e.getStatus()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
                });
        server.verify();

        VoiceService semAgente = service("sk-segredo", " ");
        assertThatThrownBy(semAgente::conversationToken)
                .isInstanceOfSatisfying(ApiException.class,
                        e -> assertThat(e.getCode()).isEqualTo("VOICE_NOT_CONFIGURED"));
    }

    @Test
    @DisplayName("falha do ElevenLabs vira 502 VOICE_UPSTREAM_ERROR sem vazar a chave")
    void falhaDoProvedor() {
        VoiceService voice = service("sk-segredo", "agent-42");
        server.expect(requestTo(BASE + "/v1/convai/conversation/token?agent_id=agent-42"))
                .andRespond(withServerError());

        assertThatThrownBy(voice::conversationToken)
                .isInstanceOfSatisfying(ApiException.class, e -> {
                    assertThat(e.getCode()).isEqualTo("VOICE_UPSTREAM_ERROR");
                    assertThat(e.getStatus()).isEqualTo(HttpStatus.BAD_GATEWAY);
                    assertThat(e.getMessage()).doesNotContain("sk-segredo");
                });
    }

    @Test
    @DisplayName("resposta 200 sem token também é 502, não um token vazio")
    void respostaSemToken() {
        VoiceService voice = service("sk-segredo", "agent-42");
        server.expect(requestTo(BASE + "/v1/convai/conversation/token?agent_id=agent-42"))
                .andRespond(withSuccess("{}", MediaType.APPLICATION_JSON));

        assertThatThrownBy(voice::conversationToken)
                .isInstanceOfSatisfying(ApiException.class,
                        e -> assertThat(e.getCode()).isEqualTo("VOICE_UPSTREAM_ERROR"));
    }

    @Test
    @DisplayName("ElevenLabs lento desiste no limite e vira 502 na hora, não 20 s de espera")
    void desisteNoLimite() throws Exception {
        com.sun.net.httpserver.HttpServer lento =
                com.sun.net.httpserver.HttpServer.create(new java.net.InetSocketAddress("127.0.0.1", 0), 0);
        lento.createContext("/", troca -> {
            try {
                Thread.sleep(3_000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            troca.sendResponseHeaders(500, -1);
            troca.close();
        });
        lento.start();
        try {
            String base = "http://127.0.0.1:" + lento.getAddress().getPort();
            VoiceService voice = new VoiceService("sk-segredo", "agent-42", base,
                    java.time.Duration.ofMillis(300), RestClient.builder());

            long inicio = System.nanoTime();
            assertThatThrownBy(voice::conversationToken)
                    .isInstanceOfSatisfying(ApiException.class,
                            e -> assertThat(e.getCode()).isEqualTo("VOICE_UPSTREAM_ERROR"));
            long ms = (System.nanoTime() - inicio) / 1_000_000;
            assertThat(ms).isLessThan(2_000);
        } finally {
            lento.stop(0);
        }
    }
}
