package br.com.fiap.aura.web.dto;

import br.com.fiap.aura.domain.enums.SignalSource;
import br.com.fiap.aura.domain.enums.SignalType;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

public final class SignalDtos {

    private SignalDtos() { }

    public record CreateSignalRequest(
            @NotNull UUID homeId,
            @NotNull SignalType type,
            @NotNull SignalSource source,
            @Schema(example = "{\"event\": \"near_fall\", \"place\": \"bathroom\"}")
            Map<String, Object> value) { }

    public record SignalCreatedResponse(UUID signalId) { }

    public record SignalResponse(UUID id, SignalType type, SignalSource source,
                                 Map<String, Object> value, Instant capturedAt) { }
}
