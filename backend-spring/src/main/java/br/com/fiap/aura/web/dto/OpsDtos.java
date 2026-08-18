package br.com.fiap.aura.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

public final class OpsDtos {

    private OpsDtos() { }

    @Schema(description = """
            KPIs da Torre de Controle, calculados sobre os pedidos reais do banco — não são valores fixos.
            `otif`: entregues dentro do SLA / total entregues (meta >= 0,95).
            `fillRate`: itens do catálogo com estoque próximo (meta >= 0,90).
            `leadTimeHours`: média entre criação e entrega.""")
    public record KpiResponse(double otif, double fillRate, double leadTimeHours,
                              long openOrders, long slaBreaches, long homes, long signals,
                              long highRiskScores, String uptime, List<StageCount> byStage) { }

    public record StageCount(String stage, long count) { }

    public record HealthResponse(
            @Schema(example = "ok") String status,
            @Schema(example = "1.0.0") String version,
            @Schema(example = "dev") String env) { }
}
