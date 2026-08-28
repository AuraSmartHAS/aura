package br.com.fiap.aura.web;

import br.com.fiap.aura.security.CurrentUser;
import br.com.fiap.aura.service.NotificationService;
import br.com.fiap.aura.web.dto.NotificationDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(value = "/api/v1", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "7. Notificações", description = "Push no celular de quem cuida — com modo simulado declarado")
public class NotificationController {

    private final NotificationService notifications;
    private final CurrentUser currentUser;

    public NotificationController(NotificationService notifications, CurrentUser currentUser) {
        this.notifications = notifications;
        this.currentUser = currentUser;
    }

    @PostMapping("/notifications/test")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Dispara um aviso de teste para o dono da casa e devolve a latência medida",
               description = """
                       Exige um aparelho já registrado em `POST /api/v1/notifications/register-token`.
                       O payload leva `data.orderId` do último pedido da casa, que é o deep link do app.

                       Sem credencial do Firebase no servidor, responde `simulated: true`: nada saiu
                       daqui. Quem consome **precisa** olhar esse campo antes de prometer entrega —
                       o SOS, por exemplo, troca o botão por uma ligação quando ele vem verdadeiro.

                       Nenhum corpo de aviso carrega fator clínico: o texto fala da casa, não do risco.
                       """)
    public NotificationDtos.TestPushResponse test(@Valid @RequestBody NotificationDtos.TestPushRequest req) {
        return notifications.sendTest(currentUser.require(), req);
    }
}
