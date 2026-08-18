package br.com.fiap.aura.web.dto;

import br.com.fiap.aura.domain.enums.RiskLevel;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import java.util.List;
import java.util.UUID;

public final class ScoreDtos {

    private ScoreDtos() { }

    public record RecomputeRequest(
            @NotNull UUID homeId,
            @Schema(example = "mobility", description = "Omitido = recalcula todas e devolve a de maior risco")
            String dimension) { }

    /** {@code factors} e {@code weights} são listas paralelas — é o que torna o escore explicável. */
    public record ScoreResponse(UUID scoreId, String dimension, RiskLevel level, double score,
                                List<String> factors, List<Double> weights,
                                String explanation, String configVersion) { }
}
