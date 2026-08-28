package br.com.fiap.aura.web.dto;

import br.com.fiap.aura.domain.enums.EmergencyChannel;
import br.com.fiap.aura.domain.enums.EmergencyState;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import java.time.Instant;
import java.util.UUID;

/**
 * Contrato do SOS (C3). Todo campo aqui existe para a tela poder <b>não mentir</b>.
 *
 * <p>A regra que ordena o desenho: sempre que o servidor não pode prometer que o aviso saiu — push
 * simulado, nenhum aparelho registrado, ou disparo contido pela mitigação de abuso — a resposta diz
 * isso em {@code canPromiseAlert=false} com o motivo em {@code degradedReason}, e a tela troca o
 * botão por uma ligação telefônica. São três causas diferentes com o <b>mesmo</b> comportamento de
 * cliente, de propósito: a tela só precisa perguntar "posso prometer?", não enumerar falhas.
 */
public final class EmergencyDtos {

    private EmergencyDtos() { }

    /**
     * O pedido de socorro. {@code homeId} é o identificador que o aparelho já guarda — é o que
     * permite o SOS <b>sem sessão</b> (regra 3). Note o que <b>não</b> existe aqui: nenhum destino.
     * O aviso vai só para quem já está vinculado a esta casa, e é essa ausência que impede o
     * endpoint aberto de virar um encaminhador de notificação para telefone arbitrário.
     */
    public record TriggerRequest(
            @NotNull
            @Schema(description = "Casa que pede socorro; vem do pareamento do aparelho",
                    example = "a8e1f3bb-f32a-4eed-aa96-80d29095acc0")
            UUID homeId,

            @Schema(description = "Como o socorro foi pedido; ausente vale como \"touch\"",
                    example = "touch")
            EmergencyChannel channel) { }

    /**
     * Resposta <b>imediata</b> do registro: volta antes de qualquer push, porque quem caiu não pode
     * esperar uma chamada de rede ao Firebase para saber que foi ouvido.
     *
     * <p>{@code dispatchAt} é o instante em que <b>o servidor</b> dispara. A tela mostra a contagem
     * a partir dele, mas não é ela quem conta: se o aparelho morrer nesse intervalo, o disparo
     * acontece do mesmo jeito.
     */
    public record TriggerResponse(
            UUID emergencyId,
            UUID homeId,
            @Schema(example = "waiting_cancel") EmergencyState state,
            Instant createdAt,

            @Schema(description = "Quando o servidor dispara o aviso, salvo cancelamento")
            Instant dispatchAt,
            @Schema(example = "5") int cancelWindowSeconds,
            @Schema(example = "60") int escalateAfterSeconds,

            @Schema(description = "Se existe transporte real de push neste servidor (regra 1)",
                    example = "false")
            boolean transportReal,
            @Schema(description = "Espelho de transportReal para o mesmo contrato do C2: "
                            + "true = nada vai sair deste servidor",
                    example = "true")
            boolean simulated,
            @Schema(description = "Aparelhos registrados que podem receber o aviso nesta casa",
                    example = "1")
            int recipientCount,
            @Schema(description = "Primeiro nome do contato principal, para a fala do assistente",
                    example = "Ana")
            String primaryContactName,

            @Schema(description = "Disparo contido pela mitigação de abuso do acesso sem login",
                    example = "false")
            boolean throttled,
            @Schema(description = "Toque repetido: devolveu a emergência que já estava aberta, "
                            + "sem criar uma segunda nem disparar um segundo aviso",
                    example = "false")
            boolean deduplicated,

            @Schema(description = "A única pergunta que a tela precisa fazer antes de prometer "
                            + "\"avisei a Ana\"", example = "false")
            boolean canPromiseAlert,
            @Schema(description = "Motivo da degradação: simulated_transport, no_registered_device "
                            + "ou throttled; nulo quando o aviso pode ser prometido",
                    example = "simulated_transport")
            String degradedReason,
            @Schema(description = "Frase segura para o assistente falar neste estado. A tela pode "
                            + "trocar a redação, nunca aumentar a promessa.",
                    example = "Não consigo avisar a Ana daqui. Toque no botão grande para ligar para ela.")
            String spokenMessage) { }

    /**
     * Resposta do cancelamento. Os dois campos que importam são {@code withinWindow} e
     * {@code alertSent}: juntos dizem se o "foi engano" chegou a tempo de o aviso não sair, ou se
     * chegou depois — caso em que <b>nada é desfeito</b> e a retração é o que resta.
     */
    public record CancelResponse(
            UUID emergencyId,
            @Schema(example = "cancelled") EmergencyState state,
            @Schema(description = "true = chegou antes do disparador; false = o aviso já tinha saído",
                    example = "true")
            boolean withinWindow,
            @Schema(description = "Se o aviso original saiu. Cancelar depois disso não o apaga.",
                    example = "false")
            boolean alertSent,
            @Schema(description = "Se o segundo aviso (\"foi engano, a Maria cancelou\") saiu",
                    example = "true")
            boolean retractionSent,
            @Schema(example = "true") boolean simulated,
            String spokenMessage) { }

    /** Resposta do "estou indo" — é o que fecha o loop e para o escalonamento. */
    public record AckResponse(
            UUID emergencyId,
            @Schema(example = "acknowledged") EmergencyState state,
            Instant acknowledgedAt,
            @Schema(example = "Ana") String acknowledgedByName,
            @Schema(description = "Se esta confirmação impediu o escalonamento aos demais membros",
                    example = "true")
            boolean escalationStopped,
            String spokenMessage) { }

    /**
     * Estado do aviso para a tela de pós-pedido — a tela em que a Maria vê o que aconteceu.
     *
     * <p>Deliberadamente magro: <b>nenhum fator clínico, nenhum endereço, nenhum nome de paciente.</b>
     * A rota é aberta (a mesma sessão inexistente da regra 3), então tudo que ela devolve é tudo
     * que vaza para quem tiver o identificador da emergência.
     */
    public record StatusResponse(
            UUID emergencyId,
            @Schema(example = "dispatched") EmergencyState state,
            Instant createdAt,
            Instant dispatchAt,
            Instant dispatchedAt,
            Instant acknowledgedAt,
            @Schema(example = "Ana") String acknowledgedByName,
            @Schema(example = "false") boolean escalated,
            @Schema(example = "1") int notifiedCount,
            @Schema(example = "false") boolean transportReal,
            @Schema(example = "true") boolean simulated,
            @Schema(example = "false") boolean canPromiseAlert,
            String degradedReason,
            String spokenMessage) { }
}
