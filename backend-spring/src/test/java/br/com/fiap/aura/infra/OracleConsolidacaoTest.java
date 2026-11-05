package br.com.fiap.aura.infra;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.fiap.aura.intelligence.RawUuid;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
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
 * Fase 7: as rotinas da Fase 6 consolidadas em packages, as duas triggers e o Dynamic SQL.
 *
 * <p>Sem {@code @Transactional}, como o {@link OracleIntelligenceFlowTest}: cada passo commita de
 * verdade, então o que a trigger gravou é lido como o painel leria.
 */
@AutoConfigureMockMvc
class OracleConsolidacaoTest extends OracleTestSupport {

    private static final String UUID_TEXTO = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}";

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired JdbcTemplate jdbc;

    @Test
    @DisplayName("As nove rotinas soltas da Fase 6 agora moram em cinco packages válidos")
    void rotinasDaFase6MoramEmPackages() {
        assertThat(jdbc.queryForList(
                "SELECT object_name FROM user_objects WHERE object_type IN ('FUNCTION', 'PROCEDURE')", String.class))
                .as("nenhuma function ou procedure solta").isEmpty();
        assertThat(jdbc.queryForList("""
                SELECT object_name || ' ' || object_type || ' ' || status FROM user_objects
                 WHERE object_type IN ('PACKAGE', 'PACKAGE BODY') ORDER BY object_name, object_type""", String.class))
                .containsExactly(
                        "PKG_ALERTAS PACKAGE VALID", "PKG_ALERTAS PACKAGE BODY VALID",
                        "PKG_APOIO PACKAGE VALID", "PKG_APOIO PACKAGE BODY VALID",
                        "PKG_LEITURA PACKAGE VALID", "PKG_LEITURA PACKAGE BODY VALID",
                        "PKG_MEDICACAO PACKAGE VALID", "PKG_MEDICACAO PACKAGE BODY VALID",
                        "PKG_RELATORIO PACKAGE VALID", "PKG_RELATORIO PACKAGE BODY VALID");
        assertThat(jdbc.queryForList(
                "SELECT trigger_name || ' ' || status FROM user_triggers ORDER BY trigger_name", String.class))
                .containsExactly("TRG_MEDICACAO_ESTOQUE_BAIXO ENABLED", "TRG_REGRA_ALERTA_AUDITORIA ENABLED");
    }

    @Test
    @DisplayName("Auditoria: mudar, criar ou apagar uma regra de aviso deixa o antes e o depois")
    void mudarUmLimiarDeixaRastro() {
        try {
            jdbc.update("UPDATE regra_alerta SET limiar = 70 WHERE codigo = 'ADESAO_BAIXA'");
            Map<String, Object> ultima = jdbc.queryForMap("""
                    SELECT operacao, limiar_antes, limiar_depois, usuario_banco, programa FROM regra_alerta_hist
                     WHERE codigo = 'ADESAO_BAIXA' ORDER BY id DESC FETCH FIRST 1 ROW ONLY""");
            assertThat(ultima.get("OPERACAO")).isEqualTo("UPDATE");
            assertThat(((Number) ultima.get("LIMIAR_ANTES")).intValue()).isEqualTo(80);
            assertThat(((Number) ultima.get("LIMIAR_DEPOIS")).intValue()).isEqualTo(70);
            assertThat(ultima.get("USUARIO_BANCO")).isEqualTo("AURA");
            assertThat(ultima.get("PROGRAMA")).isNotNull();
        } finally {
            jdbc.update("UPDATE regra_alerta SET limiar = 80 WHERE codigo = 'ADESAO_BAIXA'");
        }

        // Inativa desde o nascimento: o PKG_ALERTAS nunca chega a avaliá-la.
        jdbc.update("""
                INSERT INTO regra_alerta (codigo, descricao, severidade, limiar, janela_horas, ativa, versao)
                VALUES ('TESTE_AUDITORIA', 'Regra de teste', 'info', 1, 1, 0, 'teste')""");
        jdbc.update("DELETE FROM regra_alerta WHERE codigo = 'TESTE_AUDITORIA'");
        assertThat(jdbc.queryForList(
                "SELECT operacao FROM regra_alerta_hist WHERE codigo = 'TESTE_AUDITORIA' ORDER BY id", String.class))
                .containsExactly("INSERT", "DELETE");
    }

    @Test
    @DisplayName("Automação: a dose que deixa o remédio com 3 dias ou menos vira aviso no painel, uma vez só")
    void doseQueCruzaALinhaViraAvisoNoPainel() throws Exception {
        String ana = login("ana@aura.com");
        UUID maria = casaDaMaria();
        // 2 doses/dia e 7 em estoque = 3,5 dias: o cadastro fica uma dose acima da linha e não avisa.
        String remedio = remedioPelaApi(ana, maria, "Remédio do teste de estoque");
        try {
            assertThat(avisosDeEstoque(remedio)).isZero();

            confirmaDose(ana, remedio);
            assertThat(avisosDeEstoque(remedio)).isEqualTo(1);
            confirmaDose(ana, remedio); // já abaixo da linha: não repete
            assertThat(avisosDeEstoque(remedio)).isEqualTo(1);

            JsonNode alertas = body(mvc.perform(get("/api/v1/homes/{id}/alertas", maria).header("Authorization", ana))
                    .andExpect(status().isOk()));
            assertThat(alertas.get("alertas").findValuesAsText("mensagem")).contains(
                    "Estoque acabando · Remédio do teste de estoque: 6 doses, cobertura de 3,0 dias pela rotina declarada");
        } finally {
            desativa(remedio);
        }
    }

    @Test
    @DisplayName("Guardrail: o aviso que embute um nome com verbo de dose não sai nem em /alertas nem em /consulta")
    void avisoComTextoReprovadoNaoSaiPelaApi() throws Exception {
        String ana = login("ana@aura.com");
        UUID maria = casaDaMaria();
        String remedio = remedioPelaApi(ana, maria, "Dipirona 500 mg de manhã");
        try {
            confirmaDose(ana, remedio);
            assertThat(avisosDeEstoque(remedio)).as("o banco gravou o aviso").isEqualTo(1);

            JsonNode alertas = body(mvc.perform(get("/api/v1/homes/{id}/alertas", maria).header("Authorization", ana)));
            JsonNode consulta = body(mvc.perform(get("/api/v1/homes/{id}/consulta", maria).header("Authorization", ana)
                    .param("entidade", "alerta").param("coluna", "regra").param("valor", "ESTOQUE_BAIXO")));
            JsonNode grupos = body(mvc.perform(get("/api/v1/homes/{id}/consulta/agrupada", maria)
                    .header("Authorization", ana).param("entidade", "alerta").param("coluna", "mensagem")));
            assertThat(alertas.get("alertas").findValuesAsText("mensagem")).noneMatch(m -> m.contains("Dipirona 500 mg de manhã"));
            assertThat(consulta.get("linhas").findValuesAsText("mensagem")).noneMatch(m -> m.contains("Dipirona 500 mg de manhã"));
            assertThat(grupos.get("linhas").findValuesAsText("valor")).noneMatch(m -> m.contains("Dipirona 500 mg de manhã"));
        } finally {
            desativa(remedio);
        }
    }

    @Test
    @DisplayName("Regra desligada não avisa, e a falha do aviso nunca desfaz a gravação do estoque")
    void falhaNoAvisoNaoDerrubaAGravacao() {
        String casa = casaDeTeste();
        String desligada = novoRemedio(casa, 7);
        String travada = novoRemedio(casa, 7);
        try {
            jdbc.update("UPDATE regra_alerta SET ativa = 0 WHERE codigo = 'ESTOQUE_BAIXO'");
            jdbc.update("UPDATE medications SET stock_doses = 2 WHERE id = HEXTORAW(?)", desligada);
            assertThat(avisosDeEstoque(desligada)).isZero();
        } finally {
            jdbc.update("UPDATE regra_alerta SET ativa = 1 WHERE codigo = 'ESTOQUE_BAIXO'");
        }

        int errosAntes = jdbc.queryForObject(
                "SELECT COUNT(*) FROM log_erro_plsql WHERE origem = 'TRG_MEDICACAO_ESTOQUE_BAIXO'", Integer.class);
        try {
            // ALERTA só leitura: o INSERT do aviso falha dentro da trigger.
            jdbc.execute("ALTER TABLE alerta READ ONLY");
            jdbc.update("UPDATE medications SET stock_doses = 2 WHERE id = HEXTORAW(?)", travada);
        } finally {
            jdbc.execute("ALTER TABLE alerta READ WRITE");
        }
        assertThat(jdbc.queryForObject("SELECT stock_doses FROM medications WHERE id = HEXTORAW(?)",
                Integer.class, travada)).as("a gravação do estoque ficou").isEqualTo(2);
        assertThat(jdbc.queryForObject(
                "SELECT COUNT(*) FROM log_erro_plsql WHERE origem = 'TRG_MEDICACAO_ESTOQUE_BAIXO'", Integer.class))
                .as("a falha foi registrada").isEqualTo(errosAntes + 1);
    }

    @Test
    @DisplayName("Dynamic SQL pela API: entidade, filtro, ordem e limite escolhidos na hora, com lista branca")
    void consultaDinamicaPelaApi() throws Exception {
        String ana = login("ana@aura.com");
        UUID maria = casaDaMaria();
        String base = "/api/v1/homes/" + maria + "/consulta";

        JsonNode sono = body(mvc.perform(get(base).header("Authorization", ana)
                        .param("entidade", "signals").param("coluna", "type").param("valor", "SLEEP")
                        .param("ordem", "captured_at").param("limite", "5"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.engine").value("oracle")));
        assertThat(sono.get("linhas")).isNotEmpty().hasSizeLessThanOrEqualTo(5);
        assertThat(sono.get("linhas").findValuesAsText("type")).containsOnly("SLEEP");
        assertThat(sono.get("linhas").get(0).get("id").asText()).matches(UUID_TEXTO);

        // O id sai no formato da API e volta como filtro sem conversão nenhuma.
        String remedio = body(mvc.perform(get("/api/v1/homes/{id}/medications", maria).header("Authorization", ana)))
                .get(0).get("id").asText();
        mvc.perform(get(base).header("Authorization", ana)
                        .param("entidade", "medications").param("coluna", "id").param("valor", remedio))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.linhas.length()").value(1))
                .andExpect(jsonPath("$.linhas[0].id").value(remedio));

        // Valor que não converte para o tipo da coluna só não encontra nada.
        for (String coluna : List.of("stock_doses", "created_at")) {
            mvc.perform(get(base).header("Authorization", ana)
                            .param("entidade", "medications").param("coluna", coluna).param("valor", "ontem"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.linhas.length()").value(0));
        }

        JsonNode porTipo = body(mvc.perform(get(base + "/agrupada").header("Authorization", ana)
                        .param("entidade", "signals").param("coluna", "type"))
                .andExpect(status().isOk()));
        assertThat(porTipo.get("linhas").get(0).get("total").asInt()).isPositive();

        // Fora da lista branca, injeção no nome da coluna e na ordem: 400, nunca 500.
        mvc.perform(get(base).header("Authorization", ana).param("entidade", "users"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error.code").value("CONSULTA_INVALIDA"));
        mvc.perform(get(base).header("Authorization", ana).param("entidade", "signals")
                        .param("coluna", "type = type OR 1=1 --"))
                .andExpect(status().isBadRequest());
        mvc.perform(get(base).header("Authorization", ana).param("entidade", "signals")
                        .param("ordem", "1; DROP TABLE signals"))
                .andExpect(status().isBadRequest());

        mvc.perform(get(base).header("Authorization", login("carlos@aura.com")).param("entidade", "signals"))
                .andExpect(status().isForbidden());
    }

    private String login(String email) throws Exception {
        return "Bearer " + body(mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"aura1234"}""".formatted(email)))
                .andExpect(status().isOk())).get("token").asText();
    }

    private void confirmaDose(String auth, String remedio) throws Exception {
        mvc.perform(post("/api/v1/medications/{id}/confirm", remedio).header("Authorization", auth))
                .andExpect(status().isCreated());
    }

    private String remedioPelaApi(String auth, UUID casa, String nome) throws Exception {
        return body(mvc.perform(post("/api/v1/homes/{id}/medications", casa).header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"%s","schedule":["08:00","20:00"],"stockDoses":7}""".formatted(nome)))
                .andExpect(status().isCreated())).get("id").asText();
    }

    // As outras classes do Oracle contam os remédios ativos da Maria; o que o teste cria não pode sobrar.
    private void desativa(String remedio) {
        jdbc.update("UPDATE medications SET active = 0 WHERE id = HEXTORAW(?)", hex(UUID.fromString(remedio)));
    }

    // Casa só deste teste, da Ana: nada do que a trigger fizer aqui aparece na casa da Maria.
    private String casaDeTeste() {
        String id = hex(UUID.randomUUID());
        jdbc.update("""
                INSERT INTO homes (id, owner_user_id, patient_name, created_at)
                SELECT HEXTORAW(?), id, 'Casa da trigger', SYSTIMESTAMP FROM users WHERE email = 'ana@aura.com'""", id);
        return id;
    }

    private String novoRemedio(String casa, int estoque) {
        String id = hex(UUID.randomUUID());
        jdbc.update("""
                INSERT INTO medications (id, home_id, name, schedule, stock_doses, active, created_at)
                VALUES (HEXTORAW(?), HEXTORAW(?), 'Remédio da trigger', '["08:00","20:00"]', ?, 1, SYSTIMESTAMP)""",
                id, casa, estoque);
        return id;
    }

    private int avisosDeEstoque(String remedio) {
        String hex = remedio.contains("-") ? hex(UUID.fromString(remedio)) : remedio;
        return jdbc.queryForObject(
                "SELECT COUNT(*) FROM alerta WHERE regra = 'ESTOQUE_BAIXO' AND chave_dedup LIKE ? || '-%'",
                Integer.class, hex);
    }

    private UUID casaDaMaria() {
        return RawUuid.fromBytes(casaDoSeed(jdbc, "Maria S."));
    }

    private static String hex(UUID id) {
        return id.toString().replace("-", "").toUpperCase();
    }

    private JsonNode body(ResultActions res) throws Exception {
        return json.readTree(res.andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8));
    }
}
