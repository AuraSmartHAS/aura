package br.com.fiap.aura.web;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

/** A rota de voz como o CI a vê: sem credencial do ElevenLabs, e sempre atrás do JWT. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
class VoiceTokenTest {

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper json;

    @Test
    @DisplayName("sem login a rota é 401: diferente da Edge Function antiga, não emite token a qualquer um")
    void exigeLogin() throws Exception {
        mvc.perform(get("/api/v1/voice/token")).andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("logada e sem ELEVENLABS_* no ambiente, responde 503 VOICE_NOT_CONFIGURED no envelope padrão")
    void semCredencial() throws Exception {
        String token = json.readTree(mvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"voz@aura.com","password":"aura1234","role":"paciente"}"""))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString()).get("token").asText();

        mvc.perform(get("/api/v1/voice/token").header("Authorization", "Bearer " + token))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.error.code").value("VOICE_NOT_CONFIGURED"));
    }
}
