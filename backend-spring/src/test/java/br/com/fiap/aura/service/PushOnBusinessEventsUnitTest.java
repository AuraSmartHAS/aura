package br.com.fiap.aura.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import br.com.fiap.aura.domain.enums.OrderStage;
import br.com.fiap.aura.web.error.ApiException;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** O freio de spam e a regra de "falha vira log", sem Spring e sem relógio de parede. */
class PushOnBusinessEventsUnitTest {

    /** Relógio que o teste empurra: o período por item é medido nele, não no tempo real. */
    private static final class RelogioManual extends Clock {
        private Instant agora = Instant.parse("2026-10-07T12:00:00Z");

        @Override
        public ZoneOffset getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(java.time.ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return agora;
        }
    }

    private final NotificationService notifications = mock(NotificationService.class);
    private final RelogioManual relogio = new RelogioManual();
    private final PushOnBusinessEvents listener = new PushOnBusinessEvents(notifications, relogio);

    @Test
    @DisplayName("no máximo um aviso por item e período, mesmo que a recomendação renasça")
    void umAvisoPorItemEPeriodo() {
        when(notifications.notifyRecommendation(any())).thenReturn(true);
        UUID casa = UUID.randomUUID();

        listener.onRecommendationCreated(new PushEvents.RecommendationCreated(casa, UUID.randomUUID(), "sku-1", null));
        listener.onRecommendationCreated(new PushEvents.RecommendationCreated(casa, UUID.randomUUID(), "sku-1", null));
        verify(notifications, times(1)).notifyRecommendation(any());

        // outro item da mesma casa não é segurado pelo primeiro
        listener.onRecommendationCreated(new PushEvents.RecommendationCreated(casa, UUID.randomUUID(), "sku-2", null));
        verify(notifications, times(2)).notifyRecommendation(any());

        // passado o período, o mesmo item volta a poder avisar
        relogio.agora = relogio.agora.plus(PushOnBusinessEvents.RECOMMENDATION_PERIOD);
        listener.onRecommendationCreated(new PushEvents.RecommendationCreated(casa, UUID.randomUUID(), "sku-1", null));
        verify(notifications, times(3)).notifyRecommendation(any());
    }

    @Test
    @DisplayName("aviso que não saiu (sem aparelho) não consome o período do item")
    void avisoSemDestinoNaoConsomeOPeriodo() {
        when(notifications.notifyRecommendation(any())).thenReturn(false, true);
        UUID casa = UUID.randomUUID();

        listener.onRecommendationCreated(new PushEvents.RecommendationCreated(casa, UUID.randomUUID(), "sku-1", null));
        listener.onRecommendationCreated(new PushEvents.RecommendationCreated(casa, UUID.randomUUID(), "sku-1", null));
        verify(notifications, times(2)).notifyRecommendation(any());
    }

    @Test
    @DisplayName("FCM recusando vira log: o listener não propaga a falha para quem agiu")
    void falhaNaoPropaga() {
        when(notifications.notifyOrderStage(any())).thenThrow(ApiException.unprocessable("PUSH_FAILED", "x"));

        listener.onOrderStageChanged(new PushEvents.OrderStageChanged(
                UUID.randomUUID(), UUID.randomUUID(), OrderStage.IN_ROUTE, null));

        verify(notifications).notifyOrderStage(any());
    }

    @Test
    @DisplayName("o texto do pedido fala do estágio e da casa, nunca do item")
    void corpoDoPedido() {
        assertThat(NotificationService.orderBody(OrderStage.IN_ROUTE, "Maria S."))
                .isEqualTo("O pedido da casa da Maria saiu para entrega. Toque para acompanhar.");
        assertThat(NotificationService.orderBody(OrderStage.DELIVERED, null))
                .isEqualTo("O pedido da casa foi entregue. Toque para ver.");
    }
}
