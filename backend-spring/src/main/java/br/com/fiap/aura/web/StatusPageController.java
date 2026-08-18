package br.com.fiap.aura.web;

import br.com.fiap.aura.repository.DeliveryOrderRepository;
import br.com.fiap.aura.repository.HomeRepository;
import br.com.fiap.aura.repository.ProductRepository;
import br.com.fiap.aura.domain.enums.OrderStage;
import java.time.Instant;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * Página de status renderizada no servidor com Spring MVC + Thymeleaf.
 * É a única tela servida pelo backend — os clientes (Flutter, React Native e
 * Angular) consomem a API REST.
 */
@Controller
public class StatusPageController {

    private final ProductRepository products;
    private final HomeRepository homes;
    private final DeliveryOrderRepository orders;
    private final Environment env;

    public StatusPageController(ProductRepository products, HomeRepository homes,
                                DeliveryOrderRepository orders, Environment env) {
        this.products = products;
        this.homes = homes;
        this.orders = orders;
        this.env = env;
    }

    @GetMapping({"/", "/status"})
    public String status(Model model) {
        String profile = env.getActiveProfiles().length == 0 ? "default" : env.getActiveProfiles()[0];
        model.addAttribute("appName", "AURA Care-Chain API");
        model.addAttribute("status", "ok");
        model.addAttribute("version", "1.0.0");
        model.addAttribute("profile", profile);
        model.addAttribute("database", "postgres".equals(profile) ? "PostgreSQL" : "H2 (memória)");
        model.addAttribute("apiPrefix", "/api/v1");
        model.addAttribute("products", products.count());
        model.addAttribute("homes", homes.count());
        model.addAttribute("openOrders", orders.countByStageNot(OrderStage.RETURNED));
        model.addAttribute("now", Instant.now().toString());
        return "status";
    }
}
