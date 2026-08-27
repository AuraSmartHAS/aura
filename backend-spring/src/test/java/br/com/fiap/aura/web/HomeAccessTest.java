package br.com.fiap.aura.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
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
 * Modelo de acesso do paciente (C0): a Maria entra na própria casa pelo vínculo de
 * {@code home_members}, a Ana continua entrando como dona e quem não é nenhum dos dois
 * continua levando 403 — o isolamento do RN-017 só ganhou gente, não afrouxou.
 * O gate LGPD (RN-001) segue valendo por cima de tudo, inclusive para a paciente.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
class HomeAccessTest {

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper json;

    private JsonNode body(MvcResult res) throws Exception {
        return json.readTree(res.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8));
    }

    /** Contas do seed: a demonstração inteira depende de elas existirem com esta senha. */
    private String login(String email) throws Exception {
        MvcResult res = mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"aura1234"}""".formatted(email)))
                .andExpect(status().isOk())
                .andReturn();
        return "Bearer " + body(res).get("token").asText();
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

    /** A casa do seed, vista pela dona — o alvo de todos os casos daqui. */
    private String casaDaMaria() throws Exception {
        JsonNode casas = body(mvc.perform(get("/api/v1/homes").header("Authorization", login("ana@aura.com")))
                .andExpect(status().isOk())
                .andReturn());
        return casas.get(0).get("id").asText();
    }

    @Test
    @DisplayName("a paciente acessa a própria casa e enxerga o escore dela (C0)")
    void pacienteAcessaAPropriaCasa() throws Exception {
        String maria = login("maria@aura.com");

        // antes do vínculo esta lista vinha vazia: a casa é da Ana, não da Maria
        JsonNode casas = body(mvc.perform(get("/api/v1/homes").header("Authorization", maria))
                        .andExpect(status().isOk())
                        .andExpect(jsonPath("$.length()").value(1))
                        .andExpect(jsonPath("$[0].label").value("Casa da Maria"))
                        .andReturn());
        String homeId = casas.get(0).get("id").asText();

        // 200, não 403 — é o gate desta correção
        mvc.perform(get("/api/v1/homes/{id}", homeId).header("Authorization", maria))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patientName").value("Maria S."))
                .andExpect(jsonPath("$.safetyChecklist.grab_bar_bathroom").value(false));

        // e o escore que a tela de voz dela lê: o pico de 0,9 do fluxo-herói, com os três fatores
        JsonNode escores = body(mvc.perform(get("/api/v1/homes/{id}/scores/latest", homeId)
                                .header("Authorization", maria))
                        .andExpect(status().isOk())
                        .andExpect(jsonPath("$[0].dimension").value("mobility"))
                        .andExpect(jsonPath("$[0].level").value("high"))
                        .andExpect(jsonPath("$[0].score").value(0.9))
                        .andReturn());
        assertThat(escores.get(0).get("weights").toString()).isEqualTo("[0.4,0.3,0.2]");

        // as outras rotas com escopo de casa abrem junto: sem elas o app dela não roda
        mvc.perform(get("/api/v1/homes/{id}/medications", homeId).header("Authorization", maria))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(3));

        mvc.perform(get("/api/v1/homes/{id}/signals", homeId).header("Authorization", maria))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("usuário sem vínculo continua levando 403 na casa da Maria (RN-017)")
    void semVinculoContinua403() throws Exception {
        String homeId = casaDaMaria();
        String estranha = signup("c0-estranha@aura.com");
        mvc.perform(post("/api/v1/consent").header("Authorization", estranha)).andExpect(status().isCreated());

        // consentida e autenticada, mas sem vínculo nenhum: nada da casa abre
        mvc.perform(get("/api/v1/homes/{id}", homeId).header("Authorization", estranha))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));

        mvc.perform(get("/api/v1/homes/{id}/scores/latest", homeId).header("Authorization", estranha))
                .andExpect(status().isForbidden());

        mvc.perform(get("/api/v1/homes/{id}/medications", homeId).header("Authorization", estranha))
                .andExpect(status().isForbidden());

        mvc.perform(put("/api/v1/homes/{id}/checklist", homeId).header("Authorization", estranha)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"items":{"grab_bar_bathroom":true}}"""))
                .andExpect(status().isForbidden());

        mvc.perform(post("/api/v1/signals").header("Authorization", estranha)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s","type":"mobility","source":"voice",
                                 "value":{"event":"near_fall"}}""".formatted(homeId)))
                .andExpect(status().isForbidden());

        // e a casa de outra pessoa não vaza na listagem dela
        mvc.perform(get("/api/v1/homes").header("Authorization", estranha))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    @DisplayName("a dona da casa continua com acesso total, leitura e escrita")
    void donaContinuaComAcessoTotal() throws Exception {
        String ana = login("ana@aura.com");
        String homeId = casaDaMaria();

        mvc.perform(get("/api/v1/homes/{id}", homeId).header("Authorization", ana))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.patientName").value("Maria S."));

        // escrita também: o checklist volta com o mesmo valor do seed, o fluxo-herói não muda
        mvc.perform(put("/api/v1/homes/{id}/checklist", homeId).header("Authorization", ana)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"items":{"grab_bar_bathroom":false}}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.safetyChecklist.grab_bar_bathroom").value(false))
                .andExpect(jsonPath("$.safetyChecklist.anti_slip_floor").value(false));

        mvc.perform(get("/api/v1/homes/{id}/scores/latest", homeId).header("Authorization", ana))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].score").value(0.9));

        // e o admin da Torre de Controle enxerga a casa sem precisar de vínculo
        mvc.perform(get("/api/v1/homes/{id}", homeId).header("Authorization", login("admin@aura.com")))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("o gate de consentimento continua valendo para quem não aceitou (RN-001)")
    void gateDeConsentimentoContinuaValendo() throws Exception {
        String homeId = casaDaMaria();
        String semAceite = signup("c0-sem-aceite@aura.com");

        mvc.perform(post("/api/v1/homes").header("Authorization", semAceite)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"patientName":"Maria S.","cep":"01310100"}"""))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.error.code").value("CONSENT_REQUIRED"));

        // o vínculo não é atalho para o aceite: o gate roda antes do escopo de casa
        mvc.perform(post("/api/v1/signals").header("Authorization", semAceite)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s","type":"adherence","source":"self_report",
                                 "value":{"taken":true}}""".formatted(homeId)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.error.code").value("CONSENT_REQUIRED"));

        // a Maria passa pelo mesmo gate porque o aceite dela está registrado, não porque é paciente
        mvc.perform(post("/api/v1/signals").header("Authorization", login("maria@aura.com"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s","type":"adherence","source":"self_report",
                                 "value":{"taken":true}}""".formatted(homeId)))
                .andExpect(status().isCreated());
    }
}
