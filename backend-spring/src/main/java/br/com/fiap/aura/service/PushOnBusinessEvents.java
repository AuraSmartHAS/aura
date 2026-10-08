package br.com.fiap.aura.service;

import br.com.fiap.aura.domain.enums.PushKind;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Pedido que muda de estágio e recomendação nova viram push para o dono da casa.
 *
 * <p><b>AFTER_COMMIT</b>: o aviso só sai do que foi gravado de verdade. <b>Falha aqui vira log,
 * nunca erro</b> para quem agiu: o pedido já avançou, e um token revogado ou o FCM fora do ar
 * não podem desfazer a ação de negócio (mesma regra do SOS: segue em frente).
 *
 * <p><b>Sem spam:</b> a reposição já não materializa recomendação com pedido a caminho ou
 * adiamento em vigor; aqui fica o segundo freio — no máximo um aviso por item da casa a cada
 * {@link #RECOMMENDATION_PERIOD}, mesmo que a recomendação seja rejeitada e nasça de novo.
 */
@Component
public class PushOnBusinessEvents {

    private static final Logger log = LoggerFactory.getLogger(PushOnBusinessEvents.class);

    static final Duration RECOMMENDATION_PERIOD = Duration.ofHours(12);

    private final NotificationService notifications;
    private final Clock clock;
    private final Map<String, Instant> lastRecommendationPush = new ConcurrentHashMap<>();

    @Autowired
    public PushOnBusinessEvents(NotificationService notifications) {
        this(notifications, Clock.systemUTC());
    }

    PushOnBusinessEvents(NotificationService notifications, Clock clock) {
        this.notifications = notifications;
        this.clock = clock;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW, readOnly = true)
    public void onOrderStageChanged(PushEvents.OrderStageChanged event) {
        try {
            notifications.notifyOrderStage(event);
        } catch (RuntimeException e) {
            log.warn("Aviso do pedido {} (estágio {}) não saiu: {}",
                    event.orderId(), event.stage().value(), e.getMessage());
        }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW, readOnly = true)
    public void onRecommendationCreated(PushEvents.RecommendationCreated event) {
        String key = event.homeId() + "|" + event.itemKey();
        Instant now = clock.instant();
        Instant last = lastRecommendationPush.get(key);
        if (last != null && Duration.between(last, now).compareTo(RECOMMENDATION_PERIOD) < 0) {
            log.info("Aviso de recomendação da casa {} segurado: o mesmo item já avisou há menos de {} h",
                    event.homeId(), RECOMMENDATION_PERIOD.toHours());
            return;
        }
        try {
            if (notifications.notifyRecommendation(event)) {
                lastRecommendationPush.put(key, now);
            }
        } catch (RuntimeException e) {
            log.warn("Aviso de {} da casa {} não saiu: {}",
                    PushKind.RECOMMENDATION.value(), event.homeId(), e.getMessage());
        }
    }
}
