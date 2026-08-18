package br.com.fiap.aura.domain.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

/** Origem do sinal — só software e wearable leve, nunca sensor instalado na casa. */
public enum SignalSource {
    VOICE, SELF_REPORT, USAGE, WEARABLE;

    @JsonValue
    public String value() {
        return name().toLowerCase();
    }

    @JsonCreator
    public static SignalSource from(String raw) {
        return SignalSource.valueOf(raw.trim().toUpperCase());
    }
}
