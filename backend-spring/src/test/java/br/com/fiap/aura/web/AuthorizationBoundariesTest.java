package br.com.fiap.aura.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.fiap.aura.domain.HomeMember;
import br.com.fiap.aura.domain.enums.HomeMemberRole;
import br.com.fiap.aura.domain.enums.Role;
import br.com.fiap.aura.repository.HomeMemberRepository;
import br.com.fiap.aura.repository.UserAccountRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
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

/** Regressões das fronteiras de privilégio decididas para a TASK-001. */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
class AuthorizationBoundariesTest {

    @Autowired private MockMvc mvc;
    @Autowired private ObjectMapper json;
    @Autowired private HomeMemberRepository members;
    @Autowired private UserAccountRepository users;

    private record Account(String auth, UUID userId) { }

    private JsonNode body(MvcResult res) throws Exception {
        return json.readTree(res.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8));
    }

    private Account signup(String email, String role) throws Exception {
        JsonNode response = body(mvc.perform(post("/api/v1/auth/signup")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"aura1234","role":"%s","name":"Teste"}"""
                                .formatted(email, role)))
                .andExpect(status().isCreated())
                .andReturn());
        return new Account("Bearer " + response.get("token").asText(),
                UUID.fromString(response.get("userId").asText()));
    }

    private String adminAuth() throws Exception {
        return login("admin@aura.com", "aura1234");
    }

    private String login(String email, String password) throws Exception {
        JsonNode response = body(mvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"%s\",\"password\":\"%s\"}".formatted(email, password)))
                .andExpect(status().isOk())
                .andReturn());
        return "Bearer " + response.get("token").asText();
    }

    private String homeOf(Account owner, String label) throws Exception {
        mvc.perform(post("/api/v1/consent").header("Authorization", owner.auth()))
                .andExpect(status().isCreated());
        return body(mvc.perform(post("/api/v1/homes").header("Authorization", owner.auth())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"patientName":"Maria S.","cep":"01310100","label":"%s"}""".formatted(label)))
                .andExpect(status().isCreated())
                .andReturn()).get("homeId").asText();
    }

    @Test
    @DisplayName("cadastro público preserva papéis legítimos, mas nunca cria ADMIN nem token administrativo")
    void publicSignupCannotCreateAdmin() throws Exception {
        for (String role : new String[] {"paciente", "cuidadora", "profissional"}) {
            mvc.perform(post("/api/v1/auth/signup").contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"email":"publico-%s@aura.com","password":"aura1234","role":"%s"}"""
                                    .formatted(role, role)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.role").value(role))
                    .andExpect(jsonPath("$.token").isNotEmpty());
        }

        mvc.perform(post("/api/v1/auth/signup").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"publico-admin@aura.com","password":"aura1234","role":"admin"}"""))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));

        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"publico-admin@aura.com","password":"aura1234"}"""))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    @DisplayName("somente ADMIN autenticado provisiona ADMIN e a resposta não inclui tokens")
    void adminProvisioningIsRestrictedAndDoesNotReturnTokens() throws Exception {
        String payload = """
                {"email":"novo-admin@aura.com","password":"aura1234","name":"Operação"}""";
        mvc.perform(post("/api/v1/auth/admins").contentType(MediaType.APPLICATION_JSON).content(payload))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));

        Account cuidadora = signup("provisionador-comum@aura.com", "cuidadora");
        mvc.perform(post("/api/v1/auth/admins").header("Authorization", cuidadora.auth())
                        .contentType(MediaType.APPLICATION_JSON).content(payload))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));

        mvc.perform(post("/api/v1/auth/admins").header("Authorization", adminAuth())
                        .contentType(MediaType.APPLICATION_JSON).content(payload))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.role").value("admin"))
                .andExpect(jsonPath("$.userId").isNotEmpty())
                .andExpect(jsonPath("$.token").doesNotExist())
                .andExpect(jsonPath("$.refreshToken").doesNotExist());
    }

    @Test
    @DisplayName("token de ADMIN excluído não conserva nenhuma operação privilegiada")
    void deletedAdminTokenCannotMutatePrivilegedResources() throws Exception {
        Account owner = signup("dona-admin-excluido-" + UUID.randomUUID() + "@aura.com", "cuidadora");
        String homeId = homeOf(owner, "Casa do token excluído");
        String medicationId = body(mvc.perform(post("/api/v1/homes/{id}/medications", homeId)
                        .header("Authorization", owner.auth()).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Levodopa\",\"schedule\":[\"08:00\"],\"stockDoses\":7}"))
                .andExpect(status().isCreated()).andReturn()).get("id").asText();
        String recommendationId = body(mvc.perform(post("/api/v1/recommendations")
                        .header("Authorization", owner.auth()).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"homeId\":\"%s\"}".formatted(homeId)))
                .andExpect(status().isCreated()).andReturn()).get("recommendationId").asText();
        String orderId = body(mvc.perform(post("/api/v1/recommendations/{id}/approve", recommendationId)
                        .header("Authorization", owner.auth()))
                .andExpect(status().isCreated()).andReturn()).get("orderId").asText();

        String email = "admin-excluido-" + UUID.randomUUID() + "@aura.com";
        mvc.perform(post("/api/v1/auth/admins").header("Authorization", adminAuth())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"%s\",\"password\":\"aura1234\"}".formatted(email)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.role").value("admin"));
        String deletedAdminToken = login(email, "aura1234");
        mvc.perform(delete("/api/v1/auth/me").header("Authorization", deletedAdminToken))
                .andExpect(status().isOk());

        String candidateEmail = "nao-criado-" + UUID.randomUUID() + "@aura.com";
        mvc.perform(post("/api/v1/auth/admins").header("Authorization", deletedAdminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"%s\",\"password\":\"aura1234\"}".formatted(candidateEmail)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
        mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"%s\",\"password\":\"aura1234\"}".formatted(candidateEmail)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("INVALID_CREDENTIALS"));
        mvc.perform(delete("/api/v1/homes/{id}", homeId).header("Authorization", deletedAdminToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));
        mvc.perform(post("/api/v1/orders/{id}/advance", orderId).header("Authorization", deletedAdminToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error.code").value("UNAUTHORIZED"));

        mvc.perform(get("/api/v1/homes/{id}", homeId).header("Authorization", owner.auth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.label").value("Casa do token excluído"));
        mvc.perform(get("/api/v1/orders/{id}", orderId).header("Authorization", owner.auth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stage").value("approved"));
        JsonNode medications = body(mvc.perform(get("/api/v1/homes/{id}/medications", homeId)
                        .header("Authorization", owner.auth())).andExpect(status().isOk()).andReturn());
        assertThat(medications.findValue("id").asText()).isEqualTo(medicationId);
        assertThat(medications.findValue("stockDoses").asInt()).isEqualTo(7);
    }

    @Test
    @DisplayName("papel vigente no banco substitui privilégio ADMIN gravado no token")
    void persistedRoleRevocationRemovesAdminPrivilegeFromExistingToken() throws Exception {
        String email = "admin-revogado-" + UUID.randomUUID() + "@aura.com";
        JsonNode response = body(mvc.perform(post("/api/v1/auth/admins").header("Authorization", adminAuth())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"%s\",\"password\":\"aura1234\"}".formatted(email)))
                .andExpect(status().isCreated()).andReturn());
        String token = login(email, "aura1234");
        UUID userId = UUID.fromString(response.get("userId").asText());
        var revoked = users.findById(userId).orElseThrow();
        revoked.setRole(Role.CUIDADORA);
        users.saveAndFlush(revoked);

        mvc.perform(post("/api/v1/auth/admins").header("Authorization", token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"bloqueado-" + UUID.randomUUID()
                                + "@aura.com\",\"password\":\"aura1234\"}"))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
    }

    @Test
    @DisplayName("somente dona ou ADMIN exclui casa; membro e estrangeira não apagam dados")
    void homeDeletionRequiresOwnerOrAdmin() throws Exception {
        Account owner = signup("dona-exclusao@aura.com", "cuidadora");
        String homeId = homeOf(owner, "Casa protegida");
        Account member = signup("membro-exclusao@aura.com", "paciente");
        Account stranger = signup("estranha-exclusao@aura.com", "cuidadora");
        members.save(HomeMember.builder().homeId(UUID.fromString(homeId)).userId(member.userId())
                .role(HomeMemberRole.PACIENTE).build());

        for (Account forbidden : new Account[] {member, stranger}) {
            mvc.perform(delete("/api/v1/homes/{id}", homeId).header("Authorization", forbidden.auth()))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
            mvc.perform(get("/api/v1/homes/{id}", homeId).header("Authorization", owner.auth()))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.label").value("Casa protegida"));
        }

        mvc.perform(delete("/api/v1/homes/{id}", homeId).header("Authorization", owner.auth()))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/homes/{id}", homeId).header("Authorization", owner.auth()))
                .andExpect(status().isNotFound());

        String adminHome = homeOf(owner, "Casa do admin");
        mvc.perform(delete("/api/v1/homes/{id}", adminHome).header("Authorization", adminAuth()))
                .andExpect(status().isOk());
        mvc.perform(get("/api/v1/homes/{id}", adminHome).header("Authorization", owner.auth()))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("somente ADMIN move logística; negativas preservam estágio, SLA e estoque")
    void logisticsAdvanceRequiresAdminWithoutMutatingOnDenial() throws Exception {
        Account owner = signup("dona-logistica@aura.com", "cuidadora");
        String homeId = homeOf(owner, "Casa logística");
        String medicationId = body(mvc.perform(post("/api/v1/homes/{id}/medications", homeId)
                        .header("Authorization", owner.auth()).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"Levodopa\",\"schedule\":[\"08:00\"],\"stockDoses\":7}"))
                .andExpect(status().isCreated()).andReturn()).get("id").asText();
        String recommendationId = body(mvc.perform(post("/api/v1/recommendations")
                        .header("Authorization", owner.auth()).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"homeId\":\"%s\"}".formatted(homeId)))
                .andExpect(status().isCreated()).andReturn()).get("recommendationId").asText();
        String orderId = body(mvc.perform(post("/api/v1/recommendations/{id}/approve", recommendationId)
                        .header("Authorization", owner.auth()))
                .andExpect(status().isCreated()).andReturn()).get("orderId").asText();
        JsonNode before = body(mvc.perform(get("/api/v1/orders/{id}", orderId).header("Authorization", owner.auth()))
                .andExpect(status().isOk()).andReturn());

        Account patient = signup("paciente-logistica@aura.com", "paciente");
        Account familyMember = signup("familiar-logistica@aura.com", "cuidadora");
        Account stranger = signup("estranha-logistica@aura.com", "profissional");
        members.save(HomeMember.builder().homeId(UUID.fromString(homeId)).userId(patient.userId())
                .role(HomeMemberRole.PACIENTE).build());
        members.save(HomeMember.builder().homeId(UUID.fromString(homeId)).userId(familyMember.userId())
                .role(HomeMemberRole.CUIDADORA).build());

        for (Account forbidden : new Account[] {owner, patient, familyMember, stranger}) {
            mvc.perform(post("/api/v1/orders/{id}/advance", orderId).header("Authorization", forbidden.auth()))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.error.code").value("FORBIDDEN"));
        }

        JsonNode unchanged = body(mvc.perform(get("/api/v1/orders/{id}", orderId).header("Authorization", owner.auth()))
                .andExpect(status().isOk()).andReturn());
        assertThat(unchanged.get("stage").asText()).isEqualTo(before.get("stage").asText());
        assertThat(unchanged.get("sla").get("dueAt").asText()).isEqualTo(before.get("sla").get("dueAt").asText());
        JsonNode medications = body(mvc.perform(get("/api/v1/homes/{id}/medications", homeId)
                        .header("Authorization", owner.auth())).andExpect(status().isOk()).andReturn());
        assertThat(medications.findValue("id").asText()).isEqualTo(medicationId);
        assertThat(medications.findValue("stockDoses").asInt()).isEqualTo(7);

        mvc.perform(post("/api/v1/orders/{id}/advance", orderId).header("Authorization", adminAuth()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.stage").value("sourcing"));
    }
}
