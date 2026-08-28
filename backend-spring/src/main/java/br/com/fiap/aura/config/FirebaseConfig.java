package br.com.fiap.aura.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Transporte real do push. Registra o {@link FirebaseMessaging} apenas quando existe credencial
 * configurada — e é de propósito que a ausência dela <b>não</b> derrube o boot: CI e ambiente de
 * desenvolvimento não podem depender de segredo, então o bean vem nulo e o
 * {@code FcmService} passa a responder {@code simulated: true}.
 *
 * <p>Credencial inválida cai no mesmo lugar, com log de erro: derrubar a aplicação na véspera da
 * demonstração por causa de um caminho errado seria pior do que declarar que o push está simulado.
 */
@Configuration
public class FirebaseConfig {

    private static final Logger log = LoggerFactory.getLogger(FirebaseConfig.class);

    /** Nome fixo do FirebaseApp do AURA: boot repetido (testes, restart) reaproveita em vez de duplicar. */
    static final String APP_NAME = "aura";

    /**
     * Devolve {@code null} quando não há credencial. O Spring registra um bean nulo e a injeção
     * anotada com {@code @Nullable} no {@code FcmService} recebe null — é esse null que liga o
     * modo simulado, em um lugar só.
     */
    @Bean
    public FirebaseMessaging firebaseMessaging(AuraProperties props) {
        AuraProperties.Push push = props.push();
        String origem = origem(push);
        if (origem == null) {
            log.warn("Push SIMULADO: sem AURA_FIREBASE_CREDENTIALS nem AURA_FIREBASE_CREDENTIALS_JSON, "
                    + "nenhuma notificação sai do servidor e a API devolve simulated=true");
            return null;
        }
        try (InputStream credencial = abrir(push)) {
            FirebaseMessaging messaging = messagingFrom(credencial, APP_NAME);
            log.info("Push REAL habilitado — credencial do Firebase lida de {}", origem);
            return messaging;
        } catch (IOException | RuntimeException e) {
            log.error("Credencial do Firebase em {} não carregou ({}) — push segue simulado",
                    origem, e.getMessage());
            return null;
        }
    }

    /**
     * Visível para teste: é o que prova que as exclusões de Firestore e Cloud Storage no
     * {@code pom.xml} não quebraram o caminho com credencial — sem credencial de verdade,
     * nenhum teste passaria por aqui e a poda do pom só apareceria em produção.
     */
    static FirebaseMessaging messagingFrom(InputStream credencial, String appName) throws IOException {
        FirebaseOptions options = FirebaseOptions.builder()
                .setCredentials(GoogleCredentials.fromStream(credencial))
                .build();
        FirebaseApp app = FirebaseApp.getApps().stream()
                .filter(existente -> appName.equals(existente.getName()))
                .findFirst()
                .orElseGet(() -> FirebaseApp.initializeApp(options, appName));
        return FirebaseMessaging.getInstance(app);
    }

    /** Nome da origem para o log — nunca o conteúdo da credencial. */
    private static String origem(AuraProperties.Push push) {
        if (push == null) {
            return null;
        }
        if (preenchido(push.credentialsJson())) {
            return "AURA_FIREBASE_CREDENTIALS_JSON";
        }
        return preenchido(push.credentialsPath()) ? push.credentialsPath() : null;
    }

    /** O JSON inteiro tem precedência sobre o caminho: é o que a plataforma de deploy costuma oferecer. */
    private static InputStream abrir(AuraProperties.Push push) throws IOException {
        return preenchido(push.credentialsJson())
                ? new ByteArrayInputStream(push.credentialsJson().getBytes(StandardCharsets.UTF_8))
                : Files.newInputStream(Path.of(push.credentialsPath()));
    }

    private static boolean preenchido(String valor) {
        return valor != null && !valor.isBlank();
    }
}
