package br.com.fiap.aura.web;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import br.com.fiap.aura.domain.Home;
import br.com.fiap.aura.repository.HomeRepository;
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

/**
 * As rotas da inteligência fora do Oracle (H2, a suíte padrão): respondem "indisponível" com 200,
 * nunca 500, e continuam aplicando as mesmas fronteiras de acesso das outras rotas.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
class IntelligenceUnavailableTest {

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired HomeRepository homes;

    private String login(String email) throws Exception {
        String body = mvc.perform(post("/api/v1/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"%s","password":"aura1234"}""".formatted(email)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return "Bearer " + json.readTree(body).get("token").asText();
    }

    private UUID casa(String paciente) {
        return homes.findAll().stream().filter(h -> paciente.equals(h.getPatientName()))
                .map(Home::getId).findFirst().orElseThrow();
    }

    @Test
    @DisplayName("Sem Oracle, avisos e relatório respondem 200 com engine indisponível e listas vazias")
    void respondeIndisponivelSemErro() throws Exception {
        String ana = login("ana@aura.com");
        UUID maria = casa("Maria S.");

        mvc.perform(get("/api/v1/homes/{id}/alertas", maria).header("Authorization", ana))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.engine").value("indisponivel"))
                .andExpect(jsonPath("$.alertas.length()").value(0));
        mvc.perform(post("/api/v1/homes/{id}/alertas/processar", maria).header("Authorization", ana))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.novos").value(0));
        mvc.perform(get("/api/v1/homes/{id}/relatorio-consumo", maria).header("Authorization", ana))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.engine").value("indisponivel"))
                .andExpect(jsonPath("$.totalDoses").doesNotExist())
                .andExpect(jsonPath("$.de").exists())
                .andExpect(jsonPath("$.itens.length()").value(0));
    }

    @Test
    @DisplayName("Avisos e relatório de uma casa alheia dão 403, como qualquer outra rota da casa")
    void casaAlheiaDa403() throws Exception {
        String carlos = login("carlos@aura.com");
        UUID maria = casa("Maria S.");

        mvc.perform(get("/api/v1/homes/{id}/alertas", maria).header("Authorization", carlos))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/homes/{id}/relatorio-consumo", maria).header("Authorization", carlos))
                .andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/homes/{id}/alertas/processar", maria).header("Authorization", carlos))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Indicadores consolidados são da Operação: só admin")
    void indicadoresSoAdmin() throws Exception {
        mvc.perform(get("/api/v1/ops/indicadores").header("Authorization", login("ana@aura.com")))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/ops/indicadores").header("Authorization", login("admin@aura.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.engine").value("indisponivel"))
                .andExpect(jsonPath("$.casas.length()").value(0));
        mvc.perform(post("/api/v1/ops/indicadores/consolidar").header("Authorization", login("admin@aura.com")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.casasProcessadas").value(0));
    }

    @Test
    @DisplayName("Marcar como visto um aviso que não existe é 404")
    void avisoInexistente() throws Exception {
        mvc.perform(post("/api/v1/alertas/{id}/visto", UUID.randomUUID()).header("Authorization", login("ana@aura.com")))
                .andExpect(status().isNotFound());
    }
}
