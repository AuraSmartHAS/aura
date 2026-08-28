package br.com.fiap.aura.web.dto;

import br.com.fiap.aura.domain.enums.PushKind;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import java.util.UUID;

public final class NotificationDtos {

    private NotificationDtos() { }

    public record TestPushRequest(
            @NotNull UUID homeId,
            @Schema(description = "Assunto do aviso; ausente vale como \"recommendation\"",
                    example = "recommendation")
            PushKind kind) { }

    /**
     * {@code latencyMs} é o tempo do envio medido no servidor — é o número que sustenta o SLA
     * "evento → aviso em ≤10s". {@code simulated} diz se o push saiu de verdade: sem credencial
     * do Firebase ele vem {@code true}, e o chamador tem de degradar em vez de prometer entrega.
     */
    public record TestPushResponse(
            @Schema(example = "projects/aura/messages/0:1724800000000000%3Ade3f")
            String messageId,
            @Schema(example = "184") long latencyMs,
            @Schema(example = "false") boolean simulated) { }
}
