package br.com.fiap.aura.service;

import br.com.fiap.aura.domain.DeliveryOrder;
import br.com.fiap.aura.domain.Emergency;
import br.com.fiap.aura.domain.Home;
import br.com.fiap.aura.domain.UserAccount;
import br.com.fiap.aura.domain.enums.OrderStage;
import br.com.fiap.aura.domain.enums.PushKind;
import br.com.fiap.aura.repository.DeliveryOrderRepository;
import br.com.fiap.aura.repository.HomeRepository;
import br.com.fiap.aura.repository.UserAccountRepository;
import br.com.fiap.aura.security.AuthPrincipal;
import br.com.fiap.aura.web.dto.NotificationDtos;
import br.com.fiap.aura.web.error.ApiException;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Compõe e dispara o aviso que chega no celular de quem cuida.
 *
 * <p><b>Limitação declarada (C2):</b> {@code UserAccount.fcmToken} é <b>uma coluna, um aparelho</b>,
 * sobrescrita a cada login. Multi-dispositivo continua sendo tabela nova e continua fora: uma pessoa
 * com celular e tablet recebe no último em que fez login, e só nele.
 *
 * <p><b>O que o C3 acrescentou:</b> {@link #sendSos} e o plural. O aviso de crise vai para os
 * vínculos de {@code home_members} da casa, não só para o dono — mas quem escolhe os destinatários
 * e a ordem é o {@code EmergencyService}; aqui ficam a composição do texto e a regra de privacidade.
 */
@Service
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    /** Título curto: o que a tela de bloqueio mostra em negrito antes do corpo. */
    private static final String TITLE = "AURA";

    private final HomeService homeService;
    private final HomeRepository homes;
    private final UserAccountRepository users;
    private final DeliveryOrderRepository orders;
    private final FcmService fcm;

    public NotificationService(HomeService homeService, HomeRepository homes, UserAccountRepository users,
                               DeliveryOrderRepository orders, FcmService fcm) {
        this.homeService = homeService;
        this.homes = homes;
        this.users = users;
        this.orders = orders;
        this.fcm = fcm;
    }

    /**
     * Aviso de teste: é o que torna a cena gravável — o celular apita e o toque abre o pedido.
     * O disparo automático por evento (pedido que avança, recomendação nova) mora em
     * {@link PushOnBusinessEvents}; esta rota continua servindo para provar o caminho sob demanda.
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
     * Pedido mudou de estágio: avisa o dono da casa, com o pedido no deep link. Devolve se algum
     * aviso foi entregue ao transporte (simulado conta: o chamador só registra).
     */
    public boolean notifyOrderStage(PushEvents.OrderStageChanged event) {
        Map<String, String> data = new LinkedHashMap<>();
        data.put("orderId", event.orderId().toString());
        data.put("stage", event.stage().value());
        return notifyOwner(PushKind.ORDER, event.homeId(), event.actorUserId(), data,
                home -> orderBody(event.stage(), home.getPatientName()));
    }

    /** Recomendação nova: avisa o dono da casa, com a recomendação no deep link. */
    public boolean notifyRecommendation(PushEvents.RecommendationCreated event) {
        Map<String, String> data = new LinkedHashMap<>();
        data.put("recommendationId", event.recommendationId().toString());
        return notifyOwner(PushKind.RECOMMENDATION, event.homeId(), event.actorUserId(), data,
                home -> body(PushKind.RECOMMENDATION, home.getPatientName()));
    }

    private boolean notifyOwner(PushKind kind, UUID homeId, UUID actorUserId, Map<String, String> extra,
                                java.util.function.Function<Home, String> bodyOf) {
        Optional<Home> home = homes.findById(homeId);
        if (home.isEmpty()) {
            return false;
        }
        UUID ownerId = home.get().getOwnerUserId();
        if (ownerId.equals(actorUserId)) {
            // quem acabou de agir já sabe o que fez: aviso para si mesmo é ruído
            return false;
        }
        Optional<String> token = users.findById(ownerId).map(UserAccount::getFcmToken)
                .filter(t -> !t.isBlank());
        if (token.isEmpty()) {
            log.info("Aviso {} da casa {} sem destino: o dono não tem aparelho registrado",
                    kind.value(), homeId);
            return false;
        }
        Map<String, String> data = new LinkedHashMap<>();
        data.put("kind", kind.value());
        data.put("homeId", homeId.toString());
        data.putAll(extra);
        fcm.send(new FcmService.PushMessage(token.get(), TITLE, bodyOf.apply(home.get()), data));
        return true;
    }

    /**
     * Visível para teste. O estágio entra no texto; o item, não: "barra de apoio" na tela de
     * bloqueio já conta o risco que a recomendação veio tratar.
     */
    static String orderBody(OrderStage stage, String patientName) {
        String nome = firstName(patientName);
        String pedido = nome == null ? "O pedido da casa" : "O pedido da casa da " + nome;
        return switch (stage) {
            case APPROVED -> pedido + " foi aprovado. Toque para acompanhar.";
            case SOURCING -> pedido + " está sendo separado. Toque para acompanhar.";
            case IN_ROUTE -> pedido + " saiu para entrega. Toque para acompanhar.";
            case DELIVERED -> pedido + " foi entregue. Toque para ver.";
            case INSTALLED -> pedido + " foi instalado. Toque para ver.";
            case RETURNED -> pedido + " foi encerrado. Toque para ver.";
        };
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

    /**
     * Envia <b>um</b> aviso de crise (C3) para <b>um</b> aparelho, com prioridade alta e a
     * localização da casa no payload.
     *
     * <p>Fica aqui, e não no {@code EmergencyService}, porque é aqui que mora a regra de privacidade
     * do corpo do aviso — e o SOS é justamente o aviso em que a tentação de contar o motivo clínico
     * é maior. Quem orquestra <i>para quem</i> mandar é o {@code EmergencyService}; quem decide
     * <i>o que o texto pode dizer</i> é esta classe, um lugar só.
     *
     * <p>Não trata falha: a recusa do FCM sobe como {@link ApiException} e é o chamador que decide
     * o que fazer — no SOS, seguir para o próximo aparelho, porque um token revogado da Ana não
     * pode impedir o aviso de chegar no celular do filho.
     */
    public FcmService.PushResult sendSos(PushKind kind, Home home, Emergency emergency, String deviceToken) {
        return fcm.send(composeSos(kind, home, emergency, deviceToken));
    }

    /**
     * Visível para teste. Mesma regra de privacidade do {@link #compose}, com uma diferença que
     * merece atenção: aqui o <b>endereço e as coordenadas</b> da casa viajam em {@code data}.
     *
     * <p>Isso é deliberado e não contradiz a regra: {@code data} não é renderizado na tela de
     * bloqueio — só {@code title} e {@code body} são —, e sem o endereço o aviso é inútil para quem
     * precisa chegar até lá. O que continua fora do corpo visível é o <b>fator clínico</b>: não há
     * "queda", "Parkinson", "banheiro", "risco" nem escore em texto nenhum. O corpo diz que alguém
     * pediu ajuda; o motivo continua atrás da autenticação, do outro lado do deep link.
     */
    static FcmService.PushMessage composeSos(PushKind kind, Home home, Emergency emergency,
                                             String deviceToken) {
        Map<String, String> data = new LinkedHashMap<>();
        data.put("kind", kind.value());
        data.put("homeId", home.getId().toString());
        data.put("emergencyId", emergency.getId().toString());
        data.put("state", emergency.getState().value());
        // "estou indo" em um toque: sem este par o push é só disparo, não fecha o loop
        data.put("action", kind == PushKind.SOS_CANCELLED ? "none" : "ack");
        if (emergency.getLat() != null && emergency.getLng() != null) {
            data.put("lat", emergency.getLat().toString());
            data.put("lng", emergency.getLng().toString());
        }
        if (home.getAddress() != null) {
            data.put("address", home.getAddress());
        }
        return new FcmService.PushMessage(deviceToken, title(kind),
                body(kind, home.getPatientName()), data, true);
    }

    /**
     * O título é o que a Ana lê de relance na tela de bloqueio, e é o que separa "chegou uma
     * recomendação de compra" de "alguém pediu ajuda". Um título único para tudo ("AURA") tornaria
     * as duas coisas indistinguíveis no exato momento em que a diferença é a que importa.
     */
    private static String title(PushKind kind) {
        return switch (kind) {
            case SOS, SOS_ESCALATED -> "AURA · Pedido de ajuda";
            case SOS_CANCELLED -> "AURA · Alarme cancelado";
            case RECOMMENDATION, ORDER -> TITLE;
        };
    }

    private static String body(PushKind kind, String patientName) {
        String nome = firstName(patientName);
        String casa = nome == null ? "casa" : "casa da " + nome;
        // sem nome no cadastro a frase não pode virar "A  pediu ajuda": cai num sujeito genérico
        String quem = nome == null ? "Alguém da casa" : "A " + nome;
        return switch (kind) {
            case RECOMMENDATION -> "Nova recomendação para a %s. Toque para ver.".formatted(casa);
            case ORDER -> "Novidade no pedido da %s. Toque para ver.".formatted(casa);
            case SOS -> "%s pediu ajuda agora. Toque para abrir.".formatted(quem);
            case SOS_ESCALATED ->
                    "%s pediu ajuda e ninguém confirmou ainda. Toque para abrir.".formatted(quem);
            case SOS_CANCELLED -> nome == null
                    ? "Foi engano, o pedido de ajuda foi cancelado. Está tudo bem."
                    : "Foi engano, a %s cancelou. Está tudo bem.".formatted(nome);
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
