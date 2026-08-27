package br.com.fiap.aura.config;

import br.com.fiap.aura.domain.DeliveryOrder;
import br.com.fiap.aura.domain.Home;
import br.com.fiap.aura.domain.Medication;
import br.com.fiap.aura.domain.Product;
import br.com.fiap.aura.domain.Recommendation;
import br.com.fiap.aura.domain.Score;
import br.com.fiap.aura.domain.Signal;
import br.com.fiap.aura.domain.StockNode;
import br.com.fiap.aura.domain.UserAccount;
import br.com.fiap.aura.domain.enums.OrderStage;
import br.com.fiap.aura.domain.enums.RiskLevel;
import br.com.fiap.aura.domain.enums.Role;
import br.com.fiap.aura.domain.enums.SignalSource;
import br.com.fiap.aura.domain.enums.SignalType;
import br.com.fiap.aura.repository.ConsentRepository;
import br.com.fiap.aura.repository.DeliveryOrderRepository;
import br.com.fiap.aura.repository.HomeRepository;
import br.com.fiap.aura.repository.MedicationRepository;
import br.com.fiap.aura.repository.ProductRepository;
import br.com.fiap.aura.repository.RecommendationRepository;
import br.com.fiap.aura.repository.ScoreRepository;
import br.com.fiap.aura.repository.SignalRepository;
import br.com.fiap.aura.repository.StockNodeRepository;
import br.com.fiap.aura.repository.UserAccountRepository;
import br.com.fiap.aura.service.GeoService;
import br.com.fiap.aura.domain.Consent;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * Cenário de demonstração: catálogo NBR 9050, dois nós logísticos, a cuidadora Ana,
 * um admin e a casa da Maria já com risco de queda no banheiro — mais três semanas de
 * histórico (sinais, vitais de wearable e escores explicados) e uma carteira de pedidos
 * em estágios diferentes, para a Torre de Controle ter KPIs de verdade.
 * Só roda com {@code aura.seed.enabled=true} (perfil dev).
 */
