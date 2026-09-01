package br.com.fiap.aura.domain;

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
 * Medicamento cadastrado pela cuidadora. Aqui medicamento é só SINAL de adesão:
 * a API nunca prescreve, ajusta dose nem diagnostica (RN-023) — a confirmação de
 * uso vira um {@link Signal} do tipo ADHERENCE e alimenta o escore.
 */
@Entity
@Table(name = "medications")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Medication {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(name = "home_id", nullable = false)
    private UUID homeId;

    @Column(nullable = false)
    private String name;

    private String dosage;

    /** Horários no formato "HH:mm" (ex.: ["08:00","20:00"]) — lista estruturada, nunca texto livre. */
    @Convert(converter = StringListConverter.class)
    @Column(length = 500)
    @Builder.Default
    private List<String> schedule = new ArrayList<>();

    @Column(length = 500)
    private String notes;

    /**
     * Estoque domiciliar em doses; nulo = a casa não controla estoque deste item e nada dispara.
     * Desce a cada dose confirmada por voz e sobe quando a reposição da cadeia é entregue —
     * é o número que liga a adesão à logística.
     */
    @Column(name = "stock_doses")
    private Integer stockDoses;

    @Column(nullable = false)
    @Builder.Default
    private boolean active = true;

    @Column(name = "created_at", nullable = false)
    @Builder.Default
    private Instant createdAt = Instant.now();
}
