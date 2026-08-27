package br.com.fiap.aura.web.dto;

import br.com.fiap.aura.domain.enums.OrderStage;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class CareChainDtos {

    private CareChainDtos() { }

    public record CreateRecommendationRequest(@NotNull UUID homeId, UUID scoreId) { }

    @Schema(description = """
            Recomendação explicada. `reason` é o texto que a cuidadora lê antes de aprovar e passa
            pelo guardrail de não-prescrição. Enquanto `status` for `recommended`, nenhum pedido existe:
            só a aprovação humana cria o pedido (RN-022).
            `factorLabels` traz os mesmos `factors` em português, na MESMA ordem e com o mesmo tamanho —
            nenhuma tela precisa traduzir código. Preço e instalação vêm na própria recomendação para
            que ninguém aprove sem saber o total; são opcionais e vêm nulos quando o SKU saiu do catálogo
            ou quando o item não é instalável.""")
    public record RecommendationResponse(UUID recommendationId, String sku, String productName,
                                         String reason, String status,
                                         List<String> factors, List<Double> weights,
                                         @Schema(example = "[\"quase-queda relatada\", \"ausência de barra de apoio\"]")
                                         List<String> factorLabels,
                                         @Schema(example = "129.90", description = "Preço do item")
                                         BigDecimal price,
                                         @Schema(example = "true", description = "O item é instalado por técnico")
                                         Boolean installable,
                                         @Schema(example = "false", description = "Instalação já inclusa no preço do item")
                                         Boolean installationIncluded,
                                         @Schema(example = "149.90",
                                                 description = "Quanto se paga a mais pela instalação; 0 quando inclusa")
                                         BigDecimal installationPrice,
                                         @Schema(example = "NBR 9050") String normRef) { }

    public record ApproveResponse(UUID orderId, OrderStage stage) { }

    public record AdvanceResponse(OrderStage stage, Instant etaDelivery, Instant installAt, boolean slaBreached) { }

    public record OrderSummaryResponse(UUID id, OrderStage stage, String sku, String productName,
                                       Instant slaDueAt, boolean slaBreached, Instant createdAt,
                                       UUID recommendationId) { }

    public record SlaResponse(Instant dueAt, boolean breached, Instant deliveredAt, Instant installedAt) { }

    @Schema(description = "Polilinha da entrega em GeoJSON `LineString` — cada par vem na ordem [lng, lat].")
    public record RouteResponse(
            @Schema(example = "LineString") String type,
            @Schema(example = "[[-46.64, -23.55], [-46.6462, -23.5527]]") List<List<Double>> coordinates) { }

    @Schema(description = """
            Entrega despachada do nó logístico mais próximo. `route` e `durationS` são opcionais e
            simulados (ver GeoService): vêm nulos quando a casa não tem coordenadas, e nesse caso o
            cliente cai no estado vazio do mapa sem quebrar.""")
    public record DeliveryResponse(String nodeName, Instant eta, Integer distanceM, String status,
                                   Integer durationS, RouteResponse route) { }

    @Schema(description = "Pedido da cadeia de segurança, com SLA e dados da entrega roteada ao nó mais próximo.")
    public record OrderDetailResponse(UUID orderId, OrderStage stage, String sku, String productName,
                                      SlaResponse sla, DeliveryResponse delivery, Instant createdAt) { }
}
