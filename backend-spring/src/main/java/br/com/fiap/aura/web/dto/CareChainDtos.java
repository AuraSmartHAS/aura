package br.com.fiap.aura.web.dto;

import br.com.fiap.aura.domain.enums.OrderStage;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class CareChainDtos {

    private CareChainDtos() { }

    public record CreateRecommendationRequest(@NotNull UUID homeId, UUID scoreId) { }

    public record RecommendationResponse(UUID recommendationId, String sku, String productName,
                                         String reason, String status,
                                         List<String> factors, List<Double> weights) { }

    public record ApproveResponse(UUID orderId, OrderStage stage) { }

    public record AdvanceResponse(OrderStage stage, Instant etaDelivery, Instant installAt, boolean slaBreached) { }

    public record OrderSummaryResponse(UUID id, OrderStage stage, String sku, String productName,
                                       Instant slaDueAt, boolean slaBreached, Instant createdAt,
                                       UUID recommendationId) { }

    public record SlaResponse(Instant dueAt, boolean breached, Instant deliveredAt, Instant installedAt) { }

    public record DeliveryResponse(String nodeName, Instant eta, Integer distanceM, String status) { }

    public record OrderDetailResponse(UUID orderId, OrderStage stage, String sku, String productName,
                                      SlaResponse sla, DeliveryResponse delivery, Instant createdAt) { }
}
