package br.com.fiap.aura.domain.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

/** Dimensões observadas do monitoramento 360 (nenhuma delas vem de sensor IoT). */
public enum SignalType {
    MOBILITY, SLEEP, COGNITION, MOOD, ENVIRONMENT, ADHERENCE, VITALS;

    @JsonValue
    public String value() {
        return name().toLowerCase();
    }

    @JsonCreator
    public static SignalType from(String raw) {
        return SignalType.valueOf(raw.trim().toUpperCase());
    }
}
