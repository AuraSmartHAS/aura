package br.com.fiap.aura.service;

import br.com.fiap.aura.config.AuraProperties;
import br.com.fiap.aura.domain.DeliveryOrder;
import br.com.fiap.aura.domain.Home;
import br.com.fiap.aura.domain.Product;
import br.com.fiap.aura.domain.Recommendation;
import br.com.fiap.aura.domain.Score;
import br.com.fiap.aura.domain.StockNode;
import br.com.fiap.aura.domain.enums.OrderStage;
import br.com.fiap.aura.repository.DeliveryOrderRepository;
import br.com.fiap.aura.repository.ProductRepository;
import br.com.fiap.aura.repository.RecommendationRepository;
import br.com.fiap.aura.repository.ScoreRepository;
import br.com.fiap.aura.repository.StockNodeRepository;
import br.com.fiap.aura.security.AuthPrincipal;
import br.com.fiap.aura.web.dto.CareChainDtos;
import br.com.fiap.aura.web.error.ApiException;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Care-Chain: da recomendação explicada ao pedido instalado.
 * Estados: approved → sourcing → in_route → delivered → installed → returned.
 */
@Service
public class CareChainService {

    private final RecommendationRepository recommendations;
    private final DeliveryOrderRepository orders;
    private final ProductRepository products;
    private final ScoreRepository scores;
    private final StockNodeRepository nodes;
    private final HomeService homeService;
    private final AuthService auth;
    private final GeoService geo;
    private final GuardrailService guardrails;
    private final ScoringService scoring;
    private final AuraProperties props;

    public CareChainService(RecommendationRepository recommendations, DeliveryOrderRepository orders,
                            ProductRepository products, ScoreRepository scores, StockNodeRepository nodes,
                            HomeService homeService, AuthService auth, GeoService geo,
                            GuardrailService guardrails, ScoringService scoring, AuraProperties props) {
        this.recommendations = recommendations;
        this.orders = orders;
        this.products = products;
        this.scores = scores;
        this.nodes = nodes;
        this.homeService = homeService;
        this.auth = auth;
        this.geo = geo;
        this.guardrails = guardrails;
        this.scoring = scoring;
        this.props = props;
    }

    @Transactional
    public CareChainDtos.RecommendationResponse recommend(AuthPrincipal principal,
                                                          CareChainDtos.CreateRecommendationRequest req) {
        auth.requireConsent(principal);
        homeService.requireAccess(principal, req.homeId());

        List<String> factors = new ArrayList<>();
        List<Double> weights = new ArrayList<>();
        String riskTag = "fall_bathroom";

        if (req.scoreId() != null) {
            Score score = scores.findById(req.scoreId()).orElseThrow(() -> ApiException.notFound("Escore"));
            if (!score.getHomeId().equals(req.homeId())) {
                throw ApiException.unprocessable("SCORE_HOME_MISMATCH", "Escore não pertence a esta casa.");
            }
            factors = score.getFactors();
            weights = score.getWeights();
            riskTag = scoring.riskTagOf(score.getDimension());
        }

        final String tag = riskTag;
        Product product = products.findFirstByRiskTagOrderByInstallableDescPriceDesc(tag)
                .orElseThrow(() -> ApiException.unprocessable("NO_PRODUCT",
                        "Sem produto no catálogo para o risco '" + tag + "'."));

        String reason = guardrails.assertNonPrescriptive(
                "%s reduz risco de queda/acidente (%s).".formatted(product.getName(),
                        product.getNormRef() == null ? "NBR 9050" : product.getNormRef()));

        Recommendation rec = recommendations.save(Recommendation.builder()
                .homeId(req.homeId()).scoreId(req.scoreId()).sku(product.getSku())
                .reason(reason).status("recommended").factors(factors).weights(weights)
                .build());

        return new CareChainDtos.RecommendationResponse(rec.getId(), product.getSku(), product.getName(),
                reason, rec.getStatus(), factors, weights);
    }

    @Transactional(readOnly = true)
    public List<CareChainDtos.RecommendationResponse> listRecommendations(AuthPrincipal principal, UUID homeId) {
        homeService.requireAccess(principal, homeId);
        Map<String, Product> bySku = productIndex();
        return recommendations.findByHomeIdOrderByCreatedAtDesc(homeId).stream()
                .map(r -> new CareChainDtos.RecommendationResponse(r.getId(), r.getSku(),
                        nameOf(bySku, r.getSku()), r.getReason(), r.getStatus(), r.getFactors(), r.getWeights()))
                .toList();
    }

    /** RN-022: o pedido só nasce da aprovação humana da cuidadora. */
    @Transactional
    public CareChainDtos.ApproveResponse approve(AuthPrincipal principal, UUID recommendationId) {
        Recommendation rec = recommendations.findById(recommendationId)
                .orElseThrow(() -> ApiException.notFound("Recomendação"));
        Home home = homeService.requireAccess(principal, rec.getHomeId());

        if ("approved".equals(rec.getStatus())) {
            throw ApiException.conflict("Recomendação já aprovada.");
        }
        if ("rejected".equals(rec.getStatus())) {
            throw ApiException.unprocessable("APPROVAL_REQUIRED", "Recomendação rejeitada não vira pedido.");
        }
        rec.setStatus("approved");

        StockNode node = geo.nearestNode(nodes.findAll(), home.getLat(), home.getLng()).orElse(null);
        Integer distance = (node == null || home.getLat() == null) ? null
                : (int) Math.round(geo.haversineMeters(home.getLat(), home.getLng(), node.getLat(), node.getLng()));

        DeliveryOrder order = orders.save(DeliveryOrder.builder()
                .homeId(rec.getHomeId())
                .recommendationId(rec.getId())
                .sku(rec.getSku())
                .stage(OrderStage.APPROVED)
                .nodeName(node == null ? null : node.getName())
                .distanceM(distance)
                .slaDueAt(Instant.now().plus(props.carechain().deliverySlaHours(), ChronoUnit.HOURS))
                .build());

        return new CareChainDtos.ApproveResponse(order.getId(), order.getStage());
    }

