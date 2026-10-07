package br.com.fiap.aura.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.fiap.aura.config.AuraProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
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
 * Um token velho esquecido no cliente não pode bloquear as rotas públicas (o próprio login), e nas
 * rotas protegidas o 401 continua dizendo ao cliente se vale tentar o refresh.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
class StaleTokenOnPublicRoutesTest {

    private static final String GARBAGE = "Bearer nao-e-um-jwt";

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private AuraProperties props;

    private JsonNode body(MvcResult res) throws Exception {
        return json.readTree(res.getResponse().getContentAsString(StandardCharsets.UTF_8));
    }

    private JsonNode signup(String email) throws Exception {
        return body(mvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"aura1234","role":"cuidadora","name":"Teste"}"""
                                .formatted(email)))
                .andExpect(status().isCreated())
                .andReturn());
    }

    /** Access token com assinatura válida, vencido há um minuto. */
    private String expiredBearer(String userId) {
        var key = Keys.hmacShaKeyFor(props.jwt().secret().getBytes(StandardCharsets.UTF_8));
        Instant now = Instant.now();
        return "Bearer " + Jwts.builder().subject(userId).claim("role", "cuidadora").claim("typ", "access")
                .claim("pwd", "qualquer")
                .issuedAt(Date.from(now.minusSeconds(3600))).expiration(Date.from(now.minusSeconds(60)))
                .signWith(key).compact();
    }

    private MvcResult login(String email, String authorization) throws Exception {
        return mvc.perform(post("/api/v1/auth/login")
                        .header("Authorization", authorization)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"%s\",\"password\":\"aura1234\"}".formatted(email)))
                .andReturn();
    }

    @Test
    @DisplayName("login, signup, refresh e health ignoram Bearer vencido ou lixo")
    void publicAuthRoutesIgnoreStaleBearer() throws Exception {
        String email = "token-velho-login@aura.com";
        JsonNode created = signup(email);
        String expired = expiredBearer(created.get("userId").asText());

        assertThat(login(email, expired).getResponse().getStatus()).isEqualTo(200);
        assertThat(login(email, GARBAGE).getResponse().getStatus()).isEqualTo(200);

        mvc.perform(post("/api/v1/auth/signup").header("Authorization", expired)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"token-velho-signup@aura.com","password":"aura1234","role":"cuidadora","name":"T"}"""))
                .andExpect(status().isCreated());

        mvc.perform(post("/api/v1/auth/refresh").header("Authorization", expired)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"%s\"}".formatted(created.get("refreshToken").asText())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").isNotEmpty());

        mvc.perform(get("/api/v1/health").header("Authorization", GARBAGE)).andExpect(status().isOk());
        mvc.perform(get("/v3/api-docs").header("Authorization", expired)).andExpect(status().isOk());
    }

    @Test
    @DisplayName("token de conta apagada (usuário inexistente) não bloqueia o login")
    void tokenOfMissingUserDoesNotBlockLogin() throws Exception {
        String email = "token-orfao@aura.com";
        signup(email);
        var key = Keys.hmacShaKeyFor(props.jwt().secret().getBytes(StandardCharsets.UTF_8));
        Instant now = Instant.now();
        String orphan = "Bearer " + Jwts.builder().subject(UUID.randomUUID().toString())
                .claim("role", "cuidadora").claim("typ", "access").claim("pwd", "x")
                .issuedAt(Date.from(now)).expiration(Date.from(now.plusSeconds(600))).signWith(key).compact();

        assertThat(login(email, orphan).getResponse().getStatus()).isEqualTo(200);
        mvc.perform(get("/api/v1/auth/me").header("Authorization", orphan))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
    }

    @Test
    @DisplayName("rota aberta do SOS trata token recusado como anônimo")
    void sosOpenRouteIgnoresStaleBearer() throws Exception {
        // Sem sessão o status de um id inexistente é 404; com token lixo tem de ser o mesmo, não 401.
        mvc.perform(get("/api/v1/emergencies/{id}", UUID.randomUUID()).header("Authorization", GARBAGE))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("rota protegida: vencido é 401 TOKEN_EXPIRED, lixo é 401 UNAUTHORIZED")
    void protectedRouteKeepsCodes() throws Exception {
        String userId = signup("token-velho-me@aura.com").get("userId").asText();

        mvc.perform(get("/api/v1/auth/me").header("Authorization", expiredBearer(userId)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("TOKEN_EXPIRED"));
        mvc.perform(get("/api/v1/auth/me").header("Authorization", GARBAGE))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
        mvc.perform(get("/api/v1/auth/me"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.error.message").value("Autenticação necessária."));
    }

    @Test
    @DisplayName("token revogado pela troca de senha: login segue livre, rota protegida diz sessão encerrada")
    void revokedTokenKeepsUnauthorizedOnProtectedRoute() throws Exception {
        String email = "token-revogado@aura.com";
        String oldAuth = "Bearer " + signup(email).get("token").asText();
        mvc.perform(post("/api/v1/auth/password").header("Authorization", oldAuth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"currentPassword":"aura1234","newPassword":"aura1234-nova"}"""))
                .andExpect(status().isOk());

        mvc.perform(get("/api/v1/auth/me").header("Authorization", oldAuth))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"))
                .andExpect(jsonPath("$.error.message").value("Sessão encerrada — entre novamente."));

        mvc.perform(post("/api/v1/auth/login").header("Authorization", oldAuth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"%s\",\"password\":\"aura1234-nova\"}".formatted(email)))
                .andExpect(status().isOk());
    }
}
