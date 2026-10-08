package br.com.fiap.aura.service;

import br.com.fiap.aura.domain.enums.OrderStage;
import java.util.UUID;

/**
 * Fatos de negócio que viram aviso no celular de quem cuida. São publicados dentro da transação
 * e só viram push depois do commit ({@link PushOnBusinessEvents}): aviso de pedido que deu
 * rollback é aviso de algo que não aconteceu.
 *
 * <p>{@code actorUserId} é quem causou o fato. Quem acabou de agir já sabe o que fez: o aviso
 * vai para o dono da casa só quando foi outra pessoa (a operação, a voz da paciente).
 */
public final class PushEvents {

    private PushEvents() { }

    public record OrderStageChanged(UUID homeId, UUID orderId, OrderStage stage, UUID actorUserId) { }

    /**
     * {@code itemKey} identifica o item recomendado (SKU ou medicação): é a chave do limite de
     * um aviso por item e período.
     */
    public record RecommendationCreated(UUID homeId, UUID recommendationId, String itemKey,
                                        UUID actorUserId) { }
}
