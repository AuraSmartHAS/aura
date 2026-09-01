package br.com.fiap.aura.service;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** A régua da última milha — função pura, relógio por parâmetro, sem mock de Instant.now(). */
class CareChainServiceTest {

    private static final int WINDOW = 20;

    private final Instant eta = Instant.parse("2026-09-01T17:30:00Z");

    @Test
    @DisplayName("antes da partida o progresso é zero")
    void beforeDeparture() {
        Instant createdAt = eta.minus(WINDOW, ChronoUnit.MINUTES);
        assertThat(CareChainService.routeProgress(createdAt, eta, createdAt.minusSeconds(60), WINDOW))
                .isZero();
    }

    @Test
    @DisplayName("pedido antigo: a partida é eta − janela, e no meio dela o progresso é 0,5")
    void midwayAnchorsOnWindow() {
        Instant createdAt = eta.minus(2, ChronoUnit.HOURS);
        Instant now = eta.minus(WINDOW / 2, ChronoUnit.MINUTES);
        assertThat(CareChainService.routeProgress(createdAt, eta, now, WINDOW)).isEqualTo(0.5);
    }

    @Test
    @DisplayName("depois da ETA o progresso trava no teto — o ponto fica \"chegando\", nunca pousa sozinho")
    void cappedAfterEta() {
        Instant createdAt = eta.minus(3, ChronoUnit.HOURS);
        assertThat(CareChainService.routeProgress(createdAt, eta, eta.plusSeconds(300), WINDOW))
                .isEqualTo(CareChainService.MAX_ROUTE_PROGRESS);
    }

    @Test
    @DisplayName("pedido despachado ao vivo: a partida é o próprio advance, não eta − janela")
    void liveOrderAnchorsOnCreation() {
        Instant createdAt = eta.minus(10, ChronoUnit.MINUTES);
        Instant now = createdAt.plus(5, ChronoUnit.MINUTES);
        assertThat(CareChainService.routeProgress(createdAt, eta, now, WINDOW)).isEqualTo(0.5);
    }
}