@Component
@ConditionalOnProperty(name = "aura.seed.enabled", havingValue = "true")
public class DataSeeder implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(DataSeeder.class);
    private static final String DEMO_PASSWORD = "aura1234";
    private static final String NORM = "NBR 9050";

    /** Dias de histórico simulado — ver a restrição da janela do escore em {@link #seedHistory}. */
    private static final int HISTORY_DAYS = 21;

    private final ProductRepository products;
    private final StockNodeRepository nodes;
    private final UserAccountRepository users;
    private final ConsentRepository consents;
    private final HomeRepository homes;
    private final SignalRepository signals;
    private final MedicationRepository medications;
    private final ScoreRepository scores;
    private final RecommendationRepository recommendations;
    private final DeliveryOrderRepository orders;
    private final GeoService geo;
    private final AuraProperties props;
    private final PasswordEncoder encoder;

    public DataSeeder(ProductRepository products, StockNodeRepository nodes, UserAccountRepository users,
                      ConsentRepository consents, HomeRepository homes, SignalRepository signals,
                      MedicationRepository medications, ScoreRepository scores,
                      RecommendationRepository recommendations, DeliveryOrderRepository orders,
                      GeoService geo, AuraProperties props, PasswordEncoder encoder) {
        this.products = products;
        this.nodes = nodes;
        this.users = users;
        this.consents = consents;
        this.homes = homes;
        this.signals = signals;
        this.medications = medications;
        this.scores = scores;
        this.recommendations = recommendations;
        this.orders = orders;
        this.geo = geo;
        this.props = props;
        this.encoder = encoder;
    }

    @Override
    public void run(String... args) {
        if (products.count() > 0) {
            return;
        }

        products.saveAll(java.util.List.of(
                product("LM-1566953614", "Kit 2 Barras de Apoio 60cm", "Barra de apoio", "129.90", true, "fall_bathroom", 48),
                product("LM-ANTIDERRAP", "Piso Antiderrapante p/ Box (m²)", "Antiderrapante", "39.90", true, "fall_bathroom", 120),
                product("LM-CAD-BANHO", "Cadeira de Banho Regulável", "Cadeira de banho", "249.90", false, "mobility", 12),
                product("LM-LUZ-SENSOR", "Iluminação Noturna c/ Sensor", "Iluminação", "59.90", false, "night_trips", 64),
                product("LM-DET-GAS", "Detector de Gás e Fumaça", "Segurança", "89.90", true, "cognition", 30),
                product("LM-PURIF-AR", "Purificador de Ar Compacto", "Ambiente", "199.90", false, "environment", 18)));

        nodes.saveAll(java.util.List.of(
                StockNode.builder().name("Loja Marginal").type("loja").lat(-23.55).lng(-46.64).build(),
                StockNode.builder().name("CD Embu").type("cd").lat(-23.64).lng(-46.85).build()));

        UserAccount ana = users.save(UserAccount.builder()
                .email("ana@aura.com").passwordHash(encoder.encode(DEMO_PASSWORD))
                .role(Role.CUIDADORA).name("Ana (cuidadora)").build());
        users.save(UserAccount.builder()
                .email("admin@aura.com").passwordHash(encoder.encode(DEMO_PASSWORD))
                .role(Role.ADMIN).name("Torre de Controle").build());
        users.save(UserAccount.builder()
                .email("maria@aura.com").passwordHash(encoder.encode(DEMO_PASSWORD))
                .role(Role.PACIENTE).name("Maria (paciente)").build());

        consents.save(Consent.builder().userId(ana.getId()).version("2026-06").build());

        Map<String, Object> checklist = new LinkedHashMap<>();
        checklist.put("grab_bar_bathroom", false);   // falta a barra → fator de risco
        checklist.put("anti_slip_floor", false);     // sem piso anti-derrapante → fator de risco
        checklist.put("night_light", true);
        checklist.put("gas_detector", true);
        checklist.put("air_purifier", true);

        Home casa = homes.save(Home.builder()
                .ownerUserId(ana.getId()).patientName("Maria S.").birthDate(LocalDate.of(1952, 3, 10))
                .label("Casa da Maria").cep("01310100")
                .address("Av. Paulista, Bela Vista, São Paulo, SP")
                .lat(-23.561).lng(-46.656).safetyChecklist(checklist)
                .build());

        // remédios da Maria: horários em "HH:mm", nunca texto livre (é o que o app lê)
        Medication levodopa = medications.save(medicacao(casa, "Levodopa + Carbidopa", "250/25mg",
                java.util.List.of("06:00", "12:00", "18:00"), "tomar 1h antes das refeições"));
        medications.save(medicacao(casa, "Pramipexol", "0,25mg",
                java.util.List.of("08:00", "20:00"), null));
        medications.save(medicacao(casa, "Losartana", "50mg",
                java.util.List.of("08:00"), "pressão alta — acompanhamento do clínico"));

        signals.save(Signal.builder().homeId(casa.getId()).type(SignalType.MOBILITY)
                .source(SignalSource.VOICE).value(Map.of("event", "near_fall", "place", "bathroom")).build());
        signals.save(Signal.builder().homeId(casa.getId()).type(SignalType.ADHERENCE)
                .source(SignalSource.SELF_REPORT)
                .value(Map.of("medicationId", levodopa.getId().toString(), "taken", true)).build());

        Instant now = Instant.now();
        seedHistory(casa.getId(), now);
        seedWearableVitals(casa.getId(), now);
        seedScoreTrend(casa.getId(), now);
        seedOrderPipeline(casa, now);

        log.info("Seed pronto — login de demonstração: ana@aura.com / {} (casa {})", DEMO_PASSWORD, casa.getId());
    }

    /**
     * Os sinais que contam a história das últimas três semanas.
     * Restrição não óbvia: os eventos de <b>mobilidade</b> ficam todos fora da janela de
     * {@code aura.scoring.window-days} (14 dias), senão a tontura somaria 0,1 ao recálculo e o
     * fluxo-herói deixaria de fechar em 0,9 com os três fatores 0,4/0,3/0,2. Os eventos das outras
     * dimensões ficam dentro da janela de propósito: alimentam o painel 360 com sono, cognição e
     * ambiente em risco médio sem tocar no escore de mobilidade.
     */
    private void seedHistory(UUID homeId, Instant now) {
        observed(homeId, now, 21, SignalType.MOBILITY, SignalSource.VOICE,
                Map.of("event", "dizziness", "place", "bathroom"));
        observed(homeId, now, 19, SignalType.MOBILITY, SignalSource.SELF_REPORT,
                Map.of("event", "dizziness", "place", "bedroom"));
        observed(homeId, now, 17, SignalType.SLEEP, SignalSource.VOICE,
                Map.of("event", "night_trip", "times", 3));
        observed(homeId, now, 16, SignalType.MOBILITY, SignalSource.VOICE,
                Map.of("event", "dizziness", "place", "kitchen"));

        observed(homeId, now, 9, SignalType.ADHERENCE, SignalSource.SELF_REPORT, Map.of("taken", false));
        observed(homeId, now, 6, SignalType.COGNITION, SignalSource.VOICE,
                Map.of("event", "confusion", "context", "repeticao_na_fala"));
        observed(homeId, now, 5, SignalType.SLEEP, SignalSource.VOICE,
                Map.of("event", "night_trip", "times", 4));
        observed(homeId, now, 4, SignalType.ENVIRONMENT, SignalSource.SELF_REPORT,
                Map.of("event", "poor_air", "room", "quarto"));
        observed(homeId, now, 3, SignalType.ADHERENCE, SignalSource.SELF_REPORT, Map.of("taken", true));
        observed(homeId, now, 2, SignalType.SLEEP, SignalSource.VOICE,
                Map.of("event", "night_trip", "times", 4));
        observed(homeId, now, 1, SignalType.ADHERENCE, SignalSource.SELF_REPORT, Map.of("taken", false));
    }

    /** Sincronização diária do wearable: passos e sono caindo, frequência cardíaca de repouso subindo. */
    private void seedWearableVitals(UUID homeId, Instant now) {
        for (int daysAgo = HISTORY_DAYS; daysAgo >= 1; daysAgo--) {
            double progress = (double) (HISTORY_DAYS - daysAgo) / (HISTORY_DAYS - 1);
            Map<String, Object> vitals = new LinkedHashMap<>();
            vitals.put("steps", (int) Math.round(4200 - 2400 * progress));
            vitals.put("heartRateResting", (int) Math.round(68 + 11 * progress));
            vitals.put("sleepHours", Math.round((7.4 - 1.8 * progress) * 10) / 10d);
            observed(homeId, now, daysAgo, SignalType.VITALS, SignalSource.WEARABLE, vitals);
        }
    }

    /**
     * Escores já explicados das últimas três semanas: o risco de mobilidade sobe de 0,2 até o pico
     * de 0,9 que o fluxo-herói usa. Os snapshots antigos têm menos fatores porque o checklist de
     * segurança foi sendo preenchido pela cuidadora ao longo do período — é o que faz o risco subir
     * sem que a casa tenha mudado. As outras três dimensões entram com um escore recente para o
     * painel 360 abrir preenchido, cada uma coerente com os sinais que ficaram dentro da janela.
     */
    private void seedScoreTrend(UUID homeId, Instant now) {
        explained(homeId, now, 21, "mobility", 0.2, RiskLevel.LOW,
                List.of("anti_slip_floor"), List.of(0.2));
        explained(homeId, now, 18, "mobility", 0.5, RiskLevel.MEDIUM,
                List.of("no_grab_bar", "anti_slip_floor"), List.of(0.3, 0.2));
        explained(homeId, now, 14, "mobility", 0.5, RiskLevel.MEDIUM,
                List.of("no_grab_bar", "anti_slip_floor"), List.of(0.3, 0.2));
        explained(homeId, now, 10, "mobility", 0.6, RiskLevel.MEDIUM,
                List.of("no_grab_bar", "anti_slip_floor", "dizziness_bath"), List.of(0.3, 0.2, 0.1));
        explained(homeId, now, 6, "mobility", 0.6, RiskLevel.MEDIUM,
                List.of("no_grab_bar", "anti_slip_floor", "dizziness_bath"), List.of(0.3, 0.2, 0.1));
        explained(homeId, now, 3, "mobility", 0.9, RiskLevel.HIGH,
                List.of("near_fall_reported", "no_grab_bar", "anti_slip_floor"), List.of(0.4, 0.3, 0.2));
        explained(homeId, now, 1, "mobility", 0.9, RiskLevel.HIGH,
                List.of("near_fall_reported", "no_grab_bar", "anti_slip_floor"), List.of(0.4, 0.3, 0.2));

        explained(homeId, now, 2, "sleep", 0.6, RiskLevel.MEDIUM,
                List.of("night_trips_reported"), List.of(0.6));
        explained(homeId, now, 2, "cognition", 0.5, RiskLevel.MEDIUM,
                List.of("confusion_reported"), List.of(0.5));
        explained(homeId, now, 2, "environment", 0.6, RiskLevel.MEDIUM,
                List.of("poor_air_reported"), List.of(0.6));
    }

    /**
     * Carteira de pedidos da Torre de Controle: três instalados no prazo, um entregue com o SLA
     * estourado, um em rota (é o que o mapa da entrega mostra), um com o SLA vencendo na próxima
     * hora e um recém-aprovado. Os prazos saem da mesma regra da produção
     * ({@code aura.carechain.delivery-sla-hours}) e {@code slaBreached} é sempre coerente com a
     * data de entrega — OTIF, lead time e "pedido com SLA estourado" nascem daí, não de número
     * inventado no KPI.
     */
    private void seedOrderPipeline(Home casa, Instant now) {
        StockNode node = geo.nearestNode(nodes.findAll(), casa.getLat(), casa.getLng()).orElseThrow();
        int distanceM = (int) Math.round(
                geo.haversineMeters(casa.getLat(), casa.getLng(), node.getLat(), node.getLng()));
        int slaHours = props.carechain().deliverySlaHours();

        placed(casa, node, distanceM, "LM-LUZ-SENSOR", "Iluminação Noturna c/ Sensor",
                OrderStage.INSTALLED, now.minus(19, ChronoUnit.DAYS), 12, 31);
        placed(casa, node, distanceM, "LM-DET-GAS", "Detector de Gás e Fumaça",
                OrderStage.INSTALLED, now.minus(13, ChronoUnit.DAYS), 20, 40);
        placed(casa, node, distanceM, "LM-ANTIDERRAP", "Piso Antiderrapante p/ Box (m²)",
                OrderStage.INSTALLED, now.minus(8, ChronoUnit.DAYS), 16, 30);
        // entregue depois do prazo: é daqui que sai o "pedido com SLA estourado" da Torre
        placed(casa, node, distanceM, "LM-CAD-BANHO", "Cadeira de Banho Regulável",
                OrderStage.DELIVERED, now.minus(4, ChronoUnit.DAYS), slaHours + 9, null);

        DeliveryOrder emRota = placed(casa, node, distanceM, "LM-ANTIDERRAP",
                "Piso Antiderrapante p/ Box (m²)", OrderStage.IN_ROUTE,
                now.minus(14, ChronoUnit.HOURS), null, null);
        emRota.setEtaDelivery(now.plus(3, ChronoUnit.HOURS));
        orders.save(emRota);

        // criado há (SLA - 1)h: o prazo vence na próxima hora, é o pedido apertado do painel
        placed(casa, node, distanceM, "LM-PURIF-AR", "Purificador de Ar Compacto",
                OrderStage.SOURCING, now.minus(slaHours - 1L, ChronoUnit.HOURS), null, null);
        placed(casa, node, distanceM, "LM-LUZ-SENSOR", "Iluminação Noturna c/ Sensor",
                OrderStage.APPROVED, now.minus(2, ChronoUnit.HOURS), null, null);

        // nem toda recomendação vira pedido: uma recusada, sem entrega nenhuma atrás dela
        recommendation(casa.getId(), "LM-PURIF-AR", "Purificador de Ar Compacto", "rejected",
                now.minus(11, ChronoUnit.DAYS));
    }

    /**
     * Um pedido do histórico com a recomendação aprovada que o originou (RN-022: sem aprovação
     * humana o pedido não existe). {@code deliveredAfterH} e {@code installedAfterH} são horas
     * contadas da criação; nulos deixam o pedido em aberto.
     */
    private DeliveryOrder placed(Home casa, StockNode node, int distanceM, String sku, String productName,
                                 OrderStage stage, Instant createdAt,
                                 Integer deliveredAfterH, Integer installedAfterH) {
        Recommendation rec = recommendation(casa.getId(), sku, productName, "approved",
                createdAt.minus(1, ChronoUnit.HOURS));

        Instant slaDueAt = createdAt.plus(props.carechain().deliverySlaHours(), ChronoUnit.HOURS);
        Instant deliveredAt = deliveredAfterH == null ? null : createdAt.plus(deliveredAfterH, ChronoUnit.HOURS);
        Instant installedAt = installedAfterH == null ? null : createdAt.plus(installedAfterH, ChronoUnit.HOURS);

        return orders.save(DeliveryOrder.builder()
                .homeId(casa.getId()).recommendationId(rec.getId()).sku(sku).stage(stage)
                .nodeName(node.getName()).distanceM(distanceM)
                .createdAt(createdAt).slaDueAt(slaDueAt)
                .etaDelivery(deliveredAt).deliveredAt(deliveredAt)
                .installAt(installedAt).installedAt(installedAt)
                .slaBreached(deliveredAt != null && deliveredAt.isAfter(slaDueAt))
                .build());
    }

    private Recommendation recommendation(UUID homeId, String sku, String productName, String status,
                                          Instant createdAt) {
        return recommendations.save(Recommendation.builder()
                .homeId(homeId).sku(sku).status(status).createdAt(createdAt)
                .reason("%s reduz risco de queda/acidente (%s).".formatted(productName, NORM))
                .factors(List.of("no_grab_bar", "anti_slip_floor"))
                .weights(List.of(0.3, 0.2))
                .build());
    }

    private void observed(UUID homeId, Instant now, int daysAgo, SignalType type, SignalSource source,
                          Map<String, Object> value) {
        signals.save(Signal.builder().homeId(homeId).type(type).source(source).value(value)
                .capturedAt(now.minus(daysAgo, ChronoUnit.DAYS)).build());
    }

    private void explained(UUID homeId, Instant now, int daysAgo, String dimension, double score,
                           RiskLevel level, List<String> factors, List<Double> weights) {
        scores.save(Score.builder()
                .homeId(homeId).dimension(dimension).score(score).level(level)
                .factors(factors).weights(weights)
                .explanation("Norma %s → risco %s.".formatted(NORM, word(level)))
                .configVersion(props.scoring().configVersion())
                .explainedAt(now.minus(daysAgo, ChronoUnit.DAYS))
                .build());
    }

    private String word(RiskLevel level) {
        return switch (level) {
            case HIGH -> "ALTO";
            case MEDIUM -> "MÉDIO";
            case LOW -> "BAIXO";
        };
    }

    private Medication medicacao(Home casa, String name, String dosage,
                                 java.util.List<String> schedule, String notes) {
        return Medication.builder().homeId(casa.getId()).name(name).dosage(dosage)
                .schedule(new java.util.ArrayList<>(schedule)).notes(notes).build();
    }

    private Product product(String sku, String name, String category, String price,
                            boolean installable, String riskTag, int stock) {
        return Product.builder().sku(sku).name(name).category(category).price(new BigDecimal(price))
                .installable(installable).normRef(NORM).riskTag(riskTag).stockNearby(stock).build();
    }
}
