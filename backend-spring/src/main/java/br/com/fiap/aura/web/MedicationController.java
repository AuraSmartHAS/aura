package br.com.fiap.aura.web;

import br.com.fiap.aura.security.CurrentUser;
import br.com.fiap.aura.service.MedicationService;
import br.com.fiap.aura.web.dto.CatalogDtos;
import br.com.fiap.aura.web.dto.MedicationDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(value = "/api/v1", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "3.1 Medicação", description = "Medicamentos da casa e confirmação de dose — sinal de adesão, nunca prescrição")
public class MedicationController {

    private final MedicationService medications;
    private final CurrentUser currentUser;

    public MedicationController(MedicationService medications, CurrentUser currentUser) {
        this.medications = medications;
        this.currentUser = currentUser;
    }

    @PostMapping("/homes/{homeId}/medications")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Cadastra um medicamento da casa (horários em \"HH:mm\")")
    public MedicationDtos.MedicationResponse create(@PathVariable UUID homeId,
                                                    @Valid @RequestBody MedicationDtos.CreateMedicationRequest req) {
        return medications.create(currentUser.require(), homeId, req);
    }

    @GetMapping("/homes/{homeId}/medications")
    @Operation(summary = "Medicamentos da casa, do mais recente para o mais antigo")
    public List<MedicationDtos.MedicationResponse> list(@PathVariable UUID homeId,
                                                        @RequestParam(defaultValue = "100") int limit,
                                                        @RequestParam(defaultValue = "0") int offset) {
        return medications.list(currentUser.require(), homeId, limit, offset);
    }

    @PutMapping("/medications/{medId}")
    @Operation(summary = "Atualiza o medicamento — só os campos enviados mudam")
    public MedicationDtos.MedicationResponse update(@PathVariable UUID medId,
                                                    @Valid @RequestBody MedicationDtos.UpdateMedicationRequest req) {
        return medications.update(currentUser.require(), medId, req);
    }

    @DeleteMapping("/medications/{medId}")
    @Operation(summary = "Remove o medicamento da casa")
    public CatalogDtos.DeletedResponse delete(@PathVariable UUID medId) {
        medications.delete(currentUser.require(), medId);
        return new CatalogDtos.DeletedResponse(true);
    }

    @PostMapping("/medications/{medId}/confirm")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Confirma a dose tomada — registra um sinal de adesão (corpo opcional)")
    public MedicationDtos.ConfirmMedicationResponse confirm(
            @PathVariable UUID medId,
            @Valid @RequestBody(required = false) MedicationDtos.ConfirmMedicationRequest req) {
        return medications.confirm(currentUser.require(), medId, req == null ? null : req.taken());
    }
}
