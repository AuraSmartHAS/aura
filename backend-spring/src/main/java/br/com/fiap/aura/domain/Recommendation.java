package br.com.fiap.aura.domain;

import br.com.fiap.aura.domain.converter.DoubleListConverter;
import br.com.fiap.aura.domain.converter.StringListConverter;
import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Recomendação explicada. Status: recommended → approved | rejected.
 * RN-022: só uma recomendação aprovada vira pedido.
 */
@Entity
@Table(name = "recommendations")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Recommendation {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(name = "home_id", nullable = false)
    private UUID homeId;

    @Column(name = "score_id")
    private UUID scoreId;

    @Column(nullable = false)
    private String sku;

    @Column(nullable = false, length = 500)
    private String reason;

    @Column(nullable = false)
    @Builder.Default
    private String status = "recommended";

    @Convert(converter = StringListConverter.class)
    @Column(length = 1000)
    @Builder.Default
    private List<String> factors = new ArrayList<>();

    @Convert(converter = DoubleListConverter.class)
    @Column(length = 500)
    @Builder.Default
    private List<Double> weights = new ArrayList<>();

    @Column(name = "created_at", nullable = false)
    @Builder.Default
    private Instant createdAt = Instant.now();
}
