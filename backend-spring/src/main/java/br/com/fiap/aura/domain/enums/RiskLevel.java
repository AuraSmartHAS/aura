package br.com.fiap.aura.domain.enums;

import com.fasterxml.jackson.annotation.JsonValue;

public enum RiskLevel {
    LOW, MEDIUM, HIGH;

    @JsonValue
    public String value() {
        return name().toLowerCase();
    }
}
