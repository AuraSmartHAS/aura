package br.com.fiap.aura.web;

import br.com.fiap.aura.security.AuthPrincipal;
import br.com.fiap.aura.security.CurrentUser;
import br.com.fiap.aura.service.EmergencyService;
import br.com.fiap.aura.web.dto.EmergencyDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * SOS e fluxo de crise (C3). Três rotas <b>abertas</b> e uma autenticada, e a divisão não é
 * descuido:
 *
 * <ul>
 *   <li><b>Aberto</b> — pedir socorro, dizer "foi engano" e ver o estado do aviso. Se a sessão
 *       expirou, o socorro não pode depender de uma senha que a Maria não vai digitar no chão do
 *       banheiro. A chave é o identificador da casa que o aparelho já guarda.</li>
 *   <li><b>Autenticado</b> — "estou indo". Quem confirma está de pé, chegando pelo push, e a
 *       confirmação precisa de autor: dizer à Maria "alguém está indo" sem saber quem é pior que
 *       não dizer nada.</li>
 * </ul>
 *
 * <p>A análise de abuso do acesso sem sessão, com o risco residual declarado, está no
 * {@code EmergencyService#contidoPorAbuso}. Resumo: a requisição não nomeia destino, o aviso só
 * alcança quem já está vinculado àquela casa, e disparo repetido coalesce em vez de multiplicar.
 */
@RestController
@RequestMapping(value = "/api/v1/emergencies", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "8. SOS e crise", description = "Pedido de socorro com janela de cancelamento no servidor")
public class EmergencyController {

    private final EmergencyService emergencies;
    private final CurrentUser currentUser;

    public EmergencyController(EmergencyService emergencies, CurrentUser currentUser) {
        this.emergencies = emergencies;
        this.currentUser = currentUser;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @SecurityRequirements
    @Operation(summary = "Registra o pedido de socorro e agenda o disparo do aviso no servidor",
               description = """
                       **Não exige autenticação** (C3, regra 3): a Maria precisa pedir ajuda com a
                       sessão expirada. A chave é o `homeId` que o aparelho já guarda.

                       Responde **na hora**, antes de qualquer push. O aviso sai em `dispatchAt`,
                       por conta do **servidor** — o aparelho não precisa continuar vivo, o que é o
                       ponto: cronômetro de cliente morre quando o telefone cai da mão.

                       Antes de prometer "avisei a Ana", olhe `canPromiseAlert`. Ele vem `false`
                       quando o push é simulado (`degradedReason: simulated_transport`), quando a
                       casa não tem aparelho registrado (`no_registered_device`) ou quando o disparo
                       foi contido pela mitigação de abuso (`throttled`). Nos três casos a tela deve
                       oferecer **ligação telefônica** em vez de anunciar entrega.

                       Toque repetido na mesma casa devolve a emergência já aberta com
                       `deduplicated: true` — sem segunda linha e sem segundo aviso.
                       """)
    public EmergencyDtos.TriggerResponse trigger(@Valid @RequestBody EmergencyDtos.TriggerRequest req) {
        return emergencies.trigger(principalOuNulo(), req);
    }

    @PostMapping("/{emergencyId}/cancel")
    @SecurityRequirements
    @Operation(summary = "\"Foi engano\" — cancela dentro da janela e avisa quem precisa saber",
               description = """
                       Dentro da janela, o aviso original **não sai**; ainda assim o segundo aviso
                       ("foi engano, a Maria cancelou") é enviado, porque quem cuida tem direito de
                       saber que o botão foi apertado.

                       Fora da janela, **nada é desfeito**: `withinWindow: false`, `alertSent: true`,
                       o estado permanece `dispatched`/`escalated` e o histórico continua dizendo que
                       o aviso saiu. A retração vai de todo modo — a Ana está na rua.
                       """)
    public EmergencyDtos.CancelResponse cancel(@PathVariable UUID emergencyId) {
        return emergencies.cancel(emergencyId);
    }

    @PostMapping("/{emergencyId}/ack")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "\"Estou indo\" — fecha o loop e para o escalonamento",
               description = """
                       Única rota do fluxo que exige sessão: a confirmação precisa de autor.
                       Exige acesso à casa (dono, vínculo em `home_members` ou admin).

                       É isto que impede o escalonamento aos demais membros da casa. Sem esta
                       chamada, o SOS é só disparo — não há loop.
                       """)
    public EmergencyDtos.AckResponse acknowledge(@PathVariable UUID emergencyId) {
        return emergencies.acknowledge(currentUser.require(), emergencyId);
    }

    @GetMapping("/{emergencyId}")
    @SecurityRequirements
    @Operation(summary = "Estado do aviso, para a tela de pós-pedido",
               description = """
                       Aberta, como o disparo — é a mesma tela e a mesma sessão inexistente. Por
                       isso o corpo é magro de propósito: **nenhum fator clínico, nenhum endereço,
                       nenhum nome de paciente**. É daqui que a tela lê os quatro estados falados.
                       """)
    public EmergencyDtos.StatusResponse status(@PathVariable UUID emergencyId) {
        return emergencies.status(emergencyId);
    }

    /**
     * O principal <b>quando existe</b>. Não usa {@code currentUser.require()} de propósito: nesta
     * rota a ausência de sessão é o caso de uso, não um erro.
     *
     * <p>O {@code JwtAuthenticationFilter} continua rodando e continua recusando token inválido com
     * 401 — o que é o comportamento certo: token corrompido é sintoma de bug no cliente, e mascarar
     * isso como "disparo anônimo" esconderia o problema. Sem cabeçalho nenhum, aqui é nulo.
     */
    private AuthPrincipal principalOuNulo() {
        var auth = SecurityContextHolder.getContext().getAuthentication();
        return auth != null && auth.getPrincipal() instanceof AuthPrincipal principal ? principal : null;
    }
}
