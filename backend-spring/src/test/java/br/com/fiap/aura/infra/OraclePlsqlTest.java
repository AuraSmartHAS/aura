package br.com.fiap.aura.infra;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.sql.Date;
import java.sql.Types;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.ColumnMapRowMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.SqlOutParameter;
import org.springframework.jdbc.core.SqlParameter;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;

/**
 * Cada function e procedure do PL/SQL, chamada direto no banco com os dados do seed.
 *
 * <p>Sem {@code @Transactional}: as rotinas rodam em autocommit, como rodariam no SQL Developer.
 * As asserções valem para o seed (Maria com adesão acompanhada, quase-queda recente e pulseira em
 * queda; seu Antônio sem nenhuma dose marcada no app).
 */
class OraclePlsqlTest extends OracleTestSupport {

    @Autowired JdbcTemplate jdbc;

    private byte[] casa(String paciente) {
        return jdbc.queryForObject("SELECT id FROM homes WHERE patient_name = ?", byte[].class, paciente);
    }

    @Test
    void esquemaTemAs16TabelasDoModelo() {
        Integer tabelas = jdbc.queryForObject(
                "SELECT COUNT(*) FROM user_tables WHERE UPPER(table_name) <> 'FLYWAY_SCHEMA_HISTORY'",
                Integer.class);
        assertThat(tabelas).isEqualTo(16);
        List<String> regras = jdbc.queryForList(
                "SELECT codigo FROM regra_alerta WHERE ativa = 1 ORDER BY codigo", String.class);
        assertThat(regras).containsExactly("ADESAO_BAIXA", "DOSES_NEGADAS", "QUASE_QUEDA", "ROTINA_PASSOS");
    }

    @Test
    void taxaDeAdesaoEUmPercentualOuNuloSemDado() {
        BigDecimal maria = jdbc.queryForObject(
                "SELECT fn_taxa_adesao(id, NULL, 7) FROM homes WHERE patient_name = 'Maria S.'", BigDecimal.class);
        assertThat(maria).isBetween(BigDecimal.ZERO, new BigDecimal("100"));

        // Seu Antônio tem medicações, mas nenhuma dose marcada no app: é falta de dado, não 0%.
        BigDecimal antonio = jdbc.queryForObject(
                "SELECT fn_taxa_adesao(id, NULL, 7) FROM homes WHERE patient_name = 'Antônio R.'", BigDecimal.class);
        assertThat(antonio).isNull();

        // Casa que nem existe também não é erro.
        BigDecimal inexistente = jdbc.queryForObject(
                "SELECT fn_taxa_adesao(HEXTORAW('00000000000000000000000000000000')) FROM dual", BigDecimal.class);
        assertThat(inexistente).isNull();
    }

    @Test
    void descreveLeituraEmPortuguesSemVerboDeDose() {
        String texto = jdbc.queryForObject("""
                SELECT fn_descrever_leitura(s.id) FROM signals s JOIN homes h ON h.id = s.home_id
                 WHERE h.patient_name = 'Maria S.' AND JSON_VALUE(s.signal_value, '$.event') = 'near_fall'
                 FETCH FIRST 1 ROWS ONLY""", String.class);
        assertThat(texto).startsWith("Quase-queda registrada · banheiro · por voz · ");

        List<String> pulseira = jdbc.queryForList("""
                SELECT fn_descrever_leitura(s.id) FROM signals s WHERE s.type = 'VITALS'""", String.class);
        assertThat(pulseira).isNotEmpty().allSatisfy(t -> assertThat(t).startsWith("Pulseira: ").contains(" passos"));

        List<String> doses = jdbc.queryForList("""
                SELECT fn_descrever_leitura(s.id) FROM signals s WHERE s.type = 'ADHERENCE'""", String.class);
        assertThat(doses).allSatisfy(t -> assertThat(t.toLowerCase()).doesNotContain("tomar", "tome"));

        assertThat(jdbc.queryForObject(
                "SELECT fn_descrever_leitura(HEXTORAW('00000000000000000000000000000000')) FROM dual",
                String.class)).isEqualTo("Leitura não encontrada");
    }

    @Test
    void variacaoDeRotinaComparaComAPropriaPessoa() {
        BigDecimal passos = jdbc.queryForObject(
                "SELECT fn_variacao_rotina(id, 'steps') FROM homes WHERE patient_name = 'Maria S.'", BigDecimal.class);
        // Seed: passos caindo de 4.200 para 1.800 em 21 dias.
        assertThat(passos).isNegative();
        assertThatThrownBy(() -> jdbc.queryForObject(
                "SELECT fn_variacao_rotina(id, 'pressao') FROM homes WHERE patient_name = 'Maria S.'", BigDecimal.class))
                .hasMessageContaining("ORA-20003");
    }

