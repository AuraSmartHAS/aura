package br.com.fiap.aura.web;

import br.com.fiap.aura.security.CurrentUser;
import br.com.fiap.aura.service.HomeService;
import br.com.fiap.aura.service.LgpdService;
import br.com.fiap.aura.web.dto.AuthDtos;
import br.com.fiap.aura.web.dto.HomeDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(value = "/api/v1/homes", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "2. Casas", description = "Cadastro da casa do paciente e checklist de segurança")
public class HomeController {

    private final HomeService homes;
    private final LgpdService lgpd;
    private final CurrentUser currentUser;

    public HomeController(HomeService homes, LgpdService lgpd, CurrentUser currentUser) {
        this.homes = homes;
        this.lgpd = lgpd;
        this.currentUser = currentUser;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Cria a casa e resolve o endereço pelo CEP (ViaCEP)")
    public HomeDtos.HomeCreatedResponse create(@Valid @RequestBody HomeDtos.CreateHomeRequest req) {
        return homes.create(currentUser.require(), req);
    }

    @GetMapping
    @Operation(summary = "Lista as casas visíveis ao usuário autenticado")
    public List<HomeDtos.HomeResponse> list() {
        return homes.list(currentUser.require());
    }

    @GetMapping("/{homeId}")
    @Operation(summary = "Detalhe da casa, paciente e checklist de segurança")
    public HomeDtos.HomeResponse get(@PathVariable UUID homeId) {
        return homes.get(currentUser.require(), homeId);
    }

    @DeleteMapping("/{homeId}")
    @Operation(summary = "Exclui a casa e todos os dados observados nela (LGPD)")
    public AuthDtos.OkResponse delete(@PathVariable UUID homeId) {
        lgpd.deleteHome(currentUser.require(), homeId);
        return new AuthDtos.OkResponse(true);
    }

    @PutMapping("/{homeId}/checklist")
    @Operation(summary = "Atualiza o checklist de segurança (alimenta o escore)")
    public HomeDtos.ChecklistResponse checklist(@PathVariable UUID homeId,
                                                @Valid @RequestBody HomeDtos.ChecklistRequest req) {
        return homes.updateChecklist(currentUser.require(), homeId, req.items());
    }
}
