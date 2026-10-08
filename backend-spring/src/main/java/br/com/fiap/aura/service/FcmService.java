package br.com.fiap.aura.service;

import br.com.fiap.aura.web.error.ApiException;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.Aps;
import com.google.firebase.messaging.ApsAlert;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.lang.Nullable;
import org.springframework.stereotype.Service;

/**
 * Envio de push pelo Firebase Admin SDK, com um único ponto de degradação: sem credencial
 * configurada o transporte real não existe, o envio é registrado no log e a resposta se declara
 * {@code simulated}.
 *
 * <p><b>Por que o {@code simulated} chega ao chamador e não fica só no log:</b> o SOS (C3) só pode
 * prometer "avisei a Ana" quando o aviso saiu de verdade. Push simulado tratado como enviado é
 * pior do que não ter push — quem chama precisa poder trocar de caminho (ligar, por exemplo).
 */
@Service
public class FcmService {

    private static final Logger log = LoggerFactory.getLogger(FcmService.class);

    /**
     * Canais Android criados pelos apps no startup (Flutter e RN, mesmos ids). O do SOS toca e
     * vibra com importância máxima; o geral é o de pedidos e recomendações. Canal que o app não
     * criou faz o Android cair num canal genérico sem som — os ids aqui e lá têm de ser iguais.
     */
    static final String CHANNEL_SOS = "aura_sos";
    static final String CHANNEL_GERAL = "aura_geral";

    /**
     * Categoria do aviso de SOS que leva o botão "Estou indo". Os apps registram a categoria com a
     * ação {@code ack}; o RN (expo-notifications) a lê de {@code data.categoryId}, o Flutter a
     * reconhece pelo mesmo campo.
     */
    static final String CATEGORY_SOS_ACK = "aura_sos_ack";

    /** Prefixo do identificador do modo simulado: nenhum id do FCM se parece com isso. */
    private static final String SIMULATED_PREFIX = "simulado:";

    /**
     * O aviso pronto para sair. {@code data} é o payload do deep link (valores só de texto no FCM).
     *
     * <p>{@code highPriority} é o que o SOS (C3) precisa e uma recomendação de compra não: no
     * Android tira o aviso da fila do <i>doze mode</i>, no iOS pede
     * {@code interruption-level: time-sensitive}, que é o que atravessa Foco e Não Perturbe. Às 3h
     * da manhã, um aviso de queda dormindo na fila de economia de bateria é o mesmo que nenhum
     * aviso. Não é o padrão de propósito: prioridade alta em tudo é como se perde a prioridade alta.
     */
    public record PushMessage(String deviceToken, String title, String body, Map<String, String> data,
                              boolean highPriority) {

        /** Aviso comum (recomendação, pedido): prioridade normal. */
        public PushMessage(String deviceToken, String title, String body, Map<String, String> data) {
            this(deviceToken, title, body, data, false);
        }
    }

    /** {@code simulated} responde uma pergunta só: o push saiu de verdade deste servidor? */
    public record PushResult(String messageId, long latencyMs, boolean simulated) { }

    private final FirebaseMessaging messaging;

    public FcmService(@Nullable FirebaseMessaging messaging) {
        this.messaging = messaging;
    }

    /** Se existe transporte real. É o que o SOS (C3, regra 1) precisa saber <b>antes</b> de prometer. */
    public boolean transportReal() {
        return messaging != null;
    }

