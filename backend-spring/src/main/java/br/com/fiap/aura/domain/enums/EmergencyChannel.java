package br.com.fiap.aura.domain.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

/**
 * Como o socorro foi pedido. Existe para a validação do cenário de queda distinguir o botão da voz
 * — os dois caminhos são exigidos pelo C3 e falham por motivos diferentes (alvo de 64dp x
 * endpointing que corta a fala de quem tem Parkinson).
 *
 * <p>Persistido como texto, nunca com {@code @Enumerated} — ver {@link EmergencyState}.
 */
public enum EmergencyChannel {

    /** Botão SOS da tela. */
    TOUCH("touch"),

    /** Tool {@code emergencia} do agente de voz. */
    VOICE("voice");

    private final String wire;

    EmergencyChannel(String wire) {
        this.wire = wire;
    }

    @JsonValue
    public String value() {
        return wire;
    }

    @JsonCreator
    public static EmergencyChannel from(String raw) {
        for (EmergencyChannel c : values()) {
            if (c.wire.equalsIgnoreCase(raw) || c.name().equalsIgnoreCase(raw)) {
                return c;
            }
        }
        throw new IllegalArgumentException("Canal de emergência desconhecido: " + raw);
    }
}
