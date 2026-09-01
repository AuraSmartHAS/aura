package br.com.fiap.aura.service;

import br.com.fiap.aura.domain.DeliveryOrder;
import br.com.fiap.aura.domain.enums.OrderStage;
import br.com.fiap.aura.domain.enums.RiskLevel;
import br.com.fiap.aura.repository.DeliveryOrderRepository;
import br.com.fiap.aura.repository.HomeRepository;
import br.com.fiap.aura.repository.ProductRepository;
import br.com.fiap.aura.repository.ScoreRepository;
import br.com.fiap.aura.repository.SignalRepository;
import br.com.fiap.aura.web.dto.OpsDtos;
import java.lang.management.ManagementFactory;
import java.time.Duration;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Torre de Controle (NOC): os KPIs que o painel Angular mostra em tempo real. */
@Service
public class OpsService {

    private final DeliveryOrderRepository orders;
    private final ProductRepository products;
    private final HomeRepository homes;
    private final SignalRepository signals;
    private final ScoreRepository scores;

    public OpsService(DeliveryOrderRepository orders, ProductRepository products, HomeRepository homes,
                      SignalRepository signals, ScoreRepository scores) {
        this.orders = orders;
        this.products = products;
        this.homes = homes;
        this.signals = signals;
        this.scores = scores;
    }

    @Transactional(readOnly = true)
    public OpsDtos.KpiResponse kpis() {
        List<DeliveryOrder> all = orders.findAll();

        List<DeliveryOrder> delivered = all.stream().filter(o -> o.getDeliveredAt() != null).toList();
        double otif = delivered.isEmpty() ? 1.0
                : (double) delivered.stream().filter(o -> !o.isSlaBreached()).count() / delivered.size();

        long skus = products.count();
        double fillRate = skus == 0 ? 0
                : (double) products.findAll().stream().filter(p -> p.getStockNearby() > 0).count() / skus;

        double leadTimeHours = delivered.isEmpty() ? 0 : delivered.stream()
                .mapToDouble(o -> Duration.between(o.getCreatedAt(), o.getDeliveredAt()).toMinutes() / 60d)
                .average().orElse(0);

        long open = all.stream()
                .filter(o -> o.getStage() != OrderStage.INSTALLED && o.getStage() != OrderStage.RETURNED)
                .count();

        List<OpsDtos.StageCount> byStage = java.util.Arrays.stream(OrderStage.values())
                .map(stage -> new OpsDtos.StageCount(stage.value(),
                        all.stream().filter(o -> o.getStage() == stage).count()))
                .toList();

        long highRisk = scores.findAll().stream().filter(s -> s.getLevel() == RiskLevel.HIGH).count();

        return new OpsDtos.KpiResponse(round(otif), round(fillRate), round(leadTimeHours), open,
                all.stream().filter(DeliveryOrder::isSlaBreached).count(),
                homes.count(), signals.count(), highRisk, uptime(), byStage);
    }

    /** A carteira que a Torre exibe: os 20 pedidos mais recentes, do mais novo pro mais antigo. */
    @Transactional(readOnly = true)
    public List<OpsDtos.OrderRow> orders() {
        var nameBySku = products.findAll().stream()
                .collect(java.util.stream.Collectors.toMap(p -> p.getSku(), p -> p.getName(), (a, b) -> a));
        return this.orders.findTop20ByOrderByCreatedAtDesc().stream()
                .map(o -> new OpsDtos.OrderRow(o.getId(), o.getSku(),
                        nameBySku.getOrDefault(o.getSku(), o.getSku()), o.getStage().value(),
                        o.getNodeName(), o.getSlaDueAt(), o.isSlaBreached(),
                        o.getEtaDelivery(), o.getCreatedAt()))
                .toList();
    }

    private String uptime() {
        Duration up = Duration.ofMillis(ManagementFactory.getRuntimeMXBean().getUptime());
        return "%dh %02dm".formatted(up.toHours(), up.toMinutesPart());
    }

    private double round(double value) {
        return Math.round(value * 1000d) / 1000d;
    }
}
