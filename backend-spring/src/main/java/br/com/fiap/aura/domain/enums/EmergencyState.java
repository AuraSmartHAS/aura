package br.com.fiap.aura.domain.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

/**
 * Estados de um pedido de socorro (C3). A transição que importa é a primeira:
 * {@link #WAITING_CANCEL} → {@link #NOTIFIED} acontece <b>no servidor</b>, por relógio do servidor,
 * sem participação do aparelho (regra 2). O aparelho só pode chegar antes disso com o cancelamento.
 *
 * <pre>
 *   WAITING_CANCEL ─(T+5s, servidor)→ DISPATCHED ─(60s sem confirmar)→ ESCALATED
 *         │                              │                                │
 *         └─(cancelar)→ CANCELLED        └─────────(confirmar)───────────→ ACKNOWLEDGED
 *
 *   THROTTLED: registrado e auditável, mas o aviso foi contido pela mitigação de abuso.
 * </pre>
 *
 * <p><b>O nome {@code DISPATCHED} é escolhido a dedo, e não "notified".</b> O servidor sabe que
 * entregou o aviso ao transporte; ele <b>não</b> sabe que um humano viu. Um estado chamado
 * "notified" convidaria a tela a dizer "avisei a Ana" — que é exatamente a mentira que a regra 4
 * proíbe. Quem viu tem estado próprio: {@link #ACKNOWLEDGED}. E se o aviso saiu de verdade se lê
 * em {@code transportReal} e {@code notifiedCount}, nunca no nome do estado.
 *
 * <p><b>Persistido como texto</b> ({@code EmergencyStateConverter}), nunca com
 * {@code @Enumerated(STRING)} — a razão é a mesma documentada em {@link HomeMemberRole}: o perfil
 * {@code postgres} roda com {@code ddl-auto: update}, que <b>não</b> altera <i>check constraint</i>
 * existente. Um estado novo (um "sem resposta de ninguém", um "encerrado pela cuidadora") quebraria
 * em produção passando 100% verde no H2, que recria o schema a cada boot.
 */
public enum EmergencyState {

    /** Registrado; o servidor dispara em T+5s salvo cancelamento. É o único estado cancelável. */
    WAITING_CANCEL("waiting_cancel"),

    /** A janela fechou e o servidor entregou o aviso ao transporte, para o contato principal. */
    DISPATCHED("dispatched"),

    /** Ninguém confirmou em 60s: o aviso foi também para os demais membros da casa. */
    ESCALATED("escalated"),

    /** Alguém disse "estou indo". É o que fecha o loop e para o escalonamento. */
    ACKNOWLEDGED("acknowledged"),

    /** "Foi engano": cancelado dentro da janela, antes de o aviso sair. */
    CANCELLED("cancelled"),

    /** Contido pela mitigação de abuso do acesso sem login — o registro existe, o push não saiu. */
    THROTTLED("throttled");

    private final String wire;

    EmergencyState(String wire) {
        this.wire = wire;
    }

    @JsonValue
    public String value() {
        return wire;
    }

    @JsonCreator
    public static EmergencyState from(String raw) {
        for (EmergencyState s : values()) {
            if (s.wire.equalsIgnoreCase(raw) || s.name().equalsIgnoreCase(raw)) {
                return s;
            }
        }
        throw new IllegalArgumentException("Estado de emergência desconhecido: " + raw);
    }

    /** Emergência viva: ainda pode receber cancelamento, escalonamento ou confirmação. */
    public boolean aberta() {
        return this == WAITING_CANCEL || this == DISPATCHED || this == ESCALATED;
    }
}
