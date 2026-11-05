package br.com.fiap.aura.intelligence;

import br.com.fiap.aura.web.dto.IntelligenceDtos;
import br.com.fiap.aura.web.error.ApiException;
import java.math.BigDecimal;
import java.sql.CallableStatement;
import java.sql.Date;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Types;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Supplier;
import org.springframework.context.annotation.Profile;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.SqlOutParameter;
import org.springframework.jdbc.core.SqlParameter;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Component;

/**
 * Adaptador Oracle: o elo Java → JDBC → PL/SQL.
 *
 * <p>{@link SimpleJdbcCall} com parâmetros declarados à mão ({@code withoutProcedureColumnMetaDataAccess}):
 * sem isso o Spring consultaria o dicionário do banco a cada chamada para descobrir nomes e tipos,
 * o que depende de maiúsculas, de schema e de permissão de leitura no catálogo — e o usuário RM do
 * servidor da FIAP não tem garantia de nenhuma das três.
 *
 * <p>Fase 7: as rotinas moram em packages. Para o {@link SimpleJdbcCall} do Oracle o package é o
 * "catalog", então {@code PKG_ALERTAS.REGISTRAR_ALERTAS} vira {@code withCatalogName} +
 * {@code withProcedureName}.
 *
 * <p>Nenhum método abre transação: quem chama decide. O PL/SQL também não faz COMMIT.
 */
@Component
@Profile("oracle")
public class OracleCareIntelligence implements CareIntelligence {

    private final JdbcTemplate jdbc;
    private final SimpleJdbcCall registrarAlertas;
    private final SimpleJdbcCall relatorioConsumo;
    private final SimpleJdbcCall consolidarIndicadores;

    public OracleCareIntelligence(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
        this.registrarAlertas = new SimpleJdbcCall(jdbc)
                .withCatalogName("PKG_ALERTAS")
                .withProcedureName("REGISTRAR_ALERTAS")
                .withoutProcedureColumnMetaDataAccess()
                .declareParameters(
                        new SqlParameter("p_home_id", Types.BINARY),
                        new SqlParameter("p_janela_horas", Types.NUMERIC),
                        new SqlOutParameter("p_novos", Types.NUMERIC));
        this.relatorioConsumo = new SimpleJdbcCall(jdbc)
                .withCatalogName("PKG_RELATORIO")
                .withProcedureName("CONSUMO")
                .withoutProcedureColumnMetaDataAccess()
                .declareParameters(
                        new SqlParameter("p_home_id", Types.BINARY),
                        new SqlParameter("p_de", Types.DATE),
                        new SqlParameter("p_ate", Types.DATE),
                        new SqlOutParameter("p_total_doses", Types.NUMERIC),
                        new SqlOutParameter("p_total_reais", Types.NUMERIC),
                        new SqlOutParameter("p_itens", Types.REF_CURSOR, OracleCareIntelligence::itemConsumo));
        this.consolidarIndicadores = new SimpleJdbcCall(jdbc)
                .withCatalogName("PKG_RELATORIO")
                .withProcedureName("CONSOLIDAR_INDICADORES")
                .withoutProcedureColumnMetaDataAccess()
                .declareParameters(
                        new SqlParameter("p_data_ref", Types.DATE),
                        new SqlOutParameter("p_casas", Types.NUMERIC));
    }

    @Override
    public String engine() {
        return ORACLE;
    }

    @Override
    public int registrarAlertas(UUID homeId) {
        Map<String, Object> in = new HashMap<>();
        in.put("p_home_id", RawUuid.toBytes(homeId));
        in.put("p_janela_horas", null); // cada regra usa a própria janela de REGRA_ALERTA
        Map<String, Object> out = traduzindoErros(() -> registrarAlertas.execute(in));
        return ((Number) out.get("p_novos")).intValue();
    }

