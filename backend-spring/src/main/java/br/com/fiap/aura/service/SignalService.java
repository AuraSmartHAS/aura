package br.com.fiap.aura.service;

import br.com.fiap.aura.domain.Signal;
import br.com.fiap.aura.domain.enums.SignalType;
import br.com.fiap.aura.repository.SignalRepository;
import br.com.fiap.aura.security.AuthPrincipal;
import br.com.fiap.aura.web.dto.SignalDtos;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SignalService {

    private final SignalRepository signals;
    private final HomeService homeService;
    private final AuthService auth;

    public SignalService(SignalRepository signals, HomeService homeService, AuthService auth) {
        this.signals = signals;
        this.homeService = homeService;
        this.auth = auth;
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
        return new SignalDtos.SignalCreatedResponse(signal.getId());
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
