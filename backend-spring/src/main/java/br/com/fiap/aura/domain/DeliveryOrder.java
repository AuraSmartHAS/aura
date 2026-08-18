package br.com.fiap.aura.domain;

import br.com.fiap.aura.domain.enums.OrderStage;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Pedido da cadeia de segurança: da aprovação à instalação, com SLA por estágio. */
@Entity
@Table(name = "orders")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DeliveryOrder {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(name = "home_id", nullable = false)
    private UUID homeId;

    @Column(name = "recommendation_id", nullable = false)
    private UUID recommendationId;

    @Column(nullable = false)
    private String sku;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    @Builder.Default
    private OrderStage stage = OrderStage.APPROVED;

    /** Nó logístico mais próximo (ship-from-store). */
    @Column(name = "node_name")
    private String nodeName;

    @Column(name = "distance_m")
    private Integer distanceM;

    @Column(name = "sla_due_at")
    private Instant slaDueAt;

    @Column(name = "sla_breached", nullable = false)
    @Builder.Default
    private boolean slaBreached = false;

    @Column(name = "eta_delivery")
    private Instant etaDelivery;

    @Column(name = "delivered_at")
    private Instant deliveredAt;

    @Column(name = "install_at")
    private Instant installAt;

    @Column(name = "installed_at")
    private Instant installedAt;

    @Column(name = "created_at", nullable = false)
    @Builder.Default
    private Instant createdAt = Instant.now();
}