    @Override
    public List<IntelligenceDtos.Alerta> listarAlertas(UUID homeId, int limite) {
        return jdbc.query("""
                SELECT id, regra, severidade, mensagem, status, criado_em
                  FROM alerta
                 WHERE home_id = ?
                 ORDER BY criado_em DESC
                 FETCH FIRST ? ROWS ONLY""",
                (rs, i) -> new IntelligenceDtos.Alerta(
                        RawUuid.fromBytes(rs.getBytes("id")),
                        rs.getString("regra"),
                        rs.getString("severidade"),
                        rs.getString("mensagem"),
                        rs.getString("status"),
                        instante(rs, "criado_em")),
                RawUuid.toBytes(homeId), limite);
    }

    @Override
    public Optional<UUID> casaDoAlerta(UUID alertaId) {
        List<byte[]> casa = jdbc.query("SELECT home_id FROM alerta WHERE id = ?",
                (rs, i) -> rs.getBytes(1), (Object) RawUuid.toBytes(alertaId));
        return casa.stream().findFirst().map(RawUuid::fromBytes);
    }

    @Override
    public void marcarVisto(UUID alertaId) {
        jdbc.update("""
                UPDATE alerta SET status = 'visto', visto_em = SYSTIMESTAMP
                 WHERE id = ? AND status = 'aberto'""", (Object) RawUuid.toBytes(alertaId));
    }

    @Override
    @SuppressWarnings("unchecked")
    public IntelligenceDtos.RelatorioConsumoResponse relatorioConsumo(UUID homeId, LocalDate de, LocalDate ate) {
        Map<String, Object> out = traduzindoErros(() -> relatorioConsumo.execute(Map.of(
                "p_home_id", RawUuid.toBytes(homeId),
                "p_de", Date.valueOf(de),
                "p_ate", Date.valueOf(ate))));
        Number totalDoses = (Number) out.get("p_total_doses");
        return new IntelligenceDtos.RelatorioConsumoResponse(ORACLE, de, ate,
                totalDoses == null ? null : totalDoses.intValue(),
                (BigDecimal) out.get("p_total_reais"),
                (List<IntelligenceDtos.ItemConsumo>) out.get("p_itens"));
    }

    @Override
    public int consolidarIndicadores(LocalDate dataRef) {
        Map<String, Object> in = new HashMap<>();
        in.put("p_data_ref", dataRef == null ? null : Date.valueOf(dataRef));
        Map<String, Object> out = traduzindoErros(() -> consolidarIndicadores.execute(in));
        return ((Number) out.get("p_casas")).intValue();
    }

    @Override
    public IntelligenceDtos.IndicadoresResponse indicadores() {
        Date ultimo = jdbc.queryForObject("SELECT MAX(data_ref) FROM indicador_diario", Date.class);
        if (ultimo == null) {
            return new IntelligenceDtos.IndicadoresResponse(ORACLE, null, List.of());
        }
        List<IntelligenceDtos.IndicadorCasa> casas = jdbc.query("""
                SELECT i.home_id, COALESCE(h.label, h.patient_name) AS casa, i.adesao_pct,
                       i.variacao_passos_pct, i.alertas_abertos, i.atualizado_em
                  FROM indicador_diario i
                  JOIN homes h ON h.id = i.home_id
                 WHERE i.data_ref = ?
                 ORDER BY casa""",
                (rs, i) -> new IntelligenceDtos.IndicadorCasa(
                        RawUuid.fromBytes(rs.getBytes("home_id")),
                        rs.getString("casa"),
                        rs.getBigDecimal("adesao_pct"),
                        rs.getBigDecimal("variacao_passos_pct"),
                        rs.getInt("alertas_abertos"),
                        instante(rs, "atualizado_em")),
                ultimo);
        return new IntelligenceDtos.IndicadoresResponse(ORACLE, ultimo.toLocalDate(), casas);
    }

