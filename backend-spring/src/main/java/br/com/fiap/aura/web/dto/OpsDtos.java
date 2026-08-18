package br.com.fiap.aura.web.dto;

import java.util.List;

public final class OpsDtos {

    private OpsDtos() { }

    /** KPIs da Torre de Controle (NOC) exibidos no painel Angular. */
    public record KpiResponse(double otif, double fillRate, double leadTimeHours,
                              long openOrders, long slaBreaches, long homes, long signals,
                              long highRiskScores, String uptime, List<StageCount> byStage) { }

    public record StageCount(String stage, long count) { }

    public record HealthResponse(String status, String version, String env) { }
}
