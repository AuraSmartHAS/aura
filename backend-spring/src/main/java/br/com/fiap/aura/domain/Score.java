package br.com.fiap.aura.domain;

import br.com.fiap.aura.domain.converter.DoubleListConverter;
import br.com.fiap.aura.domain.converter.StringListConverter;
import br.com.fiap.aura.domain.enums.RiskLevel;
import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
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
 * Escore explicável. {@code factors} e {@code weights} são listas paralelas —
 * é o que permite mostrar na tela por que o risco subiu (nunca caixa-preta).
 */
@Entity
@Table(name = "scores")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Score {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(name = "home_id", nullable = false)
    private UUID homeId;

    @Column(nullable = false)
    private String dimension;

    @Convert(converter = StringListConverter.class)
    @Column(length = 1000)
    @Builder.Default
    private List<String> factors = new ArrayList<>();

    @Convert(converter = DoubleListConverter.class)
    @Column(length = 500)
    @Builder.Default
    private List<Double> weights = new ArrayList<>();

    @Column(name = "score_value", nullable = false)
    private double score;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private RiskLevel level;

    @Column(length = 1000)
    private String explanation;

    @Column(name = "config_version")
    private String configVersion;

    @Column(name = "explained_at", nullable = false)
    @Builder.Default
    private Instant explainedAt = Instant.now();
}
