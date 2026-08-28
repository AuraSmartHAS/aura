package br.com.fiap.aura.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
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
 * A rota de aviso de teste (C2) rodando como o CI roda: <b>sem credencial do Firebase</b>.
 * É o cenário que sustenta a regra 1 do SOS (C3) — o transporte simulado tem de se declarar.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
class NotificationFlowTest {

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper json;

    private JsonNode body(MvcResult res) throws Exception {
        return json.readTree(res.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8));
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

    private String homeOf(String auth) throws Exception {
        mvc.perform(post("/api/v1/consent").header("Authorization", auth)).andExpect(status().isCreated());
        return body(mvc.perform(post("/api/v1/homes").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"patientName":"Maria S.","cep":"01310100","label":"Casa da Maria"}"""))
                .andExpect(status().isCreated())
                .andReturn()).get("homeId").asText();
    }

    private void registraAparelho(String auth) throws Exception {
        mvc.perform(post("/api/v1/notifications/register-token").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"fcmToken":"fMbQ7-token-de-teste-do-aparelho-da-ana-9xK2c"}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ok").value(true));
    }

    @Test
    @DisplayName("sem credencial a rota responde 201 com simulated=true, messageId e latencyMs (C2)")
    void disparoSemCredencialSeDeclaraSimulado() throws Exception {
        String auth = signup("push@aura.com");
        String homeId = homeOf(auth);
        registraAparelho(auth);

        JsonNode aviso = body(mvc.perform(post("/api/v1/notifications/test").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s","kind":"recommendation"}""".formatted(homeId)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.simulated").value(true))
                .andReturn());

        // o campo tem de CHEGAR ao chamador, não ficar só no log: é o que o SOS lê para não
        // prometer "avisei a Ana" sobre um push que nunca saiu do servidor
        assertThat(aviso.get("messageId").asText()).startsWith("simulado:");
        assertThat(aviso.get("latencyMs").isNumber()).isTrue();
        assertThat(aviso.get("latencyMs").asLong()).isNotNegative();
    }

    @Test
    @DisplayName("sem kind vale recommendation, e o disparo continua respondendo 201")
    void kindAusenteCaiNoPadrao() throws Exception {
        String auth = signup("padrao@aura.com");
        String homeId = homeOf(auth);
        registraAparelho(auth);

        mvc.perform(post("/api/v1/notifications/test").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s"}""".formatted(homeId)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.simulated").value(true))
                .andExpect(jsonPath("$.messageId").exists());
    }

    @Test
    @DisplayName("destinatário sem aparelho registrado vira 422 explicado, nunca 500")
    void semAparelhoRegistradoOErroEExplicado() throws Exception {
        String auth = signup("semaparelho@aura.com");
        String homeId = homeOf(auth);

        mvc.perform(post("/api/v1/notifications/test").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s"}""".formatted(homeId)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.error.code").value("PUSH_TOKEN_MISSING"))
                .andExpect(jsonPath("$.error.message").value(
                        org.hamcrest.Matchers.containsString("register-token")));
    }

    @Test
    @DisplayName("disparar aviso na casa de outra cuidadora continua em 403 (RN-017)")
    void isolamentoValeParaOAviso() throws Exception {
        String dona = signup("donapush@aura.com");
        String estranha = signup("estranhapush@aura.com");
        String homeId = homeOf(dona);
        registraAparelho(dona);

        mvc.perform(post("/api/v1/notifications/test").header("Authorization", estranha)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s"}""".formatted(homeId)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
    }
}