    @Override
    public List<Map<String, Object>> consultar(UUID homeId, String entidade, String coluna, String valor,
                                               String ordem, int limite) {
        return cursor("{? = call pkg_relatorio.consultar(?, ?, ?, ?, ?, ?)}",
                entidade, RawUuid.toBytes(homeId), coluna, valor, ordem, limite);
    }

    @Override
    public List<Map<String, Object>> agrupar(UUID homeId, String entidade, String coluna) {
        return cursor("{? = call pkg_relatorio.agrupar(?, ?, ?)}", entidade, RawUuid.toBytes(homeId), coluna);
    }

    /** Chama uma function que devolve SYS_REFCURSOR e lê as linhas com as colunas em minúsculas. */
    private List<Map<String, Object>> cursor(String chamada, Object... args) {
        return traduzindoErros(() -> jdbc.execute(chamada, (CallableStatement cs) -> {
            cs.registerOutParameter(1, Types.REF_CURSOR);
            for (int i = 0; i < args.length; i++) {
                cs.setObject(i + 2, args[i]);
            }
            cs.execute();
            try (ResultSet rs = cs.getObject(1, ResultSet.class)) {
                ResultSetMetaData meta = rs.getMetaData();
                List<Map<String, Object>> linhas = new ArrayList<>();
                while (rs.next()) {
                    Map<String, Object> linha = new LinkedHashMap<>();
                    for (int c = 1; c <= meta.getColumnCount(); c++) {
                        linha.put(meta.getColumnLabel(c).toLowerCase(Locale.ROOT), rs.getObject(c));
                    }
                    linhas.add(linha);
                }
                return linhas;
            }
        }));
    }

    private static IntelligenceDtos.ItemConsumo itemConsumo(ResultSet rs, int linha) throws SQLException {
        int estoque = rs.getInt("estoque_doses");
        Integer estoqueDoses = rs.wasNull() ? null : estoque;
        return new IntelligenceDtos.ItemConsumo(
                rs.getString("medicamento"),
                rs.getInt("doses_confirmadas"),
                rs.getInt("doses_negadas"),
                rs.getInt("doses_esperadas"),
                rs.getBigDecimal("adesao_pct"),
                estoqueDoses);
    }

    private static Instant instante(ResultSet rs, String coluna) throws SQLException {
        OffsetDateTime valor = rs.getObject(coluna, OffsetDateTime.class);
        return valor == null ? null : valor.toInstant();
    }

    /**
     * Os erros de negócio do PL/SQL (faixa -20xxx) viram resposta HTTP com mensagem em português;
     * o resto sobe como está e o handler global responde 500 sem vazar o detalhe.
     */
    private static <T> T traduzindoErros(Supplier<T> chamada) {
        try {
            return chamada.get();
        } catch (DataAccessException e) {
            SQLException sql = causaSql(e);
            if (sql != null && sql.getErrorCode() == 20001) {
                throw ApiException.unprocessable("PERIODO_INVALIDO", mensagemDoBanco(sql));
            }
            if (sql != null && sql.getErrorCode() == 20404) {
                throw ApiException.notFound("Casa");
            }
            // Lista branca do Dynamic SQL recusando entidade (20100) ou coluna (20101): erro de quem pediu.
            if (sql != null && (sql.getErrorCode() == 20100 || sql.getErrorCode() == 20101)) {
                throw ApiException.badRequest("CONSULTA_INVALIDA", mensagemDoBanco(sql));
            }
            throw e;
        }
    }

    private static SQLException causaSql(Throwable e) {
        for (Throwable t = e; t != null; t = t.getCause()) {
            if (t instanceof SQLException sql) {
                return sql;
            }
        }
        return null;
    }

    /** "ORA-20001: Período inválido: ...\nORA-06512: ..." vira só "Período inválido: ...". */
    static String mensagemDoBanco(SQLException sql) {
        String msg = sql.getMessage() == null ? "" : sql.getMessage();
        String primeira = msg.lines().findFirst().orElse(msg);
        return primeira.replaceFirst("^ORA-\\d+:\\s*", "").trim();
    }
}
