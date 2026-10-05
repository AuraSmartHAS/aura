package br.com.fiap.aura.infra;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.fiap.aura.intelligence.RawUuid;
import br.com.fiap.aura.repository.HomeRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/**
 * O requisito central da Fase 6, ponta a ponta: REST → Java → JDBC → Oracle.
 *
 * <p>A classe não é {@code @Transactional} de propósito. Num teste transacional a requisição nunca
 * commita, o evento AFTER_COMMIT nunca dispara e o teste passaria sem o banco ter gravado nada.
 * Aqui cada requisição commita de verdade e o aviso é lido numa requisição separada.
 */
@AutoConfigureMockMvc
class OracleIntelligenceFlowTest extends OracleTestSupport {

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired JdbcTemplate jdbc;
    @Autowired HomeRepository homes;

    private String login(String email) throws Exception {
        return "Bearer " + body(mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"aura1234"}""".formatted(email)))
                .andExpect(status().isOk())).get("token").asText();
    }

    private JsonNode body(ResultActions res) throws Exception {
        return json.readTree(res.andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8));
    }

    private UUID casaDaMaria() {
        return homes.findAll().stream().filter(h -> "Maria S.".equals(h.getPatientName()))
                .findFirst().orElseThrow().getId();
    }

    private int avisosDeQuaseQueda(UUID homeId) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM alerta WHERE home_id = ? AND regra = 'QUASE_QUEDA'",
                Integer.class, (Object) RawUuid.toBytes(homeId));
    }

    @Test
    @DisplayName("Quase-queda registrada pela API vira aviso gravado pela procedure, sem chamada extra")
    void quaseQuedaPelaApiViraAvisoNoBanco() throws Exception {
        String ana = login("ana@aura.com");
        UUID maria = casaDaMaria();
        // põe a casa em dia antes de medir, para o +1 abaixo ser só desta leitura
        mvc.perform(post("/api/v1/homes/{id}/alertas/processar", maria).header("Authorization", ana))
                .andExpect(status().isOk());
        int antes = avisosDeQuaseQueda(maria);

        mvc.perform(post("/api/v1/signals").header("Authorization", ana).contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s","type":"mobility","source":"self_report",
                                 "value":{"event":"near_fall","place":"kitchen"}}""".formatted(maria)))
                .andExpect(status().isCreated());

        // requisição separada: o aviso só existe se o listener commitou numa transação própria
        assertThat(avisosDeQuaseQueda(maria)).isEqualTo(antes + 1);
        JsonNode alertas = body(mvc.perform(get("/api/v1/homes/{id}/alertas", maria).header("Authorization", ana))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.engine").value("oracle")));
        assertThat(alertas.get("alertas").findValuesAsText("mensagem"))
                .anySatisfy(m -> assertThat(m).startsWith("Quase-queda registrada · cozinha · pelo app · "));

        // repetir não duplica (UNIQUE + DUP_VAL_ON_INDEX)
        mvc.perform(post("/api/v1/homes/{id}/alertas/processar", maria).header("Authorization", ana))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.engine").value("oracle"))
                .andExpect(jsonPath("$.novos").value(0));
        assertThat(avisosDeQuaseQueda(maria)).isEqualTo(antes + 1);
    }

    @Test
    @DisplayName("Aviso marcado como visto muda de status; casa alheia continua dando 403")
    void marcarVistoRespeitaACasa() throws Exception {
        String ana = login("ana@aura.com");
        UUID maria = casaDaMaria();
        mvc.perform(post("/api/v1/homes/{id}/alertas/processar", maria).header("Authorization", ana));
        String alertaId = body(mvc.perform(get("/api/v1/homes/{id}/alertas", maria).header("Authorization", ana)))
                .get("alertas").get(0).get("id").asText();

        mvc.perform(post("/api/v1/alertas/{id}/visto", alertaId).header("Authorization", login("carlos@aura.com")))
                .andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/alertas/{id}/visto", alertaId).header("Authorization", ana))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("visto"));
        assertThat(jdbc.queryForObject("SELECT status FROM alerta WHERE id = HEXTORAW(?)", String.class,
                alertaId.replace("-", ""))).isEqualTo("visto");
    }

    @Test
    @DisplayName("Relatório de consumo vem do cursor da procedure; período invertido é 422 em português")
    void relatorioDeConsumo() throws Exception {
        String ana = login("ana@aura.com");
        UUID maria = casaDaMaria();

        mvc.perform(get("/api/v1/homes/{id}/relatorio-consumo", maria).header("Authorization", ana))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.engine").value("oracle"))
                .andExpect(jsonPath("$.totalDoses").isNumber())
                .andExpect(jsonPath("$.demandaEncaminhadaReais").isNumber())
                .andExpect(jsonPath("$.itens.length()").value(3))
                .andExpect(jsonPath("$.itens[?(@.medicamento == 'Levodopa + Carbidopa')].adesaoPct").isNotEmpty());

        mvc.perform(get("/api/v1/homes/{id}/relatorio-consumo", maria).header("Authorization", ana)
                        .param("de", "2026-10-04").param("ate", "2026-10-01"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.error.message").value("Período inválido: a data final vem antes da inicial"));
    }

    @Test
    @DisplayName("Consolidação em lote grava uma linha por casa e a Operação lê o dia mais recente")
    void consolidacaoEIndicadores() throws Exception {
        String admin = login("admin@aura.com");
        long casas = homes.count();

        mvc.perform(post("/api/v1/ops/indicadores/consolidar").header("Authorization", admin))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.casasProcessadas").value(casas));
        mvc.perform(get("/api/v1/ops/indicadores").header("Authorization", admin))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.engine").value("oracle"))
                .andExpect(jsonPath("$.dataRef").exists())
                .andExpect(jsonPath("$.casas.length()").value(casas));
    }

    @Test
    @DisplayName("Excluir a casa (LGPD) leva junto os avisos dela, sem erro de chave estrangeira")
    void exclusaoDaCasaLevaOsAvisos() throws Exception {
        String email = "lgpd-oracle-" + UUID.randomUUID() + "@aura.com";
        String auth = "Bearer " + body(mvc.perform(post("/api/v1/auth/signup").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"aura1234","role":"cuidadora"}""".formatted(email)))
                .andExpect(status().isCreated())).get("token").asText();
        mvc.perform(post("/api/v1/consent").header("Authorization", auth)).andExpect(status().isCreated());
        String homeId = body(mvc.perform(post("/api/v1/homes").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"patientName":"Teste LGPD","cep":"01310100","label":"Casa teste"}"""))
                .andExpect(status().isCreated())).get("homeId").asText();
        mvc.perform(post("/api/v1/signals").header("Authorization", auth).contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s","type":"mobility","source":"voice",
                                 "value":{"event":"near_fall","place":"bathroom"}}""".formatted(homeId)))
                .andExpect(status().isCreated());
        assertThat(avisosDeQuaseQueda(UUID.fromString(homeId))).isEqualTo(1);

        mvc.perform(delete("/api/v1/homes/{id}", homeId).header("Authorization", auth))
                .andExpect(status().is2xxSuccessful());
        assertThat(avisosDeQuaseQueda(UUID.fromString(homeId))).isZero();
    }
}
