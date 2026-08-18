package br.com.fiap.aura.web;

import br.com.fiap.aura.domain.enums.SignalType;
import br.com.fiap.aura.security.CurrentUser;
import br.com.fiap.aura.service.ScoreService;
import br.com.fiap.aura.service.SignalService;
import br.com.fiap.aura.web.dto.ScoreDtos;
import br.com.fiap.aura.web.dto.SignalDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@Tag(name = "3. Monitoramento 360", description = "Sinais observados e escore explicável")
public class MonitoringController {

    private final SignalService signals;
    private final ScoreService scores;
    private final CurrentUser currentUser;

    public MonitoringController(SignalService signals, ScoreService scores, CurrentUser currentUser) {
        this.signals = signals;
        this.scores = scores;
        this.currentUser = currentUser;
    }

    @PostMapping("/signals")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Registra um sinal (voz, auto-relato, uso do app ou wearable)")
    public SignalDtos.SignalCreatedResponse create(@Valid @RequestBody SignalDtos.CreateSignalRequest req) {
        return signals.create(currentUser.require(), req);
    }

    @GetMapping("/homes/{homeId}/signals")
    @Operation(summary = "Histórico de sinais da casa, com filtros e paginação")
    public List<SignalDtos.SignalResponse> list(@PathVariable UUID homeId,
                                                @RequestParam(required = false) SignalType type,
                                                @RequestParam(required = false) Instant from,
                                                @RequestParam(required = false) Instant to,
                                                @RequestParam(defaultValue = "100") int limit,
                                                @RequestParam(defaultValue = "0") int offset) {
        return signals.list(currentUser.require(), homeId, type, from, to, limit, offset);
    }

    @PostMapping("/scores/recompute")
    @Operation(summary = "Recalcula o escore; sem dimensão, devolve a de maior risco")
    public ScoreDtos.ScoreResponse recompute(@Valid @RequestBody ScoreDtos.RecomputeRequest req) {
        return scores.recompute(currentUser.require(), req.homeId(), req.dimension());
    }

    @GetMapping("/homes/{homeId}/scores")
    @Operation(summary = "Histórico de escores da casa")
    public List<ScoreDtos.ScoreResponse> history(@PathVariable UUID homeId) {
        return scores.history(currentUser.require(), homeId);
    }

    @GetMapping("/homes/{homeId}/scores/latest")
    @Operation(summary = "Último escore de cada dimensão — é o que o painel 360 mostra")
    public List<ScoreDtos.ScoreResponse> latest(@PathVariable UUID homeId) {
        return scores.latestByDimension(currentUser.require(), homeId);
    }
}
