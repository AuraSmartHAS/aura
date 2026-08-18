package br.com.fiap.aura.web;

import br.com.fiap.aura.security.CurrentUser;
import br.com.fiap.aura.service.CareChainService;
import br.com.fiap.aura.web.dto.CareChainDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(value = "/api/v1", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "5. Care-Chain", description = "Recomendação explicada, aprovação humana, pedido e entrega")
public class CareChainController {

    private final CareChainService careChain;
    private final CurrentUser currentUser;

    public CareChainController(CareChainService careChain, CurrentUser currentUser) {
        this.careChain = careChain;
        this.currentUser = currentUser;
    }

    @PostMapping("/recommendations")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Gera a recomendação explicada a partir do escore da casa")
    public CareChainDtos.RecommendationResponse recommend(
            @Valid @RequestBody CareChainDtos.CreateRecommendationRequest req) {
        return careChain.recommend(currentUser.require(), req);
    }

    @GetMapping("/homes/{homeId}/recommendations")
    @Operation(summary = "Recomendações da casa")
    public List<CareChainDtos.RecommendationResponse> listRecommendations(@PathVariable UUID homeId) {
        return careChain.listRecommendations(currentUser.require(), homeId);
    }

    @PostMapping("/recommendations/{recommendationId}/approve")
    @ResponseStatus(HttpStatus.CREATED)
    @Operation(summary = "Aprovação humana da cuidadora — única porta que cria o pedido")
    public CareChainDtos.ApproveResponse approve(@PathVariable UUID recommendationId) {
        return careChain.approve(currentUser.require(), recommendationId);
    }

    @PostMapping("/recommendations/{recommendationId}/reject")
    @Operation(summary = "Recusa a recomendação — nenhum pedido é criado")
    public CareChainDtos.RecommendationResponse reject(@PathVariable UUID recommendationId) {
        return careChain.reject(currentUser.require(), recommendationId);
    }

    @PostMapping("/orders/{orderId}/advance")
    @Operation(summary = "Avança o pedido: approved → sourcing → in_route → delivered → installed → returned")
    public CareChainDtos.AdvanceResponse advance(@PathVariable UUID orderId) {
        return careChain.advance(currentUser.require(), orderId);
    }

    @GetMapping("/orders/{orderId}")
    @Operation(summary = "Detalhe do pedido, com SLA e dados da entrega")
    public CareChainDtos.OrderDetailResponse detail(@PathVariable UUID orderId) {
        return careChain.detail(currentUser.require(), orderId);
    }

    @GetMapping("/homes/{homeId}/orders")
    @Operation(summary = "Pedidos da casa")
    public List<CareChainDtos.OrderSummaryResponse> list(@PathVariable UUID homeId) {
        return careChain.listOrders(currentUser.require(), homeId);
    }
}
