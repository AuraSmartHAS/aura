package br.com.fiap.aura.domain.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

/** Papéis do RBAC (contrato /api/v1: valores em português, como no app). */
public enum Role {
    PACIENTE, CUIDADORA, PROFISSIONAL, ADMIN;

    @JsonValue
    public String value() {
        return name().toLowerCase();
    }

    @JsonCreator
    public static Role from(String raw) {
        return raw == null ? CUIDADORA : Role.valueOf(raw.trim().toUpperCase());
    }

    public String authority() {
        return "ROLE_" + name();
    }
}
