package br.com.fiap.aura.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

/**
 * A regra 2 do C3, com relógio de verdade: <b>a contagem de cancelamento mora no servidor</b>.
 *
 * <p>É o único teste da suíte que espera tempo de parede, e o custo é justificado — sem ele, todo o
 * resto do SOS poderia passar verde com o cronômetro do servidor <b>desligado</b>. A suíte inteira
 * chamaria {@code dispatchIfDue} à mão, nada notaria a ausência do {@code @EnableScheduling}, e o
 * furo só apareceria na demonstração: a API responderia "aviso agendado para daqui a 5 segundos" e
 * o aviso nunca sairia.
 *
 * <p>Duas escolhas de configuração fazem este teste provar o que ele diz provar:
 * <ul>
 *   <li>{@code cancel-window-seconds} <b>não é sobrescrito</b> — vale o 5 de produção, então o teste
 *       também é a verificação de que a janela é de cinco segundos, não dez.</li>
 *   <li>{@code sweep-millis} vai a 10 minutos, o que na prática desliga o varredor de recuperação.
 *       Sem isso, o teste passaria mesmo que o agendamento pontual estivesse quebrado, porque a
 *       varredura cobriria por ele. Aqui só o cronômetro pode disparar.</li>
 * </ul>
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
@TestPropertySource(properties = {
        "aura.sos.min-interval-seconds=1",
        "aura.sos.sweep-millis=600000"
})
class EmergencySchedulerTest {

    /** Margem generosa sobre os 5s: a falha que interessa é "nunca dispara", não "demorou 6s". */
    private static final Duration LIMITE_DE_ESPERA = Duration.ofSeconds(20);

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper json;

    private JsonNode body(MvcResult res) throws Exception {
        return json.readTree(res.getResponse().getContentAsString(StandardCharsets.UTF_8));
    }

    @Test
    @DisplayName("o servidor dispara o aviso em T+5s sozinho, sem o cliente fazer mais nada")
    void oServidorDisparaSozinhoEmCincoSegundos() throws Exception {
        JsonNode conta = body(mvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"sos-timer@aura.com","password":"aura1234",
                                 "role":"cuidadora","name":"Ana"}"""))
                .andExpect(status().isCreated()).andReturn());
        String auth = "Bearer " + conta.get("token").asText();
        mvc.perform(post("/api/v1/consent").header("Authorization", auth)).andExpect(status().isCreated());

        String homeId = body(mvc.perform(post("/api/v1/homes").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"patientName":"Maria S.","cep":"01310100","label":"Casa da Maria"}"""))
                .andExpect(status().isCreated()).andReturn()).get("homeId").asText();

        mvc.perform(post("/api/v1/notifications/register-token").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"fcmToken":"token-do-aparelho-no-teste-do-cronometro"}"""))
                .andExpect(status().isOk());

        JsonNode sos = body(mvc.perform(post("/api/v1/emergencies")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"homeId":"%s","channel":"touch"}""".formatted(homeId)))
                .andExpect(status().isCreated()).andReturn());
        String emergencyId = sos.get("emergencyId").asText();

        // são CINCO segundos, não dez: a assimetria de dano é o argumento, e o número é o contrato
        assertThat(sos.get("cancelWindowSeconds").asInt()).isEqualTo(5);
        assertThat(sos.get("escalateAfterSeconds").asInt()).isEqualTo(60);
        assertThat(sos.get("state").asText()).isEqualTo("waiting_cancel");
        // e o instante do disparo é exatamente criação + janela, calculado pelo servidor
        assertThat(Instant.parse(sos.get("dispatchAt").asText()))
                .isEqualTo(Instant.parse(sos.get("createdAt").asText()).plusSeconds(5));

        // a partir daqui NENHUMA chamada do cliente: é o servidor que tem de agir sozinho, porque
        // o celular da Maria pode ter apagado a tela, ido a segundo plano ou caído no chão
        JsonNode estado = esperaEstado(emergencyId, "dispatched");

        assertThat(estado.get("dispatchedAt").isNull()).isFalse();
        assertThat(estado.get("notifiedCount").asInt()).isEqualTo(1);
        assertThat(Instant.parse(estado.get("dispatchedAt").asText()))
                .isAfterOrEqualTo(Instant.parse(sos.get("dispatchAt").asText()).minusSeconds(1));
    }

    /** Espera ativa pelo estado, sem tocar em nada da emergência — só leitura. */
    private JsonNode esperaEstado(String emergencyId, String esperado) throws Exception {
        Instant limite = Instant.now().plus(LIMITE_DE_ESPERA);
        JsonNode ultimo = null;
        while (Instant.now().isBefore(limite)) {
            ultimo = body(mvc.perform(get("/api/v1/emergencies/{id}", emergencyId))
                    .andExpect(status().isOk()).andReturn());
            if (esperado.equals(ultimo.get("state").asText())) {
                return ultimo;
            }
            Thread.sleep(200);
        }
        throw new AssertionError(
                "O servidor não disparou o aviso sozinho em %s — o cronômetro de T+5s não está ligado. "
                        + "Último estado lido: %s".formatted(LIMITE_DE_ESPERA, ultimo));
    }
}