    @Transactional
    public CareChainDtos.RecommendationResponse reject(AuthPrincipal principal, UUID recommendationId) {
        Recommendation rec = recommendations.findById(recommendationId)
                .orElseThrow(() -> ApiException.notFound("Recomendação"));
        homeService.requireAccess(principal, rec.getHomeId());
        if ("approved".equals(rec.getStatus())) {
            throw ApiException.conflict("Recomendação já aprovada não pode ser rejeitada.");
        }
        rec.setStatus("rejected");
        return new CareChainDtos.RecommendationResponse(rec.getId(), rec.getSku(),
                nameOf(productIndex(), rec.getSku()), rec.getReason(), rec.getStatus(),
                rec.getFactors(), rec.getWeights());
    }

    @Transactional
    public CareChainDtos.AdvanceResponse advance(AuthPrincipal principal, UUID orderId) {
        DeliveryOrder order = requireOrder(principal, orderId);
        OrderStage next = order.getStage().next();
        if (next == null) {
            throw ApiException.conflict("Pedido em estágio terminal.");
        }
        Instant now = Instant.now();
        order.setStage(next);

        switch (next) {
            case IN_ROUTE -> order.setEtaDelivery(now.plus(4, ChronoUnit.HOURS));
            case DELIVERED -> {
                order.setDeliveredAt(now);
                order.setSlaBreached(order.getSlaDueAt() != null && now.isAfter(order.getSlaDueAt()));
            }
            case INSTALLED -> {
                order.setInstalledAt(now);
                order.setInstallAt(now);
            }
            default -> { }
        }
        return new CareChainDtos.AdvanceResponse(order.getStage(), order.getEtaDelivery(),
                order.getInstallAt(), order.isSlaBreached());
    }

    @Transactional(readOnly = true)
    public CareChainDtos.OrderDetailResponse detail(AuthPrincipal principal, UUID orderId) {
        DeliveryOrder order = orders.findById(orderId).orElseThrow(() -> ApiException.notFound("Pedido"));
        Home home = homeService.requireAccess(principal, order.getHomeId());

        return new CareChainDtos.OrderDetailResponse(order.getId(), order.getStage(), order.getSku(),
                nameOf(productIndex(), order.getSku()),
                new CareChainDtos.SlaResponse(order.getSlaDueAt(), order.isSlaBreached(),
                        order.getDeliveredAt(), order.getInstalledAt()),
                delivery(order, home),
                order.getCreatedAt());
    }

    /** Entrega com a rota e a duração simuladas do {@link GeoService} — ambas nulas sem coordenadas. */
    private CareChainDtos.DeliveryResponse delivery(DeliveryOrder order, Home home) {
        StockNode node = originNode(order, home);
        GeoService.SimulatedRoute route = node == null ? null
                : geo.simulateRoute(node.getLat(), node.getLng(), home.getLat(), home.getLng()).orElse(null);

        return new CareChainDtos.DeliveryResponse(order.getNodeName(), order.getEtaDelivery(),
                order.getDistanceM(), order.getStage().value(),
                route == null ? null : route.durationS(),
                route == null ? null : new CareChainDtos.RouteResponse("LineString", route.coordinates()));
    }

    /** Nó que despachou o pedido: o nome gravado na aprovação; sem ele, o mais próximo hoje. */
    private StockNode originNode(DeliveryOrder order, Home home) {
        List<StockNode> all = nodes.findAll();
        return all.stream()
                .filter(n -> n.getName() != null && n.getName().equals(order.getNodeName()))
                .findFirst()
                .orElseGet(() -> geo.nearestNode(all, home.getLat(), home.getLng()).orElse(null));
    }

    @Transactional(readOnly = true)
    public List<CareChainDtos.OrderSummaryResponse> listOrders(AuthPrincipal principal, UUID homeId) {
        homeService.requireAccess(principal, homeId);
        Map<String, Product> index = productIndex();
        return orders.findByHomeIdOrderByCreatedAtDesc(homeId).stream()
                .map(o -> new CareChainDtos.OrderSummaryResponse(o.getId(), o.getStage(), o.getSku(),
                        nameOf(index, o.getSku()), o.getSlaDueAt(), o.isSlaBreached(), o.getCreatedAt(),
                        o.getRecommendationId()))
                .toList();
    }

    private DeliveryOrder requireOrder(AuthPrincipal principal, UUID orderId) {
        DeliveryOrder order = orders.findById(orderId).orElseThrow(() -> ApiException.notFound("Pedido"));
        homeService.requireAccess(principal, order.getHomeId());
        return order;
    }

    private Map<String, Product> productIndex() {
        return products.findAll().stream().collect(Collectors.toMap(Product::getSku, Function.identity()));
    }

    private String nameOf(Map<String, Product> index, String sku) {
        Product product = index.get(sku);
        return product == null ? sku : product.getName();
    }
}
