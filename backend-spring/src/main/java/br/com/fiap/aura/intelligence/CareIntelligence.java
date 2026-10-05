package br.com.fiap.aura.intelligence;

import br.com.fiap.aura.web.dto.IntelligenceDtos;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Porta da inteligência de cuidado que mora no banco (functions e procedures PL/SQL).
 *
 * <p>Duas implementações, escolhidas pelo perfil Spring:
 * <ul>
 *   <li>{@link OracleCareIntelligence} (perfil {@code oracle}): chama o PL/SQL por JDBC;</li>
 *   <li>{@link CareIntelligenceUnavailable} (demais perfis): H2 e PostgreSQL não têm as rotinas,
 *       então responde "indisponível" em vez de quebrar.</li>
 * </ul>
 *
 * <p>Esta interface não confere permissão: quem chama ({@link IntelligenceService}) já resolveu
 * {@code requireAccess}. O PL/SQL recebe só o id da casa.
 */
public interface CareIntelligence {

    String ORACLE = "oracle";
    String INDISPONIVEL = "indisponivel";

    /** {@code "oracle"} ou {@code "indisponivel"}; vai em toda resposta. */
    String engine();

    /** PRC_REGISTRAR_ALERTAS: examina a casa e devolve quantos avisos novos gravou. */
    int registrarAlertas(UUID homeId);

    /** Avisos mais recentes primeiro, com a mensagem crua (o guardrail é aplicado por quem chama). */
    List<IntelligenceDtos.Alerta> listarAlertas(UUID homeId, int limite);

    /** Casa dona do aviso, para conferir acesso antes de marcá-lo como visto. */
    Optional<UUID> casaDoAlerta(UUID alertaId);

    void marcarVisto(UUID alertaId);

    /** PRC_RELATORIO_CONSUMO. Período inválido sai como erro 422 (ORA-20001). */
    IntelligenceDtos.RelatorioConsumoResponse relatorioConsumo(UUID homeId, LocalDate de, LocalDate ate);

    /** PRC_CONSOLIDAR_INDICADORES: devolve quantas casas foram consolidadas. */
    int consolidarIndicadores(LocalDate dataRef);

    /** Indicadores do dia mais recente consolidado. */
    IntelligenceDtos.IndicadoresResponse indicadores();
}