    public PushResult send(PushMessage message) {
        long inicio = System.nanoTime();
        if (messaging == null) {
            // o corpo do aviso fica fora do log de propósito: ele nomeia a casa da paciente
            log.warn("Push SIMULADO para o dispositivo {} (assunto {}) — nada saiu do servidor",
                    mask(message.deviceToken()), message.data().get("kind"));
            return new PushResult(SIMULATED_PREFIX + UUID.randomUUID(), elapsedMs(inicio), true);
        }
        try {
            Message.Builder builder = Message.builder()
                    .setToken(message.deviceToken())
                    .putAllData(transportData(message));
            if (message.highPriority()) {
                aplicarPrioridadeAlta(builder, message);
            } else {
                builder.setNotification(Notification.builder()
                                .setTitle(message.title())
                                .setBody(message.body())
                                .build())
                        .setAndroidConfig(AndroidConfig.builder()
                                .setPriority(AndroidConfig.Priority.NORMAL)
                                .setNotification(AndroidNotification.builder().setChannelId(CHANNEL_GERAL).build())
                                .build());
            }
            String messageId = messaging.send(builder.build());
            long latencyMs = elapsedMs(inicio);
            log.info("Push enviado para o dispositivo {} em {} ms — messageId {}",
                    mask(message.deviceToken()), latencyMs, messageId);
            return new PushResult(messageId, latencyMs, false);
        } catch (FirebaseMessagingException e) {
            // token revogado, projeto errado ou FCM fora do ar: é falha de transporte, não erro nosso
            log.error("FCM recusou o aviso ao dispositivo {}: {}", mask(message.deviceToken()), e.getMessage());
            throw ApiException.unprocessable("PUSH_FAILED",
                    "O Firebase não aceitou o aviso para este dispositivo. "
                            + "Registre o token novamente pelo app e tente de novo.");
        }
    }

    /**
     * O {@code data} que sai pelo FCM. Aviso comum vai como está. O SOS vai <b>só com dados</b> no
     * Android: o aviso que o próprio sistema desenha a partir do bloco {@code notification} não
     * aceita botão, e o "Estou indo" direto na notificação é o que poupa segundos de quem corre.
     * Então título, texto e canal viajam em {@code data} e cada app desenha o próprio aviso
     * ({@code title}/{@code message}/{@code channelId}/{@code categoryId} são as chaves que o
     * expo-notifications lê; o Flutter usa as mesmas). Só o SOS ainda em aberto leva o botão.
     *
     * <p>Visível para teste. As chaves novas não mudam a regra de privacidade: o texto é o mesmo
     * que já aparece na tela de bloqueio.
     */
    static Map<String, String> transportData(PushMessage message) {
        if (!message.highPriority()) {
            return message.data();
        }
        Map<String, String> data = new LinkedHashMap<>(message.data());
        data.put("title", message.title());
        data.put("message", message.body());
        data.put("channelId", CHANNEL_SOS);
        if ("ack".equals(message.data().get("action"))) {
            data.put("categoryId", CATEGORY_SOS_ACK);
        }
        return data;
    }

    /**
     * Prioridade máxima nas duas plataformas. São dois mecanismos distintos e nenhum dos dois é o
     * padrão do SDK:
     *
     * <ul>
     *   <li><b>Android</b>: {@code priority: high} acorda o app mesmo em <i>doze mode</i> — e é o
     *       que garante que a mensagem só de dados chegue ao app encerrado para ele desenhar o
     *       aviso com o botão.</li>
     *   <li><b>iOS</b>: o cabeçalho {@code apns-priority: 10} entrega imediatamente, e
     *       {@code interruption-level: time-sensitive} é o que faz o aviso atravessar Foco e Não
     *       Perturbe. Sem o bloco {@code notification}, o alerta visível vai no {@code aps}.</li>
     * </ul>
     *
     * <p>Não usamos {@code critical} no iOS: exige <i>entitlement</i> especial da Apple, que este
     * projeto não tem — e prometer alerta crítico sem o entitlement é falhar em silêncio.
     */
    private static void aplicarPrioridadeAlta(Message.Builder builder, PushMessage message) {
        builder.setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .build())
                .setApnsConfig(ApnsConfig.builder()
                        .putHeader("apns-priority", "10")
                        .setAps(Aps.builder()
                                .setAlert(ApsAlert.builder()
                                        .setTitle(message.title())
                                        .setBody(message.body())
                                        .build())
                                .setSound("default")
                                .putCustomData("interruption-level", "time-sensitive")
                                .build())
                        .build());
    }

    private static long elapsedMs(long inicioNanos) {
        return (System.nanoTime() - inicioNanos) / 1_000_000;
    }

    /** Token de dispositivo identifica um aparelho: no log entra só o final, nunca inteiro. */
    private static String mask(String deviceToken) {
        if (deviceToken == null || deviceToken.length() <= 6) {
            return "…";
        }
        return "…" + deviceToken.substring(deviceToken.length() - 6);
    }
}
