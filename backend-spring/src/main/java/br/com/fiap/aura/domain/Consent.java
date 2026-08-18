package br.com.fiap.aura.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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

/** Aceite da política LGPD (RN-001) — gate obrigatório antes de qualquer dado de saúde. */
@Entity
@Table(name = "consents")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Consent {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(nullable = false)
    private String version;

    @Column(name = "accepted_at", nullable = false)
    @Builder.Default
    private Instant acceptedAt = Instant.now();
}
