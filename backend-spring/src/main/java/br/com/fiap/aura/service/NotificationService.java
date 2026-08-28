package br.com.fiap.aura.service;

import br.com.fiap.aura.domain.DeliveryOrder;
import br.com.fiap.aura.domain.Home;
import br.com.fiap.aura.domain.UserAccount;
import br.com.fiap.aura.domain.enums.PushKind;
import br.com.fiap.aura.repository.DeliveryOrderRepository;
import br.com.fiap.aura.repository.UserAccountRepository;
import br.com.fiap.aura.security.AuthPrincipal;
import br.com.fiap.aura.web.dto.NotificationDtos;
import br.com.fiap.aura.web.error.ApiException;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;

/**
 * Compõe e dispara o aviso que chega no celular de quem cuida.
 *
 * <p><b>Limitação declarada (C2):</b> {@code UserAccount.fcmToken} é <b>uma coluna, um aparelho</b>,
 * sobrescrita a cada login — e o destinatário do aviso é sempre o dono da casa. Logo, na
 * demonstração quem dispara e quem recebe podem ser a mesma pessoa (a Ana é dona e cuidadora), e
 * "avisar os cuidadores da casa" no plural não existe ainda: multi-dispositivo é tabela nova e o
 * escalonamento para os demais vínculos de {@code home_members} é escopo do C3.
 */
@Service
public class NotificationService {

    /** Título curto: o que a tela de bloqueio mostra em negrito antes do corpo. */
    private static final String TITLE = "AURA";

    private final HomeService homeService;
    private final UserAccountRepository users;
    private final DeliveryOrderRepository orders;
    private final FcmService fcm;

    public NotificationService(HomeService homeService, UserAccountRepository users,
                               DeliveryOrderRepository orders, FcmService fcm) {
        this.homeService = homeService;
        this.users = users;
        this.orders = orders;
        this.fcm = fcm;
    }

    /**
     * Aviso de teste: é o que torna a cena gravável — o celular apita e o toque abre o pedido.
     * Não há disparo automático no {@code advance} do pedido nesta janela (decisão de prioridade
     * do C2): esta rota prova a mesma cena pelo mesmo preço.
     *
     * <p>Sem {@code @Transactional} de propósito: as três leituras já vêm de transações próprias,
     * e envolver tudo seguraria uma conexão do pool durante a chamada de rede ao Firebase.
     */
    public NotificationDtos.TestPushResponse sendTest(AuthPrincipal principal,
                                                      NotificationDtos.TestPushRequest req) {
        Home home = homeService.requireAccess(principal, req.homeId());
        UserAccount destinatario = users.findById(home.getOwnerUserId())
                .orElseThrow(() -> ApiException.notFound("Destinatário do aviso"));

        String deviceToken = destinatario.getFcmToken();
        if (deviceToken == null || deviceToken.isBlank()) {
            // 422 explícito, nunca 500: sem aparelho registrado não há para onde mandar, e o
            // chamador precisa saber que o problema é o cadastro do token, não o Firebase
            throw ApiException.unprocessable("PUSH_TOKEN_MISSING",
                    "Nenhum aparelho registrado para receber o aviso. Faça login no app "
                            + "ou chame POST /api/v1/notifications/register-token antes.");
        }

        PushKind kind = req.kind() == null ? PushKind.RECOMMENDATION : req.kind();
        UUID orderId = orders.findByHomeIdOrderByCreatedAtDesc(home.getId()).stream()
                .findFirst().map(DeliveryOrder::getId).orElse(null);

        FcmService.PushResult result = fcm.send(compose(kind, home, orderId, deviceToken));
        return new NotificationDtos.TestPushResponse(result.messageId(), result.latencyMs(), result.simulated());
    }

    /**
     * Visível para teste: é aqui que mora a regra de privacidade do aviso.
     *
     * <p><b>Nenhum corpo carrega fator clínico.</b> O texto fala da casa e convida ao toque —
     * nunca "quase-queda relatada", que apareceria na tela de bloqueio de quem pegasse o celular
     * do sofá. O fator continua existindo do outro lado do deep link, atrás da autenticação.
     *
     * <p>{@code data.orderId} é o deep link: o app abre o pedido em vez da tela inicial. Vem nulo
     * quando a casa ainda não tem pedido nenhum — e o app cai na lista, sem estourar.
     */
    static FcmService.PushMessage compose(PushKind kind, Home home, UUID orderId, String deviceToken) {
        Map<String, String> data = new LinkedHashMap<>();
        data.put("kind", kind.value());
        data.put("homeId", home.getId().toString());
        if (orderId != null) {
            data.put("orderId", orderId.toString());
        }
        return new FcmService.PushMessage(deviceToken, TITLE, body(kind, home.getPatientName()), data);
    }

    private static String body(PushKind kind, String patientName) {
        String nome = firstName(patientName);
        String casa = nome == null ? "casa" : "casa da " + nome;
        return switch (kind) {
            case RECOMMENDATION -> "Nova recomendação para a %s. Toque para ver.".formatted(casa);
            case ORDER -> "Novidade no pedido da %s. Toque para ver.".formatted(casa);
        };
    }

    /** "Maria S." vira "Maria": o sobrenome abreviado deixaria dois pontos seguidos na frase. */
    private static String firstName(String patientName) {
        if (patientName == null || patientName.isBlank()) {
            return null;
        }
        return patientName.trim().split("\\s+")[0];
    }
}
