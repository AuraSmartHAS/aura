package br.com.fiap.aura.web;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
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
 * Medicação da Maria no servidor: CRUD da cuidadora, confirmação de dose virando
 * sinal de adesão, isolamento entre pacientes, gate LGPD e horário estruturado.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
class MedicationFlowTest {

    private static final String LOSARTANA = """
            {"name":"Losartana","dosage":"50mg","schedule":["08:00","20:00"],"notes":"tomar com alimento"}""";

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
        return "Bearer " + json.readTree(res.getResponse().getContentAsString()).get("token").asText();
    }

    private JsonNode body(MvcResult res) throws Exception {
        return json.readTree(res.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8));
    }

    /** Cuidadora pronta para operar: conta criada, consentimento aceito e casa cadastrada. */
    private String[] cuidadoraComCasa(String email) throws Exception {
        String auth = signup(email);
        mvc.perform(post("/api/v1/consent").header("Authorization", auth)).andExpect(status().isCreated());
        String homeId = body(mvc.perform(post("/api/v1/homes").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"patientName":"Maria S.","cep":"01310100","label":"Casa da Maria"}"""))
                .andExpect(status().isCreated())
                .andReturn()).get("homeId").asText();
        return new String[] {auth, homeId};
    }

    private String criaMedicacao(String auth, String homeId) throws Exception {
        return body(mvc.perform(post("/api/v1/homes/{homeId}/medications", homeId)
                        .header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(LOSARTANA))
                .andExpect(status().isCreated())
                .andReturn()).get("id").asText();
    }

    @Test
    @DisplayName("CRUD completo: cadastra, lista, edita e exclui o medicamento da casa")
    void crud() throws Exception {
        String[] ana = cuidadoraComCasa("med-crud@aura.com");
        String auth = ana[0];
        String homeId = ana[1];

        String medId = body(mvc.perform(post("/api/v1/homes/{homeId}/medications", homeId)
                        .header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(LOSARTANA))
                        .andExpect(status().isCreated())
                        .andExpect(jsonPath("$.homeId").value(homeId))
                        .andExpect(jsonPath("$.schedule[0]").value("08:00"))
                        .andExpect(jsonPath("$.schedule[1]").value("20:00"))
                        .andExpect(jsonPath("$.active").value(true))
                        .andExpect(jsonPath("$.createdAt").exists())
                        .andReturn())
                .get("id").asText();

        mvc.perform(get("/api/v1/homes/{homeId}/medications", homeId).header("Authorization", auth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].name").value("Losartana"))
                .andExpect(jsonPath("$[0].notes").value("tomar com alimento"));

        // atualização parcial: só os campos enviados mudam
        mvc.perform(put("/api/v1/medications/{medId}", medId).header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"schedule":["09:00"],"active":false}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Losartana"))
                .andExpect(jsonPath("$.dosage").value("50mg"))
                .andExpect(jsonPath("$.schedule.length()").value(1))
                .andExpect(jsonPath("$.schedule[0]").value("09:00"))
                .andExpect(jsonPath("$.active").value(false));

        mvc.perform(delete("/api/v1/medications/{medId}", medId).header("Authorization", auth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.deleted").value(true));

        mvc.perform(get("/api/v1/homes/{homeId}/medications", homeId).header("Authorization", auth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));

        // medicamento excluído não volta a existir
        mvc.perform(put("/api/v1/medications/{medId}", medId).header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Losartana"}"""))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.error.code").value("NOT_FOUND"));
    }

    @Test
    @DisplayName("estoque domiciliar: dose confirmada desce, dose negada não mexe, piso em zero")
    void estoqueSeMoveComAsConfirmacoes() throws Exception {
        String[] ana = cuidadoraComCasa("med-estoque@aura.com");
        String auth = ana[0];

        String medId = body(mvc.perform(post("/api/v1/homes/{homeId}/medications", ana[1])
                        .header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Levodopa","schedule":["08:00"],"stockDoses":2}"""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.stockDoses").value(2))
                .andReturn()).get("id").asText();

        // dose confirmada: 2 → 1, e a resposta já devolve o estoque novo
        mvc.perform(post("/api/v1/medications/{medId}/confirm", medId).header("Authorization", auth))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.stockDoses").value(1));

        // dose negada: registra o sinal, mas o estoque fica onde está
        mvc.perform(post("/api/v1/medications/{medId}/confirm", medId).header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"taken":false}"""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.stockDoses").value(1));

        // 1 → 0, e a confirmação seguinte não deixa o estoque negativo
        mvc.perform(post("/api/v1/medications/{medId}/confirm", medId).header("Authorization", auth))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.stockDoses").value(0));
        mvc.perform(post("/api/v1/medications/{medId}/confirm", medId).header("Authorization", auth))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.stockDoses").value(0));

        // estoque negativo não entra nem no cadastro
        mvc.perform(post("/api/v1/homes/{homeId}/medications", ana[1]).header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Vitamina D","stockDoses":-1}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));

        // medicação sem estoque segue como sempre foi: confirma, e o campo vem nulo
        String semEstoque = body(mvc.perform(post("/api/v1/homes/{homeId}/medications", ana[1])
                        .header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(LOSARTANA))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.stockDoses").isEmpty())
                .andReturn()).get("id").asText();
        mvc.perform(post("/api/v1/medications/{medId}/confirm", semEstoque).header("Authorization", auth))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.stockDoses").isEmpty());
    }

    @Test
    @DisplayName("confirmar a dose grava um sinal de adesão auto-relatado (nunca prescrição)")
    void confirmGravaSinalDeAdesao() throws Exception {
        String[] ana = cuidadoraComCasa("med-confirm@aura.com");
        String auth = ana[0];
        String homeId = ana[1];
        String medId = criaMedicacao(auth, homeId);

        mvc.perform(post("/api/v1/medications/{medId}/confirm", medId).header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"taken":true}"""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.taken").value(true))
                .andExpect(jsonPath("$.signalId").exists());

        mvc.perform(get("/api/v1/homes/{homeId}/signals", homeId).header("Authorization", auth)
                        .param("type", "adherence"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].source").value("self_report"))
                .andExpect(jsonPath("$[0].value.medicationId").value(medId))
                .andExpect(jsonPath("$[0].value.taken").value(true));

        // sem corpo, o padrão é "tomei" — é o que a confirmação por voz manda
        mvc.perform(post("/api/v1/medications/{medId}/confirm", medId).header("Authorization", auth))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.taken").value(true));

        // dose não tomada também é sinal: registra taken=false, não some
        mvc.perform(post("/api/v1/medications/{medId}/confirm", medId).header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"taken":false}"""))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.taken").value(false));

        mvc.perform(get("/api/v1/homes/{homeId}/signals", homeId).header("Authorization", auth)
                        .param("type", "adherence"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(3));
    }

    @Test
    @DisplayName("medicação de outra paciente responde 403 em todas as rotas (RN-017)")
    void isolamentoEntrePacientes() throws Exception {
        String[] ana = cuidadoraComCasa("med-dona@aura.com");
        String auth = ana[0];
        String homeId = ana[1];
        String medId = criaMedicacao(auth, homeId);

        String[] outra = cuidadoraComCasa("med-estranha@aura.com");
        String estranha = outra[0];

        mvc.perform(post("/api/v1/homes/{homeId}/medications", homeId).header("Authorization", estranha)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(LOSARTANA))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));

        mvc.perform(get("/api/v1/homes/{homeId}/medications", homeId).header("Authorization", estranha))
                .andExpect(status().isForbidden());

        mvc.perform(put("/api/v1/medications/{medId}", medId).header("Authorization", estranha)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Outro remédio"}"""))
                .andExpect(status().isForbidden());

        mvc.perform(post("/api/v1/medications/{medId}/confirm", medId).header("Authorization", estranha))
                .andExpect(status().isForbidden());

        mvc.perform(delete("/api/v1/medications/{medId}", medId).header("Authorization", estranha))
                .andExpect(status().isForbidden());

        // e o medicamento continua lá para quem cuida da casa
        mvc.perform(get("/api/v1/homes/{homeId}/medications", homeId).header("Authorization", auth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1));
    }

    @Test
    @DisplayName("sem consentimento LGPD não se cadastra nem se confirma medicação (RN-001)")
    void semConsentimento() throws Exception {
        String[] ana = cuidadoraComCasa("med-comconsent@aura.com");
        String medId = criaMedicacao(ana[0], ana[1]);

        String semAceite = signup("med-semconsent@aura.com");

        mvc.perform(post("/api/v1/homes/{homeId}/medications", ana[1]).header("Authorization", semAceite)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(LOSARTANA))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.error.code").value("CONSENT_REQUIRED"));

        mvc.perform(post("/api/v1/medications/{medId}/confirm", medId).header("Authorization", semAceite))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.error.code").value("CONSENT_REQUIRED"));
    }

    @Test
    @DisplayName("horário fora de \"HH:mm\" é VALIDATION_ERROR, na criação e na edição")
    void scheduleMalformado() throws Exception {
        String[] ana = cuidadoraComCasa("med-schedule@aura.com");
        String auth = ana[0];
        String homeId = ana[1];

        mvc.perform(post("/api/v1/homes/{homeId}/medications", homeId).header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Prolopa","schedule":["8h e 20h"]}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.error.details['schedule[0]']").exists());

        // hora que não existe no relógio também não passa
        mvc.perform(post("/api/v1/homes/{homeId}/medications", homeId).header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Prolopa","schedule":["25:00"]}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));

        mvc.perform(post("/api/v1/homes/{homeId}/medications", homeId).header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"  ","schedule":["08:00"]}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.error.details.name").exists());

        String medId = criaMedicacao(auth, homeId);
        mvc.perform(put("/api/v1/medications/{medId}", medId).header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"schedule":["manhã"]}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));

        // nada foi gravado: a lista segue com o horário válido original
        mvc.perform(get("/api/v1/homes/{homeId}/medications", homeId).header("Authorization", auth))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].schedule[0]").value("08:00"));
    }

    @Test
    @DisplayName("exclusão LGPD da casa leva junto as medicações (RN-016)")
    void exclusaoDaCasaApagaMedicacoes() throws Exception {
        String[] ana = cuidadoraComCasa("med-lgpd@aura.com");
        String auth = ana[0];
        String homeId = ana[1];
        String medId = criaMedicacao(auth, homeId);

        mvc.perform(delete("/api/v1/homes/{homeId}", homeId).header("Authorization", auth))
                .andExpect(status().isOk());

        mvc.perform(put("/api/v1/medications/{medId}", medId).header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"active":false}"""))
                .andExpect(status().isNotFound());
    }
}
