package br.com.fiap.aura.domain.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

/** Máquina de estados do pedido: approved → sourcing → in_route → delivered → installed → returned. */
public enum OrderStage {
    APPROVED("approved"),
    SOURCING("sourcing"),
    IN_ROUTE("in_route"),
    DELIVERED("delivered"),
    INSTALLED("installed"),
    RETURNED("returned");

    private final String wire;

    OrderStage(String wire) {
        this.wire = wire;
    }

    @JsonValue
    public String value() {
        return wire;
    }

    @JsonCreator
    public static OrderStage from(String raw) {
        for (OrderStage s : values()) {
            if (s.wire.equalsIgnoreCase(raw)) {
                return s;
            }
        }
        throw new IllegalArgumentException("Estágio desconhecido: " + raw);
    }

    /** Próximo estágio na cadeia, ou vazio quando terminal (returned). */
    public OrderStage next() {
        return switch (this) {
            case APPROVED -> SOURCING;
            case SOURCING -> IN_ROUTE;
            case IN_ROUTE -> DELIVERED;
            case DELIVERED -> INSTALLED;
            case INSTALLED -> RETURNED;
            case RETURNED -> null;
        };
    }
}
