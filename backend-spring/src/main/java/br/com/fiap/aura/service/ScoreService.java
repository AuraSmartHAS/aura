package br.com.fiap.aura.service;

import br.com.fiap.aura.config.AuraProperties;
import br.com.fiap.aura.domain.Home;
import br.com.fiap.aura.domain.Score;
import br.com.fiap.aura.domain.Signal;
import br.com.fiap.aura.repository.ScoreRepository;
import br.com.fiap.aura.repository.SignalRepository;
import br.com.fiap.aura.security.AuthPrincipal;
import br.com.fiap.aura.web.dto.ScoreDtos;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ScoreService {

    private final ScoreRepository scores;
    private final SignalRepository signals;
    private final ScoringService engine;
    private final HomeService homeService;
    private final AuthService auth;
    private final AuraProperties props;

    public ScoreService(ScoreRepository scores, SignalRepository signals, ScoringService engine,
                        HomeService homeService, AuthService auth, AuraProperties props) {
        this.scores = scores;
        this.signals = signals;
        this.engine = engine;
        this.homeService = homeService;
        this.auth = auth;
        this.props = props;
    }

    /** Sem dimensão: recalcula todas e devolve a de maior risco (é o que a cuidadora precisa ver). */
    @Transactional
    public ScoreDtos.ScoreResponse recompute(AuthPrincipal principal, UUID homeId, String dimension) {
        auth.requireConsent(principal);
        Home home = homeService.requireAccess(principal, homeId);

        Instant cutoff = Instant.now().minus(props.scoring().windowDays(), ChronoUnit.DAYS);
        List<Signal> window = signals.findByHomeIdAndCapturedAtGreaterThanEqual(homeId, cutoff);
        List<String> dims = dimension == null || dimension.isBlank() ? engine.dimensions() : List.of(dimension);

        Score best = null;
        for (String dim : dims) {
            ScoringService.Result result = engine.compute(dim, window, home.getSafetyChecklist());
            Score saved = scores.save(Score.builder()
                    .homeId(homeId)
                    .dimension(result.dimension())
                    .factors(result.factors())
                    .weights(result.weights())
                    .score(result.score())
                    .level(result.level())
                    .explanation(result.explanation())
                    .configVersion(result.configVersion())
                    .build());
            if (best == null || saved.getScore() > best.getScore()) {
                best = saved;
            }
        }
        return toResponse(best);
    }

    @Transactional(readOnly = true)
    public List<ScoreDtos.ScoreResponse> history(AuthPrincipal principal, UUID homeId) {
        homeService.requireAccess(principal, homeId);
        return scores.findByHomeIdOrderByExplainedAtDesc(homeId).stream().map(this::toResponse).toList();
    }

    /** Último escore de cada dimensão — o que o painel 360 mostra. */
    @Transactional(readOnly = true)
    public List<ScoreDtos.ScoreResponse> latestByDimension(AuthPrincipal principal, UUID homeId) {
        homeService.requireAccess(principal, homeId);
        return scores.findByHomeIdOrderByExplainedAtDesc(homeId).stream()
                .collect(java.util.stream.Collectors.toMap(Score::getDimension, s -> s, (first, older) -> first,
                        java.util.LinkedHashMap::new))
                .values().stream()
                .sorted(Comparator.comparingDouble(Score::getScore).reversed())
                .map(this::toResponse)
                .toList();
    }

    private ScoreDtos.ScoreResponse toResponse(Score s) {
        return new ScoreDtos.ScoreResponse(s.getId(), s.getDimension(), s.getLevel(), s.getScore(),
                s.getFactors(), s.getWeights(), engine.labelsOf(s.getFactors()),
                s.getExplanation(), s.getConfigVersion());
    }
}
