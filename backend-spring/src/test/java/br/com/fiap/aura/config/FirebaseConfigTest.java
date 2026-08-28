package br.com.fiap.aura.config;

import static org.assertj.core.api.Assertions.assertThat;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.util.Base64;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** O caminho da credencial e o caminho sem ela — os dois têm de existir sem derrubar o boot. */
class FirebaseConfigTest {

    private static final String APP_DE_TESTE = "aura-teste";

    @AfterEach
    void limpaOApp() {
        FirebaseApp.getApps().stream()
                .filter(app -> APP_DE_TESTE.equals(app.getName()))
                .forEach(FirebaseApp::delete);
    }

    private AuraProperties props(String credentialsPath, String credentialsJson) {
        return new AuraProperties(null, null, null, null, null,
                new AuraProperties.Push(credentialsPath, credentialsJson), null);
    }

    /** Conta de serviço sintética: chave RSA gerada aqui, porque o SDK a valida ao carregar. */
    private String contaDeServico() throws Exception {
        KeyPairGenerator gerador = KeyPairGenerator.getInstance("RSA");
        gerador.initialize(2048);
        KeyPair par = gerador.generateKeyPair();
        String pem = "-----BEGIN PRIVATE KEY-----\n"
                + Base64.getMimeEncoder(64, "\n".getBytes(StandardCharsets.UTF_8))
                        .encodeToString(par.getPrivate().getEncoded())
                + "\n-----END PRIVATE KEY-----\n";
        return """
                {"type":"service_account","project_id":"aura-demo","private_key_id":"chave-de-teste",
                 "private_key":"%s","client_email":"aura@aura-demo.iam.gserviceaccount.com",
                 "client_id":"1234567890","token_uri":"https://oauth2.googleapis.com/token"}"""
                .formatted(pem.replace("\n", "\\n"));
    }

    @Test
    @DisplayName("com credencial, o SDK carrega inteiro — é o que prova as exclusões do pom.xml")
    void credencialCarregaOTransporteReal() throws Exception {
        // Firestore e Cloud Storage estão excluídos do firebase-admin no pom para o build não
        // arrastar ~40 jars. Se a poda tivesse levado uma classe do caminho do FCM, só apareceria
        // com credencial de verdade — ou seja, em produção. Este teste é o gate dela.
        FirebaseMessaging messaging = FirebaseConfig.messagingFrom(
                new ByteArrayInputStream(contaDeServico().getBytes(StandardCharsets.UTF_8)), APP_DE_TESTE);

        assertThat(messaging).isNotNull();
    }

    @Test
    @DisplayName("sem credencial, e com credencial inválida, o bean vem nulo em vez de estourar")
    void semCredencialNaoDerrubaOBoot() {
        assertThat(new FirebaseConfig().firebaseMessaging(props("", ""))).isNull();
        assertThat(new FirebaseConfig().firebaseMessaging(props(null, null))).isNull();

        // caminho configurado errado é problema de operação, não motivo para a API não subir:
        // vira log de erro e push simulado, que ao menos se declara na resposta
        assertThat(new FirebaseConfig().firebaseMessaging(props("/nao/existe/credencial.json", null))).isNull();
    }
}
