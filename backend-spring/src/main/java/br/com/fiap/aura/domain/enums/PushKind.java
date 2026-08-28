package br.com.fiap.aura.domain.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

/** Assunto do aviso enviado ao celular de quem cuida. Nenhum deles nomeia condição clínica. */
public enum PushKind {
    RECOMMENDATION, ORDER;

    @JsonValue
    public String value() {
        return name().toLowerCase();
    }

    @JsonCreator
    public static PushKind from(String raw) {
        return PushKind.valueOf(raw.trim().toUpperCase());
    }
}
