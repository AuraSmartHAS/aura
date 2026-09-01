package br.com.fiap.aura.web;

import br.com.fiap.aura.security.CurrentUser;
import br.com.fiap.aura.service.ReplenishmentService;
import br.com.fiap.aura.web.dto.ReplenishmentDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import java.util.UUID;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(value = "/api/v1/homes/{homeId}/replenishment", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "5.1 Reposição", description = "Projeção de reposição por consumo confirmado — régua aritmética declarada; a decisão continua humana")
public class ReplenishmentController {

    private final ReplenishmentService replenishment;
    private final CurrentUser currentUser;

    public ReplenishmentController(ReplenishmentService replenishment, CurrentUser currentUser) {
        this.replenishment = replenishment;
        this.currentUser = currentUser;
    }

    @PostMapping("/check")
    @Operation(summary = "Projeta o estoque de cada medicação contra o consumo confirmado e a régua da cadeia")
    public List<ReplenishmentDtos.Projection> check(@PathVariable UUID homeId) {
        return replenishment.check(currentUser.require(), homeId);
    }
}
