package br.com.fiap.aura.service;

import br.com.fiap.aura.domain.DeliveryOrder;
import br.com.fiap.aura.domain.Recommendation;
import br.com.fiap.aura.domain.enums.OrderStage;
import br.com.fiap.aura.repository.DeliveryOrderRepository;
import br.com.fiap.aura.repository.RecommendationRepository;
import br.com.fiap.aura.web.dto.CareChainDtos;
import java.time.Instant;
import java.util.EnumSet;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * Quando um item já está "pedido": a regra única que impede o motor de recomendar, e a aprovação
 * de criar, um segundo pedido para o que já está a caminho.
 *
 * <p>O critério muda com o tipo do item, porque muda o momento em que o motivo da recomendação
 * deixa de existir:
 * <ul>
 *   <li><b>Reposição de remédio</b>: até a <b>entrega</b>. É nela que o estoque sobe
 *       ({@code CareChainService.refillIfReplenishment}); depois dela a régua se resolve sozinha.</li>
 *   <li><b>Item durável</b> (barra, piso, luz): até a <b>instalação</b>. Entregue e não instalado,
 *       o risco que gerou a recomendação continua de pé.</li>
 * </ul>
 */
@Service
public class InFlightOrderService {

    private static final Set<OrderStage> CONSUMABLE_OPEN =
            EnumSet.of(OrderStage.APPROVED, OrderStage.SOURCING, OrderStage.IN_ROUTE);

    private static final Set<OrderStage> DURABLE_OPEN =
            EnumSet.of(OrderStage.APPROVED, OrderStage.SOURCING, OrderStage.IN_ROUTE, OrderStage.DELIVERED);

    private final DeliveryOrderRepository orders;
    private final RecommendationRepository recommendations;

    public InFlightOrderService(DeliveryOrderRepository orders, RecommendationRepository recommendations) {
        this.orders = orders;
        this.recommendations = recommendations;
    }

    /** Pedido em andamento de um item durável da casa, identificado pelo SKU. */
    public Optional<DeliveryOrder> ofDurableItem(UUID homeId, String sku) {
        return orders.findFirstByHomeIdAndSkuAndStageInOrderByCreatedAtDesc(homeId, sku, DURABLE_OPEN);
    }

    /** Pedido de reposição em andamento de uma medicação, qualquer que seja a recomendação de origem. */
    public Optional<DeliveryOrder> ofMedication(UUID homeId, UUID medicationId) {
        List<UUID> recommendationIds = recommendations.findByHomeIdAndMedicationId(homeId, medicationId)
                .stream().map(Recommendation::getId).toList();
        if (recommendationIds.isEmpty()) {
            return Optional.empty();
        }
        return orders.findFirstByRecommendationIdInAndStageInOrderByCreatedAtDesc(recommendationIds, CONSUMABLE_OPEN);
    }

    /**
     * Instante da entrega de reposição mais recente desta medicação, se houver. É quando o estoque
     * da casa mudou pela cadeia — e o que encerra um "deixar para depois" antes do prazo.
     */
    public Optional<Instant> lastDeliveryOfMedication(UUID homeId, UUID medicationId) {
        Set<UUID> recommendationIds = recommendations.findByHomeIdAndMedicationId(homeId, medicationId)
                .stream().map(Recommendation::getId).collect(Collectors.toSet());
        if (recommendationIds.isEmpty()) {
            return Optional.empty();
        }
        return orders.findByHomeIdOrderByCreatedAtDesc(homeId).stream()
                .filter(o -> recommendationIds.contains(o.getRecommendationId()))
                .map(DeliveryOrder::getDeliveredAt)
                .filter(Objects::nonNull)
                .max(Instant::compareTo);
    }

    /** O pedido em andamento que já cobre esta recomendação (reposição ou durável), se houver. */
    public Optional<DeliveryOrder> covering(Recommendation rec) {
        return rec.getMedicationId() != null
                ? ofMedication(rec.getHomeId(), rec.getMedicationId())
                : ofDurableItem(rec.getHomeId(), rec.getSku());
    }

    /** Este pedido ainda está "em andamento" para a recomendação que o originou? */
    public boolean isOpen(Recommendation rec, DeliveryOrder order) {
        return (rec.getMedicationId() != null ? CONSUMABLE_OPEN : DURABLE_OPEN).contains(order.getStage());
    }

    public static CareChainDtos.OrderInProgress toDto(DeliveryOrder order) {
        return new CareChainDtos.OrderInProgress(order.getId(), order.getStage());
    }

    /**
     * Pendentes do mesmo item que ficaram obsoletas porque o item já foi pedido. {@code superseded}
     * não é recusa da cuidadora: é "já coberta por um pedido", e some das listagens.
     */
    public void supersedePending(Recommendation covered, UUID exceptId) {
        List<Recommendation> pending = covered.getMedicationId() != null
                ? recommendations.findByHomeIdAndMedicationIdAndStatus(
                        covered.getHomeId(), covered.getMedicationId(), "recommended")
                : recommendations.findByHomeIdAndSkuAndStatus(covered.getHomeId(), covered.getSku(), "recommended");
        pending.stream()
                .filter(r -> !r.getId().equals(exceptId))
                .forEach(r -> r.setStatus("superseded"));
    }
}
