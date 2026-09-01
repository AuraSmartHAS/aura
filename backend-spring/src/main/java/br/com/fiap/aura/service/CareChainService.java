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
import br.com.fiap.aura.repository.MedicationRepository;
import br.com.fiap.aura.repository.ProductRepository;
import br.com.fiap.aura.repository.RecommendationRepository;
import br.com.fiap.aura.repository.ScoreRepository;
import br.com.fiap.aura.repository.StockNodeRepository;
import br.com.fiap.aura.security.AuthPrincipal;
import br.com.fiap.aura.web.dto.CareChainDtos;
import br.com.fiap.aura.web.error.ApiException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
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
    private final MedicationRepository medications;
    private final HomeService homeService;
    private final AuthService auth;
    private final GeoService geo;
    private final GuardrailService guardrails;
    private final ScoringService scoring;
    private final AuraProperties props;

    public CareChainService(RecommendationRepository recommendations, DeliveryOrderRepository orders,
                            ProductRepository products, ScoreRepository scores, StockNodeRepository nodes,
                            MedicationRepository medications,
                            HomeService homeService, AuthService auth, GeoService geo,
                            GuardrailService guardrails, ScoringService scoring, AuraProperties props) {
        this.recommendations = recommendations;
        this.orders = orders;
        this.products = products;
        this.scores = scores;
        this.nodes = nodes;
        this.medications = medications;
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

        String reason = guardrails.assertNonPrescriptive(reason(product, scoring.labelsOf(factors)));

        Recommendation rec = recommendations.save(Recommendation.builder()
                .homeId(req.homeId()).scoreId(req.scoreId()).sku(product.getSku())
                .reason(reason).status("recommended").factors(factors).weights(weights)
                .build());

        return toResponse(rec, product);
    }

    /**
     * Sem escore não há fatores, e a frase composta não tem do que ser composta: cai na
     * versão curta em vez de sair com um "porque houve ." no meio.
     */
    private String reason(Product product, List<String> labels) {
        String norm = product.getNormRef() == null ? "NBR 9050" : product.getNormRef();
        return labels.isEmpty()
                ? "%s reduz risco de queda/acidente (%s).".formatted(product.getName(), norm)
                : "Recomendamos %s porque houve %s (%s).".formatted(product.getName(), enumerate(labels), norm);
    }

    /** "a", "a e b", "a, b e c" — o que uma pessoa lê, não o que uma lista imprime. */
    private static String enumerate(List<String> parts) {
        if (parts.size() == 1) {
            return parts.get(0);
        }
        return String.join(", ", parts.subList(0, parts.size() - 1)) + " e " + parts.get(parts.size() - 1);
    }

    /**
     * Preço, instalação e norma viajam com a recomendação para que nenhuma tela precise de uma
     * segunda chamada ao catálogo que pode falhar — e ninguém aprove sem ver o total.
     * SKU fora do catálogo devolve os campos nulos; item não instalável não tem custo de instalação.
     */
    private CareChainDtos.RecommendationResponse toResponse(Recommendation rec, Product product) {
        boolean installable = product != null && product.isInstallable();
        boolean included = props.carechain().installationIncluded();
        return new CareChainDtos.RecommendationResponse(rec.getId(), rec.getSku(),
                product == null ? rec.getSku() : product.getName(), rec.getReason(), rec.getStatus(),
                rec.getFactors(), rec.getWeights(), scoring.labelsOf(rec.getFactors()),
                product == null ? null : product.getPrice(),
                product == null ? null : installable,
                installable ? included : null,
                installable ? money(included ? BigDecimal.ZERO : props.carechain().installationPrice()) : null,
                product == null ? null : product.getNormRef());
    }

    /** Duas casas como o preço do catálogo: os dois valores são somados na mesma linha da tela. */
    private static BigDecimal money(BigDecimal value) {
        return value == null ? null : value.setScale(2, RoundingMode.HALF_UP);
    }

    @Transactional(readOnly = true)
    public List<CareChainDtos.RecommendationResponse> listRecommendations(AuthPrincipal principal, UUID homeId) {
        homeService.requireAccess(principal, homeId);
        Map<String, Product> bySku = productIndex();
        return recommendations.findByHomeIdOrderByCreatedAtDesc(homeId).stream()
                .map(r -> toResponse(r, bySku.get(r.getSku())))
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
        return toResponse(rec, productIndex().get(rec.getSku()));
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
            case IN_ROUTE -> order.setEtaDelivery(
                    now.plus(props.carechain().routeWindowMinutes(), ChronoUnit.MINUTES));
            case DELIVERED -> {
                order.setDeliveredAt(now);
                order.setSlaBreached(order.getSlaDueAt() != null && now.isAfter(order.getSlaDueAt()));
                refillIfReplenishment(order);
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

    /**
     * A entrega da reposição devolve o pacote ao estoque da casa — o ciclo fecha nos dois
     * sentidos: desce com a voz da Maria, sobe com a cadeia. Pedido comum passa reto.
     */
    private void refillIfReplenishment(DeliveryOrder order) {
        if (order.getRecommendationId() == null) {
            return;
        }
        recommendations.findById(order.getRecommendationId())
                .filter(rec -> rec.getMedicationId() != null)
                .ifPresent(rec -> medications.findById(rec.getMedicationId()).ifPresent(med ->
                        med.setStockDoses((med.getStockDoses() == null ? 0 : med.getStockDoses())
                                + props.carechain().replenish().packageDoses())));
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

    /** O ponto nunca pousa na casa enquanto o status diz "em rota": fica "chegando". */
    static final double MAX_ROUTE_PROGRESS = 0.97;

    /**
     * Fração já percorrida da última milha, em [0, {@value #MAX_ROUTE_PROGRESS}]. A partida é o
     * despacho: {@code max(createdAt, eta − janela)} — pedido avançado ao vivo parte do instante do
     * advance; pedido do seed (criado horas atrás) parte de {@code eta − janela}. O relógio entra
     * por parâmetro para o teste ser determinístico, sem mock de {@code Instant.now()}.
     */
    static double routeProgress(Instant createdAt, Instant eta, Instant now, int windowMinutes) {
        Instant windowStart = eta.minus(windowMinutes, ChronoUnit.MINUTES);
        Instant departure = createdAt != null && createdAt.isAfter(windowStart) ? createdAt : windowStart;
        long spanMillis = Duration.between(departure, eta).toMillis();
        if (spanMillis <= 0) {
            return MAX_ROUTE_PROGRESS;
        }
        double fraction = Duration.between(departure, now).toMillis() / (double) spanMillis;
        return Math.clamp(fraction, 0d, MAX_ROUTE_PROGRESS);
    }

    /** Entrega com a rota e a duração simuladas do {@link GeoService} — ambas nulas sem coordenadas. */
    private CareChainDtos.DeliveryResponse delivery(DeliveryOrder order, Home home) {
        StockNode node = originNode(order, home);
        GeoService.SimulatedRoute route = node == null ? null
                : geo.simulateRoute(node.getLat(), node.getLng(), home.getLat(), home.getLng()).orElse(null);

        // posição derivada da ETA, calculada aqui: a tela nunca inventa onde o entregador está
        Integer progressPct = null;
        List<Double> currentPosition = null;
        if (order.getStage() == OrderStage.IN_ROUTE && order.getEtaDelivery() != null && route != null) {
            double progress = routeProgress(order.getCreatedAt(), order.getEtaDelivery(), Instant.now(),
                    props.carechain().routeWindowMinutes());
            progressPct = (int) Math.round(progress * 100);
            currentPosition = geo.positionAlong(route.coordinates(), progress);
        }

        return new CareChainDtos.DeliveryResponse(order.getNodeName(), order.getEtaDelivery(),
                order.getDistanceM(), order.getStage().value(),
                route == null ? null : route.durationS(),
                progressPct, currentPosition,
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
