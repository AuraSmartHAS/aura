package br.com.fiap.aura.domain.enums;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonValue;

/**
 * Assunto do aviso enviado ao celular de quem cuida. Nenhum deles nomeia condição clínica.
 *
 * <p><b>Sobre a regra 5 do C3 ("não criar valor novo no enum de sinal"), e por que ela não se
 * aplica aqui:</b> a armadilha da regra 5 é a <i>check constraint</i> que o Hibernate gera para
 * coluna anotada com {@code @Enumerated} — e {@code ddl-auto: update} não altera constraint
 * existente, então um valor novo passa verde no H2 e quebra no Postgres. {@code PushKind} não é
 * coluna de nenhuma entidade: ele só existe em DTO de requisição e na escolha do texto do aviso
 * (procure por usos — nenhuma classe de {@code domain} o declara como campo). Sem coluna, não há
 * constraint, e não há o que quebrar.
 *
 * <p>O enum <b>persistido</b> que o SOS trouxe é {@link EmergencyState}, e esse sim foi mapeado com
 * {@code AttributeConverter} para texto puro, no mesmo padrão do C0. O sinal de emergência, por sua
 * vez, reusa {@link SignalType#MOBILITY} com {@code value = {"event":"sos"}} — nenhum valor novo em
 * {@code SignalType}, como a regra 5 exige.
 */
public enum PushKind {

    RECOMMENDATION,
    ORDER,

    /** Pedido de socorro (C3). Sempre com prioridade alta e com a localização da casa em {@code data}. */
    SOS,

    /** "Foi engano, a Maria cancelou" — o segundo aviso da regra 2. */
    SOS_CANCELLED,

    /** Ninguém confirmou em 60s: o mesmo pedido, agora para os demais membros da casa. */
    SOS_ESCALATED;

    @JsonValue
    public String value() {
        return name().toLowerCase();
    }

    @JsonCreator
    public static PushKind from(String raw) {
        return PushKind.valueOf(raw.trim().toUpperCase());
    }

    /** Se este assunto é do fluxo de crise: define prioridade alta e canal de som próprio no app. */
    public boolean crise() {
        return this == SOS || this == SOS_CANCELLED || this == SOS_ESCALATED;
    }
}
