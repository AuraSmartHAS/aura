package br.com.fiap.aura.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import br.com.fiap.aura.domain.Signal;
import br.com.fiap.aura.domain.enums.RiskLevel;
import br.com.fiap.aura.domain.enums.SignalSource;
import br.com.fiap.aura.domain.enums.SignalType;
import br.com.fiap.aura.web.error.ApiException;
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

    private Signal signal(SignalType type, String event) {
        return Signal.builder().type(type).source(SignalSource.VOICE).value(Map.of("event", event)).build();
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
        assertThat(result.explanation()).contains("NBR 9050", "ALTO");
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
}
