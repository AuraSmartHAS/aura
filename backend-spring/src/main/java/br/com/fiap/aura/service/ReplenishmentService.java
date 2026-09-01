package br.com.fiap.aura.service;

import br.com.fiap.aura.config.AuraProperties;
import br.com.fiap.aura.domain.Medication;
import br.com.fiap.aura.domain.Signal;
import br.com.fiap.aura.domain.enums.SignalType;
import br.com.fiap.aura.repository.MedicationRepository;
import br.com.fiap.aura.repository.SignalRepository;
import br.com.fiap.aura.security.AuthPrincipal;
import br.com.fiap.aura.web.dto.ReplenishmentDtos;
import java.time.Duration;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Reposição por consumo — a promessa da Atividade 1, no corte raso declarado: burn rate é a
 * média simples das doses confirmadas por voz na janela, e a régua dispara quando os dias de
 * estoque ficam abaixo do lead time da cadeia mais a margem de segurança. Sem modelo preditivo:
 * a conta viaja aberta no DTO, como no escore. A projeção nunca cria pedido — pedido é assunto
 * exclusivo da aprovação humana (RN-022).
 */
@Service
public class ReplenishmentService {

    private final MedicationRepository medications;
    private final SignalRepository signals;
    private final HomeService homeService;
    private final GuardrailService guardrails;
    private final AuraProperties props;

    public ReplenishmentService(MedicationRepository medications, SignalRepository signals,
                                HomeService homeService, GuardrailService guardrails,
                                AuraProperties props) {
        this.medications = medications;
        this.signals = signals;
        this.homeService = homeService;
        this.guardrails = guardrails;
        this.props = props;
    }

    @Transactional
    public List<ReplenishmentDtos.Projection> check(AuthPrincipal principal, UUID homeId) {
        homeService.requireAccess(principal, homeId);
        AuraProperties.Replenish cfg = props.carechain().replenish();
        Instant now = Instant.now();

        List<Signal> adherence = signals.search(homeId, SignalType.ADHERENCE,
                now.minus(cfg.windowDays(), ChronoUnit.DAYS), null, PageRequest.of(0, 2000));

        List<ReplenishmentDtos.Projection> projections = new ArrayList<>();
        for (Medication med : medications.findByHomeIdOrderByCreatedAtDesc(homeId, PageRequest.of(0, 200))) {
            // sem estoque controlado não há o que projetar — a medicação segue fora da régua
            if (med.isActive() && med.getStockDoses() != null) {
                projections.add(project(med, adherence, cfg, now));
            }
        }
        return projections;
    }

    private ReplenishmentDtos.Projection project(Medication med, List<Signal> adherence,
                                                 AuraProperties.Replenish cfg, Instant now) {
        String medId = med.getId().toString();
        // o value do sinal é JSON numa coluna texto: o filtro por medicação é em memória, de propósito
        List<Signal> daMedicacao = adherence.stream()
                .filter(s -> medId.equals(s.getValue().get("medicationId")))
                .toList();
        long confirmadas = daMedicacao.stream()
                .filter(s -> Boolean.TRUE.equals(s.getValue().get("taken")))
                .count();
        long historyDays = daMedicacao.stream()
                .map(Signal::getCapturedAt)
                .min(Instant::compareTo)
                .map(oldest -> Duration.between(oldest, now).toDays())
                .orElse(0L);

        int leadTimeHours = props.carechain().deliverySlaHours();
        double thresholdDays = leadTimeHours / 24d + cfg.safetyStockDays();
        double avg = round1((double) confirmadas / cfg.windowDays());
        Double daysOfSupply = avg > 0 ? round1(med.getStockDoses() / avg) : null;

        boolean suggested = historyDays >= cfg.minHistoryDays()
                && daysOfSupply != null && daysOfSupply < thresholdDays;

        // a frase fala de estoque, ritmo e prazo — nunca de tratamento; e passa no guardrail como
        // qualquer texto que sai da API
        String reason = suggested ? guardrails.assertNonPrescriptive(
                ("Reposição sugerida de %s: estoque da casa para cerca de %d dias no ritmo atual "
                        + "(média de %s doses confirmadas por dia em %d dias), abaixo da margem de "
                        + "%d dias mais o prazo de entrega de %d h da cadeia.")
                        .formatted(med.getName(), Math.round(daysOfSupply),
                                String.format(Locale.forLanguageTag("pt-BR"), "%.1f", avg),
                                cfg.windowDays(), cfg.safetyStockDays(), leadTimeHours))
                : null;

        return new ReplenishmentDtos.Projection(med.getId(), med.getName(), med.getStockDoses(),
                avg, daysOfSupply, leadTimeHours, cfg.safetyStockDays(), thresholdDays,
                suggested, null, reason);
    }

    private static double round1(double value) {
        return Math.round(value * 10d) / 10d;
    }
}
