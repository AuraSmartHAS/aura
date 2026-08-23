package br.com.fiap.aura.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import java.time.LocalDate;
import java.util.Map;
import java.util.UUID;

public final class HomeDtos {

    private HomeDtos() { }

    public record CreateHomeRequest(
            @NotBlank String patientName,
            LocalDate birthDate,
            @Pattern(regexp = "\\d{8}", message = "CEP deve ter 8 dígitos, só números")
            @Schema(example = "01310100") String cep,
            String label) { }

    public record HomeCreatedResponse(UUID homeId, String address, Double lat, Double lng) { }

    public record HomeResponse(UUID id, String label, String patientName, LocalDate birthDate,
                               String cep, String address, Double lat, Double lng,
                               Map<String, Object> safetyChecklist) { }

    public record ChecklistRequest(
            @NotNull @Schema(example = "{\"grab_bar_bathroom\": false, \"anti_slip_floor\": true}")
            Map<String, Object> items) { }

    public record ChecklistResponse(Map<String, Object> safetyChecklist) { }
}
