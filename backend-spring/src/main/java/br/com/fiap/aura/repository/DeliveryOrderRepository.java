package br.com.fiap.aura.repository;

import br.com.fiap.aura.domain.DeliveryOrder;
import br.com.fiap.aura.domain.enums.OrderStage;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DeliveryOrderRepository extends JpaRepository<DeliveryOrder, UUID> {

    List<DeliveryOrder> findByHomeIdOrderByCreatedAtDesc(UUID homeId);

    long countByStageNot(OrderStage stage);

    long countBySlaBreached(boolean slaBreached);

    List<DeliveryOrder> findTop20ByOrderByCreatedAtDesc();

    void deleteByHomeId(UUID homeId);
}