    @Test
    void registrarAlertasEIdempotente() {
        SimpleJdbcCall call = new SimpleJdbcCall(jdbc).withProcedureName("PRC_REGISTRAR_ALERTAS")
                .withoutProcedureColumnMetaDataAccess()
                .declareParameters(
                        new SqlParameter("p_home_id", Types.BINARY),
                        new SqlParameter("p_janela_horas", Types.NUMERIC),
                        new SqlOutParameter("p_novos", Types.NUMERIC));
        byte[] maria = casa("Maria S.");

        call.execute(Map.of("p_home_id", maria, "p_janela_horas", 48));
        Integer depoisDaPrimeira = jdbc.queryForObject(
                "SELECT COUNT(*) FROM alerta WHERE home_id = ?", Integer.class, (Object) maria);
        Map<String, Object> segunda = call.execute(Map.of("p_home_id", maria, "p_janela_horas", 48));

        assertThat(((Number) segunda.get("p_novos")).intValue()).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM alerta WHERE home_id = ?", Integer.class, (Object) maria))
                .isEqualTo(depoisDaPrimeira);
        // A quase-queda do seed é de agora: tem de estar entre os avisos, com o texto da function.
        assertThat(jdbc.queryForList(
                "SELECT mensagem FROM alerta WHERE home_id = ? AND regra = 'QUASE_QUEDA'", String.class, (Object) maria))
                .anySatisfy(m -> assertThat(m).startsWith("Quase-queda registrada"));
    }

    @Test
    void relatorioDeConsumoDevolveTotaisECursor() {
        SimpleJdbcCall call = new SimpleJdbcCall(jdbc).withProcedureName("PRC_RELATORIO_CONSUMO")
                .withoutProcedureColumnMetaDataAccess()
                .declareParameters(
                        new SqlParameter("p_home_id", Types.BINARY),
                        new SqlParameter("p_de", Types.DATE),
                        new SqlParameter("p_ate", Types.DATE),
                        new SqlOutParameter("p_total_doses", Types.NUMERIC),
                        new SqlOutParameter("p_total_reais", Types.NUMERIC),
                        new SqlOutParameter("p_itens", Types.REF_CURSOR, new ColumnMapRowMapper()));
        LocalDate hoje = LocalDate.now();
        Map<String, Object> out = call.execute(Map.of(
                "p_home_id", casa("Maria S."),
                "p_de", Date.valueOf(hoje.minusDays(20)),
                "p_ate", Date.valueOf(hoje)));

        assertThat(((Number) out.get("p_total_doses")).intValue()).isPositive();
        assertThat((List<?>) out.get("p_itens")).hasSize(3);

        assertThatThrownBy(() -> call.execute(Map.of(
                "p_home_id", casa("Maria S."),
                "p_de", Date.valueOf(hoje),
                "p_ate", Date.valueOf(hoje.minusDays(1)))))
                .hasMessageContaining("ORA-20001");
    }

    @Test
    void consolidarIndicadoresGravaUmaLinhaPorCasa() {
        SimpleJdbcCall call = new SimpleJdbcCall(jdbc).withProcedureName("PRC_CONSOLIDAR_INDICADORES")
                .withoutProcedureColumnMetaDataAccess()
                .declareParameters(
                        new SqlParameter("p_data_ref", Types.DATE),
                        new SqlOutParameter("p_casas", Types.NUMERIC));
        Map<String, Object> out = call.execute(java.util.Collections.singletonMap("p_data_ref", null));
        Integer casas = jdbc.queryForObject("SELECT COUNT(*) FROM homes", Integer.class);

        assertThat(((Number) out.get("p_casas")).intValue()).isEqualTo(casas);
        // MERGE: rodar de novo no mesmo dia atualiza, não duplica.
        call.execute(java.util.Collections.singletonMap("p_data_ref", null));
        assertThat(jdbc.queryForObject("""
                SELECT COUNT(*) FROM indicador_diario
                 WHERE data_ref = TRUNC(CAST(SYSTIMESTAMP AT TIME ZONE 'America/Sao_Paulo' AS DATE))""",
                Integer.class)).isEqualTo(casas);
    }
}
