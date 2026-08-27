package br.com.fiap.aura.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import br.com.fiap.aura.config.AuraProperties;
import br.com.fiap.aura.domain.Signal;
import br.com.fiap.aura.domain.enums.RiskLevel;
import br.com.fiap.aura.domain.enums.SignalSource;
import br.com.fiap.aura.domain.enums.SignalType;
import br.com.fiap.aura.web.error.ApiException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("dev")
class ScoringServiceTest {

    @Autowired
    private ScoringService scoring;

    @Autowired
    private GuardrailService guardrails;

    @Autowired
    private AuraProperties props;

    private Signal signal(SignalType type, String event) {
        return Signal.builder().type(type).source(SignalSource.VOICE).value(Map.of("event", event)).build();
    }

    private AuraProperties.Factor factor(String name, String label) {
        return new AuraProperties.Factor(name, label, 0.5, AuraProperties.FactorKind.CHECKLIST_ABSENT,
                null, null, "chave_qualquer");
    }

    private AuraProperties.Dimension dimension(AuraProperties.Factor... factors) {
        return new AuraProperties.Dimension("NBR 9050", "fall_bathroom", List.of(factors));
    }

    @Test
    @DisplayName("quase-queda + sem barra + sem piso anti-derrapante = risco alto e explicação com os três fatores")
    void highRisk() {
        var result = scoring.compute("mobility",
                List.of(signal(SignalType.MOBILITY, "near_fall")),
                Map.of("grab_bar_bathroom", false, "anti_slip_floor", false));

        assertThat(result.score()).isEqualTo(0.9);           // 0.4 + 0.3 + 0.2
        assertThat(result.level()).isEqualTo(RiskLevel.HIGH);
        assertThat(result.factors())
                .containsExactly("near_fall_reported", "no_grab_bar", "anti_slip_floor");
        assertThat(result.weights()).containsExactly(0.4, 0.3, 0.2);
        // a explicação ganhou os fatores em português sem perder a norma nem o nível
        assertThat(result.explanation()).contains("NBR 9050", "ALTO",
                "quase-queda relatada", "ausência de barra de apoio");
        assertThat(result.riskTag()).isEqualTo("fall_bathroom");
    }

    @Test
    @DisplayName("casa protegida e sem eventos: risco baixo, sem fatores acionados")
    void lowRisk() {
        var result = scoring.compute("mobility", List.of(),
                Map.of("grab_bar_bathroom", true, "anti_slip_floor", true));

        assertThat(result.score()).isZero();
        assertThat(result.level()).isEqualTo(RiskLevel.LOW);
        assertThat(result.factors()).isEmpty();
    }

    @Test
    @DisplayName("só a falta da barra de apoio já coloca a casa em risco médio")
    void mediumRisk() {
        var result = scoring.compute("mobility", List.of(), Map.of("anti_slip_floor", true));

        assertThat(result.score()).isEqualTo(0.3);
        assertThat(result.level()).isEqualTo(RiskLevel.LOW);

        var withNightTrip = scoring.compute("sleep",
                List.of(signal(SignalType.SLEEP, "night_trip")), Map.of("night_light", true));
        assertThat(withNightTrip.score()).isEqualTo(0.6);
        assertThat(withNightTrip.level()).isEqualTo(RiskLevel.MEDIUM);
    }

    @Test
    @DisplayName("dimensão inexistente vira 400 UNKNOWN_DIMENSION")
    void unknownDimension() {
        assertThatThrownBy(() -> scoring.compute("telepatia", List.of(), Map.of()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("Dimensão desconhecida");
    }

    @Test
    @DisplayName("guardrail bloqueia qualquer texto prescritivo saindo da API")
    void guardrailBlocksPrescription() {
        assertThatThrownBy(() -> guardrails.assertNonPrescriptive("Tome 50mg de losartana à noite"))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("não prescreve");

        assertThat(guardrails.assertNonPrescriptive("Barra de apoio reduz risco de queda (NBR 9050)."))
                .isNotNull();
    }

    @Test
    @DisplayName("fator sem 'label' no YAML reprova o build, não a tela")
    void factorWithoutLabelFailsTheBuild() {
        Map<String, AuraProperties.Dimension> semRotulo =
                Map.of("mobility", dimension(factor("fator_novo", null)));

        assertThatThrownBy(() -> ScoringService.labelIndex(semRotulo, guardrails))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContainingAll("fator_novo", "label");

        assertThatThrownBy(() -> ScoringService.labelIndex(
                Map.of("mobility", dimension(factor("fator_vazio", "   "))), guardrails))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    @DisplayName("nomes de fator são únicos entre dimensões — é o que sustenta o mapa global de rótulos")
    void factorNamesAreUniqueAcrossDimensions() {
        // a recomendação guarda só o scoreId: se um nome sumisse do mapa, a tela traduziria errado
        int total = props.scoring().dimensions().values().stream().mapToInt(d -> d.factors().size()).sum();
        assertThat(scoring.factorLabels()).hasSize(total);

        Map<String, AuraProperties.Dimension> colisao = new LinkedHashMap<>();
        colisao.put("mobility", dimension(factor("no_grab_bar", "ausência de barra de apoio")));
        colisao.put("sleep", dimension(factor("no_grab_bar", "outra coisa qualquer")));

        assertThatThrownBy(() -> ScoringService.labelIndex(colisao, guardrails))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContainingAll("no_grab_bar", "repetido entre dimensões");
    }

    @Test
    @DisplayName("todo rótulo do YAML passa no guardrail — a frase da recomendação é composta com eles")
    void everyLabelPassesTheGuardrail() {
        assertThat(scoring.factorLabels()).isNotEmpty();
        scoring.factorLabels().forEach((name, label) ->
                assertThat(guardrails.assertNonPrescriptive(label)).as(name).isEqualTo(label));

        // rótulo prescritivo derruba o boot, em vez de virar 422 no POST /recommendations em produção
        assertThatThrownBy(() -> ScoringService.labelIndex(
                Map.of("mobility", dimension(factor("dose_extra", "tomar o remédio antes do banho"))), guardrails))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("guardrail");
    }
}
