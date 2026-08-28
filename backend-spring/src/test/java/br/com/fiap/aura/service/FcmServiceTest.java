package br.com.fiap.aura.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import br.com.fiap.aura.domain.Emergency;
import br.com.fiap.aura.domain.Home;
import br.com.fiap.aura.domain.enums.EmergencyChannel;
import br.com.fiap.aura.domain.enums.EmergencyState;
import br.com.fiap.aura.domain.enums.PushKind;
import br.com.fiap.aura.web.error.ApiException;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/** Transporte do push com o SDK do Firebase dublado — nenhuma chamada de rede sai daqui. */
@ExtendWith(MockitoExtension.class)
class FcmServiceTest {

    private static final String DEVICE_TOKEN = "fMbQ7…token-do-aparelho-da-ana…9xK2c";

    @Mock
    private FirebaseMessaging messaging;

    private final UUID homeId = UUID.randomUUID();
    private final UUID orderId = UUID.randomUUID();
    private final UUID emergencyId = UUID.randomUUID();

    private Home casa() {
        return Home.builder().id(homeId).patientName("Maria S.").label("Casa da Maria").build();
    }

    private FcmService.PushMessage aviso(PushKind kind, UUID pedido) {
        return NotificationService.compose(kind, casa(), pedido, DEVICE_TOKEN);
    }

    @Test
    @DisplayName("com credencial, o envio passa pelo SDK e devolve o messageId real e a latência")
    void enviaPeloSdkComCredencial() throws Exception {
        when(messaging.send(any(Message.class))).thenReturn("projects/aura/messages/0:1724800000%3Ade3f");

        FcmService.PushResult result = new FcmService(messaging).send(aviso(PushKind.RECOMMENDATION, orderId));

        assertThat(result.simulated()).isFalse();
        assertThat(result.messageId()).isEqualTo("projects/aura/messages/0:1724800000%3Ade3f");
        assertThat(result.latencyMs()).isNotNegative();
        verify(messaging).send(any(Message.class));
    }

    @Test
    @DisplayName("sem credencial o disparo se declara simulado e nada é entregue ao SDK")
    void semCredencialDegradaParaSimulado() {
        FcmService fcm = new FcmService(null);

        FcmService.PushResult result = fcm.send(aviso(PushKind.RECOMMENDATION, orderId));

        // é este par — transportReal() falso e simulated verdadeiro — que o SOS (C3, regra 1) lê
        // antes de prometer "avisei a Ana"; sem ele, um push que não saiu passaria por enviado
        assertThat(fcm.transportReal()).isFalse();
        assertThat(result.simulated()).isTrue();
        assertThat(result.messageId()).startsWith("simulado:");
        assertThat(result.latencyMs()).isNotNegative();
        verifyNoInteractions(messaging);
    }

    @Test
    @DisplayName("o aviso leva o deep link do pedido e nenhum fator clínico no corpo")
    void corpoSemFatorClinicoEComDeepLink() {
        FcmService.PushMessage comPedido = aviso(PushKind.RECOMMENDATION, orderId);

        assertThat(comPedido.data())
                .containsEntry("kind", "recommendation")
                .containsEntry("homeId", homeId.toString())
                .containsEntry("orderId", orderId.toString());

        // o texto que aparece na tela de bloqueio de quem pegar o celular: fala da casa, não do risco
        assertThat(comPedido.body()).isEqualTo("Nova recomendação para a casa da Maria. Toque para ver.");
        assertThat(comPedido.body()).doesNotContain("queda", "risco", "banheiro", "barra");
        assertThat(comPedido.title()).isEqualTo("AURA");

        // casa sem pedido nenhum: o deep link some em vez de viajar vazio, e o app cai na lista
        assertThat(aviso(PushKind.ORDER, null).data()).doesNotContainKey("orderId");
        assertThat(aviso(PushKind.ORDER, null).body())
                .isEqualTo("Novidade no pedido da casa da Maria. Toque para ver.");
    }

    /** A emergência do C3, com o mínimo para compor o aviso. */
    private Emergency emergencia(EmergencyState estado) {
        return Emergency.builder()
                .id(emergencyId).homeId(homeId).state(estado)
                .channel(EmergencyChannel.TOUCH)
                .lat(-23.561).lng(-46.656)
                .build();
    }

    @Test
    @DisplayName("o aviso de SOS leva localização e prioridade alta, e nenhum fator clínico no texto")
    void avisoDeSosComLocalizacaoESemFatorClinico() {
        Home casa = Home.builder().id(homeId).patientName("Maria S.").label("Casa da Maria")
                .address("Av. Paulista, Bela Vista, São Paulo, SP").build();

        FcmService.PushMessage sos = NotificationService.composeSos(
                PushKind.SOS, casa, emergencia(EmergencyState.DISPATCHED), DEVICE_TOKEN);

        // o texto visível na tela de bloqueio diz que alguém pediu ajuda — e nada além disso
        assertThat(sos.title()).isEqualTo("AURA · Pedido de ajuda");
        assertThat(sos.body()).isEqualTo("A Maria pediu ajuda agora. Toque para abrir.");
        assertThat(sos.title() + " " + sos.body()).doesNotContainIgnoringCase(
                "queda", "risco", "banheiro", "barra", "Parkinson", "tontura", "escore");

        // o endereço e as coordenadas viajam em data, que NÃO é renderizado na tela de bloqueio —
        // e sem eles o aviso é inútil para quem precisa chegar até lá
        assertThat(sos.data())
                .containsEntry("kind", "sos")
                .containsEntry("homeId", homeId.toString())
                .containsEntry("emergencyId", emergencyId.toString())
                .containsEntry("state", "dispatched")
                .containsEntry("action", "ack")
                .containsEntry("lat", "-23.561")
                .containsEntry("lng", "-46.656")
                .containsEntry("address", "Av. Paulista, Bela Vista, São Paulo, SP");

        // prioridade alta: às 3h da manhã, aviso de queda na fila de economia de bateria é nenhum aviso
        assertThat(sos.highPriority()).isTrue();
        // e o aviso comum do C2 continua sem prioridade alta — prioridade em tudo é prioridade em nada
        assertThat(aviso(PushKind.RECOMMENDATION, orderId).highPriority()).isFalse();
    }

    @Test
    @DisplayName("a retração diz que foi engano e não pede toque de socorro nenhum")
    void retracaoDizQueFoiEngano() {
        Home casa = Home.builder().id(homeId).patientName("Maria S.").build();

        FcmService.PushMessage retracao = NotificationService.composeSos(
                PushKind.SOS_CANCELLED, casa, emergencia(EmergencyState.CANCELLED), DEVICE_TOKEN);

        assertThat(retracao.title()).isEqualTo("AURA · Alarme cancelado");
        assertThat(retracao.body()).isEqualTo("Foi engano, a Maria cancelou. Está tudo bem.");
        // sem botão de "estou indo": não há para onde ir, e oferecer a ação confundiria
        assertThat(retracao.data()).containsEntry("action", "none");
        // casa sem endereço resolvido não faz o payload estourar: a chave simplesmente não vai
        assertThat(retracao.data()).doesNotContainKey("address");
    }

    @Test
    @DisplayName("recusa do Firebase vira erro de negócio explicado, nunca 500")
    void falhaDoSdkViraErroDeNegocio() throws Exception {
        when(messaging.send(any(Message.class))).thenThrow(FirebaseMessagingException.class);

        assertThatThrownBy(() -> new FcmService(messaging).send(aviso(PushKind.RECOMMENDATION, orderId)))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("Firebase não aceitou");
    }
}
