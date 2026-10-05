package br.com.fiap.aura.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.fiap.aura.domain.Emergency;
import br.com.fiap.aura.domain.Home;
import br.com.fiap.aura.domain.Medication;
import br.com.fiap.aura.domain.Product;
import br.com.fiap.aura.domain.Recommendation;
import br.com.fiap.aura.domain.enums.EmergencyChannel;
import br.com.fiap.aura.domain.enums.EmergencyState;
import br.com.fiap.aura.repository.EmergencyRepository;
import br.com.fiap.aura.repository.HomeRepository;
import br.com.fiap.aura.repository.MedicationRepository;
import br.com.fiap.aura.repository.ProductRepository;
import br.com.fiap.aura.repository.RecommendationRepository;
import br.com.fiap.aura.repository.UserAccountRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Os três caminhos de exclusão que uma chave estrangeira de verdade quebraria (Fase 6).
 *
 * <p>No H2 e no PostgreSQL não há FK, então nada falha — o registro só fica apontando para quem
 * não existe mais. No Oracle a FK existe e a mesma exclusão daria ORA-02292 (500 na API). A regra
 * mora no Java para valer igual nos três bancos; estes testes rodam na suíte padrão.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
class ReferentialIntegrityTest {

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired ProductRepository products;
    @Autowired RecommendationRepository recommendations;
    @Autowired MedicationRepository medications;
    @Autowired HomeRepository homes;
    @Autowired EmergencyRepository emergencies;
    @Autowired UserAccountRepository users;

    private String login(String email) throws Exception {
        String body = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"aura1234"}""".formatted(email)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return "Bearer " + json.readTree(body).get("token").asText();
    }

    private String signup(String email) throws Exception {
        String body = mvc.perform(post("/api/v1/auth/signup").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"aura1234","role":"paciente"}""".formatted(email)))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return "Bearer " + json.readTree(body).get("token").asText();
    }

    private Home casaDaMaria() {
        return homes.findAll().stream().filter(h -> "Maria S.".equals(h.getPatientName())).findFirst().orElseThrow();
    }

    @Test
    @DisplayName("Produto com histórico de recomendação não é excluído: 409, e o item continua no catálogo")
    void produtoComHistoricoNaoSome() throws Exception {
        String sku = "TESTE-FK-" + UUID.randomUUID();
        products.save(Product.builder().sku(sku).name("Barra de apoio teste").category("banheiro")
                .price(new BigDecimal("10.00")).stockNearby(1).build());
        recommendations.save(Recommendation.builder().homeId(casaDaMaria().getId()).sku(sku)
                .reason("Teste de integridade").status("approved").build());

        mvc.perform(delete("/api/v1/catalog/{sku}", sku).header("Authorization", login("admin@aura.com")))
                .andExpect(status().isConflict());
        assertThat(products.existsById(sku)).isTrue();
    }

    @Test
    @DisplayName("Produto sem histórico continua podendo ser excluído")
    void produtoSemHistoricoSai() throws Exception {
        String sku = "TESTE-LIVRE-" + UUID.randomUUID();
        products.save(Product.builder().sku(sku).name("Item sem uso").category("banheiro")
                .price(new BigDecimal("10.00")).stockNearby(1).build());

        mvc.perform(delete("/api/v1/catalog/{sku}", sku).header("Authorization", login("admin@aura.com")))
                .andExpect(status().isOk());
        assertThat(products.existsById(sku)).isFalse();
    }

    @Test
    @DisplayName("Excluir a medicação mantém a recomendação de refil, sem apontar para quem não existe")
    void medicacaoExcluidaSoltaARecomendacao() throws Exception {
        Home maria = casaDaMaria();
        Medication med = medications.save(Medication.builder().homeId(maria.getId()).name("Teste FK")
                .schedule(new java.util.ArrayList<>(List.of("08:00"))).active(true).build());
        String sku = products.findAll().get(0).getSku();
        Recommendation refil = recommendations.save(Recommendation.builder().homeId(maria.getId())
                .medicationId(med.getId()).sku(sku).reason("Refil de teste").build());

        mvc.perform(delete("/api/v1/medications/{id}", med.getId()).header("Authorization", login("ana@aura.com")))
                .andExpect(status().is2xxSuccessful());

        Recommendation depois = recommendations.findById(refil.getId()).orElseThrow();
        assertThat(depois.getMedicationId()).isNull();
    }

    @Test
    @DisplayName("Quem apaga a conta deixa o SOS da casa alheia intacto, só sem o próprio nome")
    void contaExcluidaSoltaOsRegistrosDeSos() throws Exception {
        String email = "paciente-fk-" + UUID.randomUUID() + "@aura.com";
        String auth = signup(email);
        UUID userId = users.findByEmailIgnoreCase(email).orElseThrow().getId();
        Emergency sos = emergencies.save(Emergency.builder().homeId(casaDaMaria().getId())
                .triggeredByUserId(userId).acknowledgedByUserId(userId)
                .channel(EmergencyChannel.TOUCH).state(EmergencyState.ACKNOWLEDGED)
                .dispatchDueAt(Instant.now()).acknowledgedAt(Instant.now()).build());

        mvc.perform(delete("/api/v1/auth/me").header("Authorization", auth)).andExpect(status().is2xxSuccessful());

        Emergency depois = emergencies.findById(sos.getId()).orElseThrow();
        assertThat(depois.getTriggeredByUserId()).isNull();
        assertThat(depois.getAcknowledgedByUserId()).isNull();
    }
}
