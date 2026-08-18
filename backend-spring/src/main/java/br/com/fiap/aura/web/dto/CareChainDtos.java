package br.com.fiap.aura.web.dto;

import br.com.fiap.aura.domain.enums.OrderStage;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class CareChainDtos {

    private CareChainDtos() { }

    public record CreateRecommendationRequest(@NotNull UUID homeId, UUID scoreId) { }

    @Schema(description = """
            Recomendação explicada. `reason` é o texto que a cuidadora lê antes de aprovar e passa
            pelo guardrail de não-prescrição. Enquanto `status` for `recommended`, nenhum pedido existe:
            só a aprovação humana cria o pedido (RN-022).""")
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

    @Schema(description = "Pedido da cadeia de segurança, com SLA e dados da entrega roteada ao nó mais próximo.")
    public record OrderDetailResponse(UUID orderId, OrderStage stage, String sku, String productName,
                                      SlaResponse sla, DeliveryResponse delivery, Instant createdAt) { }
}
