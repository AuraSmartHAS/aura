package br.com.fiap.aura.service;

import br.com.fiap.aura.domain.Medication;
import br.com.fiap.aura.domain.Signal;
import br.com.fiap.aura.domain.enums.SignalSource;
import br.com.fiap.aura.domain.enums.SignalType;
import br.com.fiap.aura.repository.MedicationRepository;
import br.com.fiap.aura.repository.SignalRepository;
import br.com.fiap.aura.security.AuthPrincipal;
import br.com.fiap.aura.web.dto.MedicationDtos;
import br.com.fiap.aura.web.error.ApiException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Medicação da casa. Medicamento é dado de saúde: entra pelo gate LGPD (RN-001) e
 * só é visível a quem cuida daquela casa (RN-017). A API nunca prescreve (RN-023) —
 * a confirmação de dose só registra um sinal de adesão.
 */
@Service
public class MedicationService {

    private final MedicationRepository medications;
    private final SignalRepository signals;
    private final HomeService homeService;
    private final AuthService auth;

    public MedicationService(MedicationRepository medications, SignalRepository signals,
                             HomeService homeService, AuthService auth) {
        this.medications = medications;
        this.signals = signals;
        this.homeService = homeService;
        this.auth = auth;
    }

    @Transactional
    public MedicationDtos.MedicationResponse create(AuthPrincipal principal, UUID homeId,
                                                    MedicationDtos.CreateMedicationRequest req) {
        // consentimento antes de resolver a casa: sem aceite, nem existência de casa se revela
        auth.requireConsent(principal);
        homeService.requireAccess(principal, homeId);

        Medication med = medications.save(Medication.builder()
                .homeId(homeId)
                .name(req.name().trim())
                .dosage(req.dosage())
                .schedule(req.schedule() == null ? new ArrayList<>() : new ArrayList<>(req.schedule()))
                .notes(req.notes())
                .active(req.active() == null || req.active())
                .build());
        return toResponse(med);
    }

    @Transactional(readOnly = true)
    public List<MedicationDtos.MedicationResponse> list(AuthPrincipal principal, UUID homeId,
                                                        int limit, int offset) {
        homeService.requireAccess(principal, homeId);
        int size = Math.clamp(limit, 1, 500);
        return medications.findByHomeIdOrderByCreatedAtDesc(homeId, PageRequest.of(offset / size, size))
                .stream()
                .map(MedicationService::toResponse)
                .toList();
    }

    @Transactional
    public MedicationDtos.MedicationResponse update(AuthPrincipal principal, UUID medId,
                                                     MedicationDtos.UpdateMedicationRequest req) {
        Medication med = requireAccess(principal, medId);
        if (req.name() != null) {
            if (req.name().isBlank()) {
                throw ApiException.badRequest("VALIDATION_ERROR", "O nome do medicamento não pode ficar vazio.");
            }
            med.setName(req.name().trim());
        }
        if (req.dosage() != null) {
            med.setDosage(req.dosage());
        }
        if (req.schedule() != null) {
            med.setSchedule(new ArrayList<>(req.schedule()));
        }
        if (req.notes() != null) {
            med.setNotes(req.notes());
        }
        if (req.active() != null) {
            med.setActive(req.active());
        }
        return toResponse(med);
    }

    @Transactional
    public void delete(AuthPrincipal principal, UUID medId) {
        medications.delete(requireAccess(principal, medId));
    }

    /** Confirma (ou nega) a dose: nada é prescrito, só se registra o sinal de adesão. */
    @Transactional
    public MedicationDtos.ConfirmMedicationResponse confirm(AuthPrincipal principal, UUID medId, Boolean taken) {
        auth.requireConsent(principal);
        Medication med = requireAccess(principal, medId);

        boolean tomou = taken == null || taken;
        Map<String, Object> value = new LinkedHashMap<>();
        value.put("medicationId", med.getId().toString());
        value.put("taken", tomou);

        Signal signal = signals.save(Signal.builder()
                .homeId(med.getHomeId())
                .type(SignalType.ADHERENCE)
                .source(SignalSource.SELF_REPORT)
                .value(value)
                .build());
        return new MedicationDtos.ConfirmMedicationResponse(signal.getId(), tomou);
    }

    /** Resolve medicação → casa e aplica o mesmo isolamento por paciente das outras rotas. */
    private Medication requireAccess(AuthPrincipal principal, UUID medId) {
        Medication med = medications.findById(medId)
                .orElseThrow(() -> ApiException.notFound("Medicação"));
        homeService.requireAccess(principal, med.getHomeId());
        return med;
    }

    static MedicationDtos.MedicationResponse toResponse(Medication m) {
        return new MedicationDtos.MedicationResponse(m.getId(), m.getHomeId(), m.getName(), m.getDosage(),
                m.getSchedule(), m.getNotes(), m.isActive(), m.getCreatedAt());
    }
}
