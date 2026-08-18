package br.com.fiap.aura.config;

import br.com.fiap.aura.domain.Home;
import br.com.fiap.aura.domain.Product;
import br.com.fiap.aura.domain.Signal;
import br.com.fiap.aura.domain.StockNode;
import br.com.fiap.aura.domain.UserAccount;
import br.com.fiap.aura.domain.enums.Role;
import br.com.fiap.aura.domain.enums.SignalSource;
import br.com.fiap.aura.domain.enums.SignalType;
import br.com.fiap.aura.repository.ConsentRepository;
import br.com.fiap.aura.repository.HomeRepository;
import br.com.fiap.aura.repository.ProductRepository;
import br.com.fiap.aura.repository.SignalRepository;
import br.com.fiap.aura.repository.StockNodeRepository;
import br.com.fiap.aura.repository.UserAccountRepository;
import br.com.fiap.aura.domain.Consent;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * Cenário de demonstração: catálogo NBR 9050, dois nós logísticos, a cuidadora Ana,
 * um admin e a casa da Maria já com risco de queda no banheiro.
 * Só roda com {@code aura.seed.enabled=true} (perfil dev).
 */
@Component
@ConditionalOnProperty(name = "aura.seed.enabled", havingValue = "true")
public class DataSeeder implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(DataSeeder.class);
    private static final String DEMO_PASSWORD = "aura1234";

    private final ProductRepository products;
    private final StockNodeRepository nodes;
    private final UserAccountRepository users;
    private final ConsentRepository consents;
    private final HomeRepository homes;
    private final SignalRepository signals;
    private final PasswordEncoder encoder;

    public DataSeeder(ProductRepository products, StockNodeRepository nodes, UserAccountRepository users,
                      ConsentRepository consents, HomeRepository homes, SignalRepository signals,
                      PasswordEncoder encoder) {
        this.products = products;
        this.nodes = nodes;
        this.users = users;
        this.consents = consents;
        this.homes = homes;
        this.signals = signals;
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
        checklist.put("slippery_floor", true);       // piso escorregadio → fator de risco
        checklist.put("night_light", true);
        checklist.put("gas_detector", true);
        checklist.put("air_purifier", true);

        Home casa = homes.save(Home.builder()
                .ownerUserId(ana.getId()).patientName("Maria S.").birthDate(LocalDate.of(1952, 3, 10))
                .label("Casa da Maria").cep("01310100")
                .address("Av. Paulista, Bela Vista, São Paulo, SP")
                .lat(-23.561).lng(-46.656).safetyChecklist(checklist)
                .build());

        signals.save(Signal.builder().homeId(casa.getId()).type(SignalType.MOBILITY)
                .source(SignalSource.VOICE).value(Map.of("event", "near_fall", "place", "bathroom")).build());
        signals.save(Signal.builder().homeId(casa.getId()).type(SignalType.ADHERENCE)
                .source(SignalSource.SELF_REPORT).value(Map.of("taken", true)).build());

        log.info("Seed pronto — login de demonstração: ana@aura.com / {} (casa {})", DEMO_PASSWORD, casa.getId());
    }

    private Product product(String sku, String name, String category, String price,
                            boolean installable, String riskTag, int stock) {
        return Product.builder().sku(sku).name(name).category(category).price(new BigDecimal(price))
                .installable(installable).normRef("NBR 9050").riskTag(riskTag).stockNearby(stock).build();
    }
}
