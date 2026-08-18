package br.com.fiap.aura.domain;

import br.com.fiap.aura.domain.converter.JsonMapConverter;
import br.com.fiap.aura.domain.enums.SignalSource;
import br.com.fiap.aura.domain.enums.SignalType;
import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** Sinal observado (voz, auto-relato, uso do app ou wearable). Nunca vem de sensor IoT. */
@Entity
@Table(name = "signals")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Signal {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(name = "home_id", nullable = false)
    private UUID homeId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private SignalType type;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private SignalSource source;

    @Convert(converter = JsonMapConverter.class)
    @Column(name = "signal_value", length = 2000)
    @Builder.Default
    private Map<String, Object> value = new LinkedHashMap<>();

    @Column(name = "captured_at", nullable = false)
    @Builder.Default
    private Instant capturedAt = Instant.now();
}
