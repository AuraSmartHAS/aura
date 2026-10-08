package br.com.fiap.aura.repository;

import br.com.fiap.aura.domain.DeliveryOrder;
import br.com.fiap.aura.domain.enums.OrderStage;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DeliveryOrderRepository extends JpaRepository<DeliveryOrder, UUID> {

    List<DeliveryOrder> findByHomeIdOrderByCreatedAtDesc(UUID homeId);

    long countByStageNot(OrderStage stage);

    long countBySlaBreached(boolean slaBreached);

    List<DeliveryOrder> findTop20ByOrderByCreatedAtDesc();

    void deleteByHomeId(UUID homeId);

    boolean existsBySku(String sku);

    /** Pedido mais recente do item, entre os estágios dados. Base da regra de "em andamento". */
    Optional<DeliveryOrder> findFirstByHomeIdAndSkuAndStageInOrderByCreatedAtDesc(
            UUID homeId, String sku, Collection<OrderStage> stages);

    /** Idem, por recomendação: a reposição é identificada pela medicação, não pelo SKU. */
    Optional<DeliveryOrder> findFirstByRecommendationIdInAndStageInOrderByCreatedAtDesc(
            Collection<UUID> recommendationIds, Collection<OrderStage> stages);
}
