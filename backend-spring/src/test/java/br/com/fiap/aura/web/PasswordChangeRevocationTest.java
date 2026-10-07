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
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

/** Trocar a senha revoga todo token emitido antes dela (access e refresh). */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
class PasswordChangeRevocationTest {

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

    private int loginStatus(String email, String password) throws Exception {
        return mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"%s\",\"password\":\"%s\"}".formatted(email, password)))
                .andReturn().getResponse().getStatus();
    }

    private MvcResult me(String accessToken) throws Exception {
        return mvc.perform(get("/api/v1/auth/me").header("Authorization", "Bearer " + accessToken))
                .andReturn();
    }

    private MvcResult refresh(String refreshToken) throws Exception {
        return mvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"refreshToken\":\"%s\"}".formatted(refreshToken)))
                .andReturn();
    }

    @Test
    @DisplayName("troca de senha derruba access e refresh antigos e devolve um par novo que funciona")
    void passwordChangeRevokesPreviousTokens() throws Exception {
        String email = "troca-senha@aura.com";
        JsonNode created = signup(email);
        String oldAccess = created.get("token").asText();
        String oldRefresh = created.get("refreshToken").asText();
        // Um refresh feito antes da troca também tem de cair junto.
        String refreshedBefore = body(refresh(oldRefresh)).get("refreshToken").asText();
        assertThat(me(oldAccess).getResponse().getStatus()).isEqualTo(200);

        JsonNode changed = body(mvc.perform(post("/api/v1/auth/password")
                        .header("Authorization", "Bearer " + oldAccess)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"currentPassword":"aura1234","newPassword":"nova-senha-9"}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.role").value("cuidadora"))
                .andReturn());
        String newAccess = changed.get("token").asText();
        String newRefresh = changed.get("refreshToken").asText();

        MvcResult oldMe = me(oldAccess);
        assertThat(oldMe.getResponse().getStatus()).isEqualTo(401);
        assertThat(body(oldMe).at("/error/code").asText()).isEqualTo("UNAUTHORIZED");
        assertThat(refresh(oldRefresh).getResponse().getStatus()).isEqualTo(401);
        assertThat(refresh(refreshedBefore).getResponse().getStatus()).isEqualTo(401);

        assertThat(me(newAccess).getResponse().getStatus()).isEqualTo(200);
        MvcResult renewed = refresh(newRefresh);
        assertThat(renewed.getResponse().getStatus()).isEqualTo(200);
        assertThat(me(body(renewed).get("token").asText()).getResponse().getStatus()).isEqualTo(200);

        assertThat(loginStatus(email, "nova-senha-9")).isEqualTo(200);
        assertThat(loginStatus(email, "aura1234")).isEqualTo(401);
    }

    @Test
    @DisplayName("senha atual errada não troca nada nem derruba a sessão")
    void wrongCurrentPasswordKeepsSession() throws Exception {
        JsonNode created = signup("troca-errada@aura.com");
        String access = created.get("token").asText();
        mvc.perform(post("/api/v1/auth/password")
                        .header("Authorization", "Bearer " + access)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"currentPassword":"errada","newPassword":"nova-senha-9"}"""))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
        assertThat(me(access).getResponse().getStatus()).isEqualTo(200);
        assertThat(refresh(created.get("refreshToken").asText()).getResponse().getStatus()).isEqualTo(200);
    }

    @Test
    @DisplayName("token sem o carimbo de senha (versão antiga) é recusado no filtro e no refresh")
    void legacyTokenWithoutStampIsRejected() throws Exception {
        String userId = signup("token-legado@aura.com").get("userId").asText();
        var key = Keys.hmacShaKeyFor(props.jwt().secret().getBytes(StandardCharsets.UTF_8));
        Instant now = Instant.now();
        String legacyAccess = Jwts.builder().subject(userId).claim("role", "cuidadora").claim("typ", "access")
                .issuedAt(Date.from(now)).expiration(Date.from(now.plusSeconds(600))).signWith(key).compact();
        String legacyRefresh = Jwts.builder().subject(userId).claim("role", "cuidadora").claim("typ", "refresh")
                .issuedAt(Date.from(now)).expiration(Date.from(now.plusSeconds(600))).signWith(key).compact();

        assertThat(me(legacyAccess).getResponse().getStatus()).isEqualTo(401);
        assertThat(refresh(legacyRefresh).getResponse().getStatus()).isEqualTo(401);
    }
}
