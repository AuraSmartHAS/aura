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

    @Schema(description = """
            Uma linha da carteira de pedidos da Torre: o pedido como a operação o vê — produto,
            estágio, nó que despachou e situação do SLA. Vem do mesmo banco dos KPIs, nunca de mock.""")
    public record OrderRow(java.util.UUID id, String sku, String productName, String stage,
                           String nodeName, java.time.Instant slaDueAt, boolean slaBreached,
                           java.time.Instant etaDelivery, java.time.Instant createdAt) { }

    public record HealthResponse(
            @Schema(example = "ok") String status,
            @Schema(example = "1.0.0") String version,
            @Schema(example = "dev") String env) { }
}
