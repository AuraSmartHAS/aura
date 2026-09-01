package br.com.fiap.aura.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.PositiveOrZero;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class MedicationDtos {

    private MedicationDtos() { }

    /** Só aceita hora válida de 24h: mata o texto livre ("8h e 20h") que o app usava. */
    private static final String HHMM = "^([01]\\d|2[0-3]):[0-5]\\d$";
    private static final String HHMM_MSG = "Horário deve estar no formato HH:mm (ex.: 08:00)";

    public record CreateMedicationRequest(
            @NotBlank String name,
            @Schema(example = "50mg, 1 comprimido") String dosage,
            @Schema(example = "[\"08:00\", \"20:00\"]")
            List<@Pattern(regexp = HHMM, message = HHMM_MSG) String> schedule,
            @Schema(example = "tomar com alimento") String notes,
            @Schema(defaultValue = "true") Boolean active,
            @Schema(example = "60", description = "Estoque domiciliar em doses; nulo = sem controle de estoque")
            @PositiveOrZero(message = "Estoque não pode ser negativo") Integer stockDoses) { }

    /** Atualização parcial: campo ausente (null) fica como está. */
    public record UpdateMedicationRequest(
            String name,
            String dosage,
            @Schema(example = "[\"08:00\", \"20:00\"]")
            List<@Pattern(regexp = HHMM, message = HHMM_MSG) String> schedule,
            String notes,
            Boolean active,
            @PositiveOrZero(message = "Estoque não pode ser negativo") Integer stockDoses) { }

    public record MedicationResponse(UUID id, UUID homeId, String name, String dosage,
                                     List<String> schedule, String notes, boolean active,
                                     Integer stockDoses, Instant createdAt) { }

    public record ConfirmMedicationRequest(
            @Schema(description = "Se a dose foi tomada; ausente equivale a true", defaultValue = "true")
            Boolean taken) { }

    /** {@code stockDoses} devolve o estoque já decrementado, para a tela mostrar o efeito da voz. */
    public record ConfirmMedicationResponse(UUID signalId, boolean taken, Integer stockDoses) { }
}
