package br.com.fiap.aura.service;

import br.com.fiap.aura.config.AuraProperties;
import br.com.fiap.aura.domain.Signal;
import br.com.fiap.aura.domain.enums.RiskLevel;
import br.com.fiap.aura.web.error.ApiException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * Motor do escore explicável. Soma os pesos dos fatores acionados e devolve,
 * junto do número, a lista de fatores e a frase que explica o resultado —
 * requisito de produto: nenhuma decisão de risco pode ser caixa-preta.
 */
@Service
public class ScoringService {

    private final AuraProperties props;
    private final GuardrailService guardrails;
    private final Map<String, String> factorLabels;

    public ScoringService(AuraProperties props, GuardrailService guardrails) {
        this.props = props;
        this.guardrails = guardrails;
        this.factorLabels = labelIndex(props.scoring().dimensions(), guardrails);
    }

    public record Result(String dimension, double score, RiskLevel level, List<String> factors,
                         List<Double> weights, String explanation, String configVersion,
                         String riskTag, String norm) { }

    public List<String> dimensions() {
        return new ArrayList<>(props.scoring().dimensions().keySet());
    }

    public Result compute(String dimension, List<Signal> signals, Map<String, Object> checklist) {
        AuraProperties.Dimension cfg = props.scoring().dimensions().get(dimension);
        if (cfg == null) {
            throw ApiException.badRequest("UNKNOWN_DIMENSION", "Dimensão desconhecida: " + dimension);
        }

        List<String> firedNames = new ArrayList<>();
        List<Double> firedWeights = new ArrayList<>();
        double total = 0;

        for (AuraProperties.Factor factor : cfg.factors()) {
            if (fired(factor, signals, checklist)) {
                firedNames.add(factor.name());
                firedWeights.add(factor.weight());
                total += factor.weight();
            }
        }

        double score = Math.min(1.0, Math.round(total * 1000d) / 1000d);
        RiskLevel level = level(score);
        // A norma e o nível abrem a frase e não saem dela: é o contrato que a tela e o teste leem.
        String explanation = "Norma %s → risco %s.".formatted(cfg.norm(), levelWord(level));
        if (!firedNames.isEmpty()) {
            explanation += " Fatores: %s.".formatted(String.join(", ", labelsOf(firedNames)));
        }

        guardrails.assertNonPrescriptive(explanation);
        return new Result(dimension, score, level, firedNames, firedWeights, explanation,
                props.scoring().configVersion(), cfg.riskTag(), cfg.norm());
    }

    private boolean fired(AuraProperties.Factor factor, List<Signal> signals, Map<String, Object> checklist) {
        return switch (factor.kind()) {
            case SIGNAL_EVENT -> signals.stream()
                    .filter(s -> s.getType() == factor.signalType())
                    .anyMatch(s -> Objects.equals(String.valueOf(s.getValue().get("event")), factor.event()));
            case CHECKLIST_PRESENT -> truthy(checklist.get(factor.checklistKey()));
            case CHECKLIST_ABSENT -> !truthy(checklist.get(factor.checklistKey()));
        };
    }

    private boolean truthy(Object value) {
        return value instanceof Boolean b ? b : Boolean.parseBoolean(String.valueOf(value));
    }

    private RiskLevel level(double score) {
        if (score >= props.scoring().levels().high()) {
            return RiskLevel.HIGH;
        }
        return score >= props.scoring().levels().medium() ? RiskLevel.MEDIUM : RiskLevel.LOW;
    }

    private String levelWord(RiskLevel level) {
        return switch (level) {
            case HIGH -> "ALTO";
            case MEDIUM -> "MÉDIO";
            case LOW -> "BAIXO";
        };
    }

    public String riskTagOf(String dimension) {
        AuraProperties.Dimension cfg = props.scoring().dimensions().get(dimension);
        return cfg == null ? "fall_bathroom" : cfg.riskTag();
    }

    public Map<String, String> riskTagsByDimension() {
        return props.scoring().dimensions().entrySet().stream()
                .collect(Collectors.toMap(Map.Entry::getKey, e -> e.getValue().riskTag()));
    }

    /** Rótulos na MESMA ordem dos nomes; nome sem rótulo cai no próprio nome, para não sumir da tela. */
    public List<String> labelsOf(List<String> factorNames) {
        return factorNames == null ? List.of()
                : factorNames.stream().map(name -> factorLabels.getOrDefault(name, name)).toList();
    }

    public Map<String, String> factorLabels() {
        return factorLabels;
    }

    /**
     * Rótulo em português de cada fator, indexado pelo nome. O mapa é GLOBAL porque a
     * recomendação guarda só o {@code scoreId}, nunca a dimensão — então só funciona
     * enquanto os nomes forem únicos entre dimensões. Por isso as três falhas abaixo
     * derrubam o boot, e não a tela:
     * fator sem {@code label}; nome repetido (traduziria errado em silêncio);
     * rótulo prescritivo (a frase da recomendação é composta com ele, e um "tomar" no
     * YAML viraria 422 no {@code POST /recommendations} na cara da cuidadora).
     */
    static Map<String, String> labelIndex(Map<String, AuraProperties.Dimension> dimensions,
                                          GuardrailService guardrails) {
        Map<String, String> index = new LinkedHashMap<>();
        dimensions.forEach((dimension, cfg) -> {
            for (AuraProperties.Factor factor : cfg.factors()) {
                if (factor.label() == null || factor.label().isBlank()) {
                    throw new IllegalStateException("Fator '%s' (dimensão %s) está sem 'label' em scoring-weights.yml."
                            .formatted(factor.name(), dimension));
                }
                try {
                    guardrails.assertNonPrescriptive(factor.label());
                } catch (ApiException e) {
                    throw new IllegalStateException(
                            "Rótulo do fator '%s' não passa no guardrail de não-prescrição: \"%s\"."
                                    .formatted(factor.name(), factor.label()), e);
                }
                if (index.put(factor.name(), factor.label()) != null) {
                    throw new IllegalStateException(
                            "Fator '%s' repetido entre dimensões: o rótulo é global e traduziria errado."
                                    .formatted(factor.name()));
                }
            }
        });
        return Collections.unmodifiableMap(index);
    }
}
