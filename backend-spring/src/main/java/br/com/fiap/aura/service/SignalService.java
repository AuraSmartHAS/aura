package br.com.fiap.aura.service;

import br.com.fiap.aura.domain.Signal;
import br.com.fiap.aura.domain.enums.Role;
import br.com.fiap.aura.domain.enums.SignalSource;
import br.com.fiap.aura.web.error.ApiException;
import br.com.fiap.aura.domain.enums.SignalType;
import br.com.fiap.aura.intelligence.LeituraRegistrada;
import br.com.fiap.aura.repository.SignalRepository;
import br.com.fiap.aura.security.AuthPrincipal;
import br.com.fiap.aura.web.dto.SignalDtos;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SignalService {

    private final SignalRepository signals;
    private final HomeService homeService;
    private final AuthService auth;
    private final ApplicationEventPublisher events;

    public SignalService(SignalRepository signals, HomeService homeService, AuthService auth,
                         ApplicationEventPublisher events) {
        this.signals = signals;
        this.homeService = homeService;
        this.auth = auth;
        this.events = events;
    }

    @Transactional
    public SignalDtos.SignalCreatedResponse create(AuthPrincipal principal, SignalDtos.CreateSignalRequest req) {
        auth.requireConsent(principal);
        homeService.requireAccess(principal, req.homeId());

        Signal signal = signals.save(Signal.builder()
                .homeId(req.homeId())
                .type(req.type())
                .source(req.source())
                .value(req.value() == null ? new LinkedHashMap<>() : new LinkedHashMap<>(req.value()))
                .build());
        // os avisos do banco rodam depois do commit (AlertasAoRegistrarLeitura), não aqui dentro
        events.publishEvent(new LeituraRegistrada(signal.getHomeId()));
        return new SignalDtos.SignalCreatedResponse(signal.getId());
    }

    /**
     * A origem {@code voice} é lida pela família como "a Maria falou" — é a procedência exibida como
     * prova. Hoje só a rota de confirmação de dose aplica a regra: {@code POST /signals} segue aceitando
     * {@code voice} de qualquer membro da casa porque o contrato histórico e os fluxos de demonstração
     * dependem disso (decisão de produto pendente — ver o relatório da revisão), e a regra só vale para
     * o que é novo.
     */
    public static void requirePatientForVoice(SignalSource source, Role role) {
        if (source == SignalSource.VOICE && role != Role.PACIENTE) {
            throw ApiException.badRequest("INVALID_SOURCE", "A origem voz só vale para a conta da paciente.");
        }
    }

    @Transactional(readOnly = true)
    public List<SignalDtos.SignalResponse> list(AuthPrincipal principal, UUID homeId, SignalType type,
                                                Instant from, Instant to, int limit, int offset) {
        homeService.requireAccess(principal, homeId);
        int page = limit <= 0 ? 0 : offset / limit;
        return signals.search(homeId, type, from, to, PageRequest.of(page, Math.clamp(limit, 1, 500)))
                .stream()
                .map(s -> new SignalDtos.SignalResponse(s.getId(), s.getType(), s.getSource(),
                        s.getValue(), s.getCapturedAt()))
                .toList();
    }
}
