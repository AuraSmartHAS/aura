package br.com.fiap.aura.domain;

import br.com.fiap.aura.domain.converter.EmergencyChannelConverter;
import br.com.fiap.aura.domain.converter.EmergencyStateConverter;
import br.com.fiap.aura.domain.enums.EmergencyChannel;
import br.com.fiap.aura.domain.enums.EmergencyState;
import jakarta.persistence.Column;
import jakarta.persistence.Convert;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * Um pedido de socorro (C3). É o registro que existe <b>antes</b> de qualquer aviso sair: o toque
 * grava a linha e responde na hora, e é o servidor que dispara em {@link #dispatchDueAt}.
 *
 * <p><b>Por que a linha nasce antes do aviso</b> (regra 2): cronômetro no aparelho morre quando o
 * telefone cai da mão, a tela apaga ou o app vai a segundo plano — exatamente o que acontece com
 * quem caiu. Com a linha gravada, perder o aparelho no meio da janela não perde o socorro: o
 * disparo já está agendado do lado de cá.
 *
 * <p><b>Cada carimbo de tempo aqui é uma pergunta que alguém vai fazer às 2h da manhã:</b> o aviso
 * saiu? ({@link #dispatchedAt}) saiu de verdade ou era transporte simulado?
 * ({@link #transportReal}) chegou em quantos aparelhos? ({@link #notifiedCount}) alguém confirmou?
 * ({@link #acknowledgedAt}) quem? ({@link #acknowledgedByUserId}). Nada disso é derivável do estado
 * sozinho, então nada disso é calculado — é gravado.
 */
@Entity
@Table(name = "emergencies")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Emergency {

    @Id
    @GeneratedValue
    private UUID id;

    @Column(name = "home_id", nullable = false)
    private UUID homeId;

    /**
     * Quem disparou, <b>quando se sabe</b>. Nulo é um valor legítimo e esperado: o SOS não fica
     * atrás de login (regra 3), então a sessão pode não existir no momento do pedido de socorro.
     * Nulo aqui significa "veio do aparelho pareado com esta casa, sem sessão", não "erro".
     */
    @Column(name = "triggered_by_user_id")
    private UUID triggeredByUserId;

    @Convert(converter = EmergencyChannelConverter.class)
    @Column(nullable = false, length = 20)
    private EmergencyChannel channel;

    @Convert(converter = EmergencyStateConverter.class)
    @Column(name = "state", nullable = false, length = 30)
    private EmergencyState state;

    @Column(name = "created_at", nullable = false)
    @Builder.Default
    private Instant createdAt = Instant.now();

    /** Instante em que o servidor dispara o aviso. Passado dele sem cancelar = o aviso sai. */
    @Column(name = "dispatch_due_at", nullable = false)
    private Instant dispatchDueAt;

    @Column(name = "dispatched_at")
    private Instant dispatchedAt;

    /** Prazo da confirmação humana; vencido sem "estou indo", o aviso vai aos demais membros. */
    @Column(name = "escalate_due_at")
    private Instant escalateDueAt;

    @Column(name = "escalated_at")
    private Instant escalatedAt;

    @Column(name = "cancelled_at")
    private Instant cancelledAt;

    @Column(name = "acknowledged_at")
    private Instant acknowledgedAt;

    @Column(name = "acknowledged_by_user_id")
    private UUID acknowledgedByUserId;

    /** Última mudança de estado — é o que a auditoria lê quando a ordem dos fatos é a dúvida. */
    @Column(name = "state_changed_at", nullable = false)
    @Builder.Default
    private Instant stateChangedAt = Instant.now();

    /**
     * Se havia transporte real de push no instante do disparo (regra 1). {@code false} significa
     * que <b>nada saiu deste servidor</b> — e o cliente tinha de estar oferecendo ligação em vez de
     * prometer "avisei a Ana".
     */
    @Column(name = "transport_real", nullable = false)
    @Builder.Default
    private boolean transportReal = false;

    /** Aparelhos que receberam o aviso principal. Zero é possível: casa sem aparelho registrado. */
    @Column(name = "notified_count", nullable = false)
    @Builder.Default
    private int notifiedCount = 0;

    /** Aparelhos alcançados pelo escalonamento. */
    @Column(name = "escalated_count", nullable = false)
    @Builder.Default
    private int escalatedCount = 0;

    /** Se o segundo aviso ("foi engano, a Maria cancelou") saiu. */
    @Column(name = "retraction_sent", nullable = false)
    @Builder.Default
    private boolean retractionSent = false;

    /**
     * Localização da casa no instante do pedido, copiada de {@link Home}. Cópia, e não leitura da
     * casa na hora de exibir: o registro tem de dizer para onde o aviso apontou, mesmo que a casa
     * seja editada ou apagada depois.
     */
    @Column(name = "lat")
    private Double lat;

    @Column(name = "lng")
    private Double lng;
}
