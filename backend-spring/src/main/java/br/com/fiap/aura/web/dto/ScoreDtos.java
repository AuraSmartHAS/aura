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
    @Schema(description = """
            Escore explicável de uma dimensão. `factors`, `weights` e `factorLabels` são listas PARALELAS:
            o peso e o rótulo na posição i correspondem ao fator na posição i, e a soma dos pesos acionados
            é o `score`. `explanation` é a mesma informação em linguagem natural, pronta para a tela.
            Faixas: < 0,4 low · < 0,7 medium · >= 0,7 high.""")
    public record ScoreResponse(
            UUID scoreId,
            @Schema(example = "mobility") String dimension,
            @Schema(example = "high") RiskLevel level,
            @Schema(example = "0.9", description = "Soma dos pesos dos fatores acionados, limitada a 1")
            double score,
            @Schema(example = "[\"near_fall_reported\", \"no_grab_bar\", \"anti_slip_floor\"]")
            List<String> factors,
            @Schema(example = "[0.4, 0.3, 0.2]") List<Double> weights,
            @Schema(example = "[\"quase-queda relatada\", \"ausência de barra de apoio\", "
                    + "\"ausência de piso anti-derrapante\"]",
                    description = "Os mesmos fatores em português, na mesma ordem — a tela não traduz código")
            List<String> factorLabels,
            @Schema(example = "Norma NBR 9050 → risco ALTO. Fatores: quase-queda relatada, "
                    + "ausência de barra de apoio.")
            String explanation,
            @Schema(example = "2026-06-14", description = "Versão do arquivo de pesos que produziu este escore")
            String configVersion) { }
}
