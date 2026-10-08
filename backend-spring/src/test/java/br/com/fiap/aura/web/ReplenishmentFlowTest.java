package br.com.fiap.aura.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.fiap.aura.domain.Recommendation;
import br.com.fiap.aura.domain.Signal;
import br.com.fiap.aura.domain.enums.SignalSource;
import br.com.fiap.aura.domain.enums.SignalType;
import br.com.fiap.aura.repository.RecommendationRepository;
import br.com.fiap.aura.repository.SignalRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

/**
 * Reposição por consumo: o burn rate é média simples sobre confirmações da janela, a régua
 * compara dias de estoque com lead time + margem, e nada disso cria pedido sozinho (RN-022).
 * Sinais são plantados direto no repositório porque o confirm da API não retrodata — o mesmo
 * precedente do EmergencySchedulerTest.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
class ReplenishmentFlowTest {

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper json;

    @Autowired
    private SignalRepository signals;

    @Autowired
    private RecommendationRepository recommendations;

    private String signup(String email) throws Exception {
        MvcResult res = mvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"aura1234","role":"cuidadora"}""".formatted(email)))
                .andExpect(status().isCreated())
                .andReturn();
        return "Bearer " + json.readTree(res.getResponse().getContentAsString()).get("token").asText();
    }

    private JsonNode body(MvcResult res) throws Exception {
        return json.readTree(res.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8));
    }

    private String adminAuth() throws Exception {
        MvcResult res = mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"admin@aura.com\",\"password\":\"aura1234\"}"))
                .andExpect(status().isOk())
                .andReturn();
        return "Bearer " + body(res).get("token").asText();
    }

    /** Cuidadora consentida com casa — o chão de todo cenário. */
    private String[] cuidadoraComCasa(String email) throws Exception {
        String auth = signup(email);
        mvc.perform(post("/api/v1/consent").header("Authorization", auth)).andExpect(status().isCreated());
        String homeId = body(mvc.perform(post("/api/v1/homes").header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"patientName":"Maria S.","cep":"01310100","label":"Casa da Maria"}"""))
                .andExpect(status().isCreated())
                .andReturn()).get("homeId").asText();
        return new String[] {auth, homeId};
    }

    private String medicacao(String auth, String homeId, String nome, Integer stockDoses) throws Exception {
        String estoque = stockDoses == null ? "" : ",\"stockDoses\":%d".formatted(stockDoses);
        return body(mvc.perform(post("/api/v1/homes/{homeId}/medications", homeId)
                        .header("Authorization", auth)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"%s","schedule":["08:00","20:00"]%s}""".formatted(nome, estoque)))
                .andExpect(status().isCreated())
                .andReturn()).get("id").asText();
    }

    /** Planta {@code porDia} confirmações por dia nos últimos {@code dias} dias, retrodatadas. */
    private void plantaConsumo(String homeId, String medId, int dias, int porDia, boolean taken) {
        for (int d = dias; d >= 1; d--) {
            for (int i = 0; i < porDia; i++) {
                Map<String, Object> value = new LinkedHashMap<>();
                value.put("medicationId", medId);
                value.put("taken", taken);
                signals.save(Signal.builder()
                        .homeId(UUID.fromString(homeId))
                        .type(SignalType.ADHERENCE)
                        .source(SignalSource.SELF_REPORT)
                        .value(value)
                        .capturedAt(Instant.now().minus(d, ChronoUnit.DAYS).plus(i, ChronoUnit.HOURS))
                        .build());
            }
        }
    }

    private JsonNode check(String auth, String homeId) throws Exception {
        return body(mvc.perform(post("/api/v1/homes/{homeId}/replenishment/check", homeId)
                        .header("Authorization", auth))
                .andExpect(status().isOk())
                .andReturn());
    }

    @Test
    @DisplayName("estoque apertado dispara a régua, com a conta aberta e a frase no guardrail")
    void reguaDisparaComEstoqueApertado() throws Exception {
        String[] ana = cuidadoraComCasa("repo-regua@aura.com");
        String medId = medicacao(ana[0], ana[1], "Levodopa e Carbidopa", 8);

        // 2 confirmações/dia por 21 dias = 42 → média 2,0/dia; 8 doses ÷ 2,0 = 4,0 dias < 5,0
        plantaConsumo(ana[1], medId, 21, 2, true);

        JsonNode projecao = check(ana[0], ana[1]).get(0);
        assertThat(projecao.get("avgDosesPerDay").asDouble()).isEqualTo(2.0);
        assertThat(projecao.get("daysOfSupply").asDouble()).isEqualTo(4.0);
        assertThat(projecao.get("thresholdDays").asDouble()).isEqualTo(5.0);
        assertThat(projecao.get("suggested").asBoolean()).isTrue();

        String reason = projecao.get("reason").asText();
        assertThat(reason).contains("Reposição sugerida", "cerca de 4 dias", "24 h");
        // texto fala de estoque e prazo — nunca de saúde
        assertThat(reason.toLowerCase()).doesNotContain("tratamento", "tomar", "posologia");
    }

    @Test
    @DisplayName("o refil sugerido é o do medicamento que está acabando, nunca o de outro")
    void refilCasaComOPrincipioAtivo() throws Exception {
        String[] ana = cuidadoraComCasa("repo-principio@aura.com");

        // O catálogo tem refil de Levodopa, Pramipexol e Losartana. Antes de existir mais de um,
        // a busca era só pelo riskTag e devolvia o primeiro da ordenação — o que, com três,
        // sugeriria o remédio errado. Recomendar reposição do medicamento errado é dano, não erro
        // cosmético, então isto é regressão e não teste de conveniência.
        String pramipexol = medicacao(ana[0], ana[1], "Pramipexol", 8);
        plantaConsumo(ana[1], pramipexol, 21, 2, true);

        String recId = check(ana[0], ana[1]).get(0).get("recommendationId").asText();
        assertThat(recId).isNotEqualTo("null");

        JsonNode recomendacoes = body(mvc.perform(get("/api/v1/homes/{id}/recommendations", ana[1])
                        .header("Authorization", ana[0]))
                .andExpect(status().isOk())
                .andReturn());
        String sku = null;
        for (JsonNode r : recomendacoes) {
            if (recId.equals(r.get("recommendationId").asText())) {
                sku = r.get("sku").asText();
            }
        }
        assertThat(sku).isEqualTo("PARC-REPO-PRAMIPEXOL");
    }

    @Test
    @DisplayName("sem refil do princípio ativo no catálogo, projeta e não materializa — não empurra outro remédio")
    void semRefilCorrespondenteNaoMaterializa() throws Exception {
        String[] ana = cuidadoraComCasa("repo-sem-refil@aura.com");

        // Princípio ativo que não tem refil de parceiro cadastrado. A projeção continua aparecendo
        // para a cuidadora; o que não pode acontecer é virar pedido de um remédio diferente.
        String medId = medicacao(ana[0], ana[1], "Rivastigmina", 8);
        plantaConsumo(ana[1], medId, 21, 2, true);

        JsonNode projecao = check(ana[0], ana[1]).get(0);
        assertThat(projecao.get("suggested").asBoolean()).isTrue();
        assertThat(projecao.get("recommendationId").isNull()
                || "null".equals(projecao.get("recommendationId").asText())).isTrue();
    }

    @Test
    @DisplayName("a reposição entra na MESMA esteira: dedupe, aprovação humana, SLA e refil na entrega")
    void reposicaoNaMesmaEsteira() throws Exception {
        String[] ana = cuidadoraComCasa("repo-esteira@aura.com");
        String medId = medicacao(ana[0], ana[1], "Levodopa e Carbidopa", 8);
        plantaConsumo(ana[1], medId, 21, 2, true);

        String recId = check(ana[0], ana[1]).get(0).get("recommendationId").asText();
        assertThat(recId).isNotEqualTo("null");

        // dedupe: um segundo check reusa a recomendação aberta em vez de criar outra
        assertThat(check(ana[0], ana[1]).get(0).get("recommendationId").asText()).isEqualTo(recId);

        // RN-022: a régua sugere, mas só a aprovação humana cria o pedido
        String orderId = body(mvc.perform(post("/api/v1/recommendations/{id}/approve", recId)
                        .header("Authorization", ana[0]))
                .andExpect(status().isCreated())
                .andReturn()).get("orderId").asText();

        JsonNode pedido = body(mvc.perform(get("/api/v1/homes/{id}/orders", ana[1])
                        .header("Authorization", ana[0]))
                .andExpect(status().isOk())
                .andReturn()).get(0);
        assertThat(pedido.get("productName").asText()).contains("refil");
        assertThat(pedido.get("slaDueAt").isNull()).isFalse();

        // approved → sourcing → in_route → delivered: a entrega devolve o pacote (8 + 30 = 38)
        String admin = adminAuth();
        for (int i = 0; i < 3; i++) {
            mvc.perform(post("/api/v1/orders/{id}/advance", orderId).header("Authorization", admin))
                    .andExpect(status().isOk());
        }
        JsonNode medicaoes = body(mvc.perform(get("/api/v1/homes/{id}/medications", ana[1])
                        .header("Authorization", ana[0]))
                .andExpect(status().isOk())
                .andReturn());
        assertThat(medicaoes.get(0).get("stockDoses").asInt()).isEqualTo(38);
    }

    @Test
    @DisplayName("reposição recusada não vira pedido e adia a sugestão: o check seguinte não recria")
    void reposicaoRecusadaNaoViraPedido() throws Exception {
        String[] ana = cuidadoraComCasa("repo-recusa@aura.com");
        String medId = medicacao(ana[0], ana[1], "Levodopa e Carbidopa", 8);
        plantaConsumo(ana[1], medId, 21, 2, true);

        JsonNode sugerida = check(ana[0], ana[1]).get(0);
        assertThat(sugerida.get("snoozedUntil").isNull()).isTrue();
        String recId = sugerida.get("recommendationId").asText();
        Instant antesDaRecusa = Instant.now();
        mvc.perform(post("/api/v1/recommendations/{id}/reject", recId).header("Authorization", ana[0]))
                .andExpect(status().isOk());

        JsonNode pedidos = body(mvc.perform(get("/api/v1/homes/{id}/orders", ana[1])
                        .header("Authorization", ana[0]))
                .andExpect(status().isOk())
                .andReturn());
        assertThat(pedidos.size()).isZero();

        // "deixar para depois": a régua continua disparando, mas a sugestão fica calada pelo prazo
        // configurado (24 h), sem materializar outra recomendação a cada recarga da tela
        JsonNode adiada = check(ana[0], ana[1]).get(0);
        assertThat(adiada.get("suggested").asBoolean()).isFalse();
        assertThat(adiada.get("recommendationId").isNull()).isTrue();
        assertThat(adiada.get("reason").isNull()).isTrue();
        Instant ate = Instant.parse(adiada.get("snoozedUntil").asText());
        assertThat(ate).isBetween(antesDaRecusa.plus(24, ChronoUnit.HOURS),
                Instant.now().plus(24, ChronoUnit.HOURS));
        check(ana[0], ana[1]);
        assertThat(recommendations.findByHomeIdAndMedicationId(UUID.fromString(ana[1]), UUID.fromString(medId)))
                .extracting(Recommendation::getStatus).containsExactly("rejected");

        // passado o prazo (a recusa retrodatada faz o papel do relógio), a régua volta a sugerir
        Recommendation recusada = recommendations.findById(UUID.fromString(recId)).orElseThrow();
        recusada.setCreatedAt(Instant.now().minus(25, ChronoUnit.HOURS));
        recommendations.save(recusada);

        JsonNode deNovo = check(ana[0], ana[1]).get(0);
        assertThat(deNovo.get("suggested").asBoolean()).isTrue();
        assertThat(deNovo.get("snoozedUntil").isNull()).isTrue();
        assertThat(deNovo.get("recommendationId").asText()).isNotEqualTo(recId).isNotEqualTo("null");
    }

    @Test
    @DisplayName("uma entrega de reposição depois da recusa encerra o adiamento antes do prazo")
    void entregaEncerraOAdiamento() throws Exception {
        String[] ana = cuidadoraComCasa("repo-recusa-entrega@aura.com");
        String medId = medicacao(ana[0], ana[1], "Levodopa e Carbidopa", 8);
        // 10/dia: mesmo com o pacote entregue (8 + 30 = 38 -> 3,8 dias) a régua segue disparando
        plantaConsumo(ana[1], medId, 21, 10, true);

        String recId = check(ana[0], ana[1]).get(0).get("recommendationId").asText();
        String sku = recommendations.findById(UUID.fromString(recId)).orElseThrow().getSku();
        mvc.perform(post("/api/v1/recommendations/{id}/reject", recId).header("Authorization", ana[0]))
                .andExpect(status().isOk());
        assertThat(check(ana[0], ana[1]).get(0).get("snoozedUntil").isNull()).isFalse();

        // pedido que veio por outra via (outro dispositivo) e é entregue durante o adiamento
        Recommendation outra = recommendations.save(Recommendation.builder()
                .homeId(UUID.fromString(ana[1])).medicationId(UUID.fromString(medId)).sku(sku)
                .reason("Pedido feito em outro dispositivo.").build());
        avanca(aprovaReposicao(ana[0], outra.getId().toString()), 3);

        JsonNode apos = check(ana[0], ana[1]).get(0);
        assertThat(apos.get("stockDoses").asInt()).isEqualTo(38);
        assertThat(apos.get("snoozedUntil").isNull()).isTrue();
        assertThat(apos.get("suggested").asBoolean()).isTrue();
    }

    @Test
    @DisplayName("a conta só vê a própria medicação: sinal alheio e dose negada ficam de fora")
    void contaIsolaMedicacaoETakenFalse() throws Exception {
        String[] ana = cuidadoraComCasa("repo-isolamento@aura.com");
        String levodopa = medicacao(ana[0], ana[1], "Levodopa e Carbidopa", 50);
        String vitamina = medicacao(ana[0], ana[1], "Vitamina D", 50);

        plantaConsumo(ana[1], levodopa, 21, 1, true);   // 21 confirmadas → 1,0/dia
        plantaConsumo(ana[1], levodopa, 21, 1, false);  // negadas não contam
        plantaConsumo(ana[1], vitamina, 21, 3, true);   // outra medicação não contamina

        JsonNode projecoes = check(ana[0], ana[1]);
        JsonNode daLevodopa = projecoes.get(0).get("medicationName").asText().startsWith("Levodopa")
                ? projecoes.get(0) : projecoes.get(1);
        assertThat(daLevodopa.get("avgDosesPerDay").asDouble()).isEqualTo(1.0);
        assertThat(daLevodopa.get("daysOfSupply").asDouble()).isEqualTo(50.0);
    }

    @Test
    @DisplayName("sem uma semana de história, nada se projeta — mesmo com estoque no fim")
    void semHistoriaNadaSeProjeta() throws Exception {
        String[] ana = cuidadoraComCasa("repo-historia@aura.com");
        String medId = medicacao(ana[0], ana[1], "Levodopa e Carbidopa", 2);

        plantaConsumo(ana[1], medId, 3, 7, true); // ritmo alto, mas só 3 dias de história

        JsonNode projecao = check(ana[0], ana[1]).get(0);
        assertThat(projecao.get("suggested").asBoolean()).isFalse();
        assertThat(projecao.get("reason").isNull()).isTrue();
    }

    @Test
    @DisplayName("estoque folgado não sugere, e medicação sem estoque controlado fica fora da lista")
    void estoqueFolgadoESemControle() throws Exception {
        String[] ana = cuidadoraComCasa("repo-folga@aura.com");
        String comEstoque = medicacao(ana[0], ana[1], "Levodopa e Carbidopa", 100);
        medicacao(ana[0], ana[1], "Losartana", null);

        plantaConsumo(ana[1], comEstoque, 21, 2, true); // 100 ÷ 2,0 = 50 dias de folga

        JsonNode projecoes = check(ana[0], ana[1]);
        assertThat(projecoes.size()).isEqualTo(1);
        assertThat(projecoes.get(0).get("suggested").asBoolean()).isFalse();
        assertThat(projecoes.get(0).get("daysOfSupply").asDouble()).isEqualTo(50.0);
    }

    private String aprovaReposicao(String auth, String recId) throws Exception {
        return body(mvc.perform(post("/api/v1/recommendations/{id}/approve", recId).header("Authorization", auth))
                .andExpect(status().isCreated())
                .andReturn()).get("orderId").asText();
    }

    private void avanca(String orderId, int vezes) throws Exception {
        String admin = adminAuth();
        for (int i = 0; i < vezes; i++) {
            mvc.perform(post("/api/v1/orders/{id}/advance", orderId).header("Authorization", admin))
                    .andExpect(status().isOk());
        }
    }

    @Test
    @DisplayName("com a reposição a caminho a régua não sugere de novo e expõe o pedido")
    void pedidoACaminhoSuspendeASugestao() throws Exception {
        String[] ana = cuidadoraComCasa("repo-andamento@aura.com");
        String medId = medicacao(ana[0], ana[1], "Levodopa e Carbidopa", 8);
        plantaConsumo(ana[1], medId, 21, 2, true);

        JsonNode antes = check(ana[0], ana[1]).get(0);
        assertThat(antes.get("suggested").asBoolean()).isTrue();
        assertThat(antes.get("orderInProgress").isNull()).isTrue();
        String orderId = aprovaReposicao(ana[0], antes.get("recommendationId").asText());

        // o estoque ainda é 8: sem a regra, o próximo check sugeriria o mesmo pacote outra vez
        JsonNode depois = check(ana[0], ana[1]).get(0);
        assertThat(depois.get("stockDoses").asInt()).isEqualTo(8);
        assertThat(depois.get("suggested").asBoolean()).isFalse();
        assertThat(depois.get("recommendationId").isNull()).isTrue();
        assertThat(depois.get("orderInProgress").get("orderId").asText()).isEqualTo(orderId);
        assertThat(depois.get("orderInProgress").get("stage").asText()).isEqualTo("approved");

        avanca(orderId, 2); // sourcing, in_route: continua a caminho
        JsonNode emRota = check(ana[0], ana[1]).get(0);
        assertThat(emRota.get("suggested").asBoolean()).isFalse();
        assertThat(emRota.get("orderInProgress").get("stage").asText()).isEqualTo("in_route");
    }

    @Test
    @DisplayName("entregue, o estoque sobe e a régua se resolve sozinha, sem pedido em andamento")
    void entregaDevolveAsDosesEEncerra() throws Exception {
        String[] ana = cuidadoraComCasa("repo-entrega@aura.com");
        String medId = medicacao(ana[0], ana[1], "Levodopa e Carbidopa", 8);
        plantaConsumo(ana[1], medId, 21, 2, true);
        String orderId = aprovaReposicao(ana[0], check(ana[0], ana[1]).get(0).get("recommendationId").asText());

        avanca(orderId, 3); // delivered: +30 doses

        JsonNode apos = check(ana[0], ana[1]).get(0);
        assertThat(apos.get("stockDoses").asInt()).isEqualTo(38);
        assertThat(apos.get("suggested").asBoolean()).isFalse();
        assertThat(apos.get("orderInProgress").isNull()).isTrue();
    }

    @Test
    @DisplayName("pendente que ficou para trás sai da lista e não vira segundo pedido")
    void pendenteObsoletaEhAposentada() throws Exception {
        String[] ana = cuidadoraComCasa("repo-obsoleta@aura.com");
        String medId = medicacao(ana[0], ana[1], "Levodopa e Carbidopa", 8);
        plantaConsumo(ana[1], medId, 21, 2, true);
        JsonNode sugerida = check(ana[0], ana[1]).get(0);
        String orderId = aprovaReposicao(ana[0], sugerida.get("recommendationId").asText());

        Recommendation velha = recommendations.save(Recommendation.builder()
                .homeId(UUID.fromString(ana[1])).medicationId(UUID.fromString(medId))
                .sku(recommendations.findById(UUID.fromString(sugerida.get("recommendationId").asText()))
                        .orElseThrow().getSku())
                .reason("Sugestão anterior ao pedido.").build());

        check(ana[0], ana[1]);

        assertThat(recommendations.findById(velha.getId()).orElseThrow().getStatus()).isEqualTo("superseded");
        mvc.perform(post("/api/v1/recommendations/{id}/approve", velha.getId()).header("Authorization", ana[0]))
                .andExpect(status().isConflict());
        assertThat(body(mvc.perform(get("/api/v1/homes/{id}/orders", ana[1]).header("Authorization", ana[0]))
                .andReturn())).hasSize(1);
        assertThat(orderId).isNotBlank();
    }
}
