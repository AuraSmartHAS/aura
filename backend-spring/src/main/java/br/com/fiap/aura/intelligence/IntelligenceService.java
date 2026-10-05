package br.com.fiap.aura.intelligence;

import br.com.fiap.aura.security.AuthPrincipal;
import br.com.fiap.aura.service.GuardrailService;
import br.com.fiap.aura.service.HomeService;
import br.com.fiap.aura.web.dto.IntelligenceDtos;
import br.com.fiap.aura.web.error.ApiException;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Regras de acesso em volta da inteligência no banco. O PL/SQL recebe só o id da casa; quem pode
 * ver qual casa é decidido aqui, antes da chamada, pelo mesmo {@code requireAccess} das outras rotas.
 */
@Service
public class IntelligenceService {

    private static final Logger log = LoggerFactory.getLogger(IntelligenceService.class);
    private static final ZoneId BRASILIA = ZoneId.of("America/Sao_Paulo");
    private static final int MAX_ALERTAS = 20;
    private static final int PERIODO_PADRAO_DIAS = 7;

    private final CareIntelligence intelligence;
    private final HomeService homeService;
    private final GuardrailService guardrail;

    public IntelligenceService(CareIntelligence intelligence, HomeService homeService, GuardrailService guardrail) {
        this.intelligence = intelligence;
        this.homeService = homeService;
        this.guardrail = guardrail;
    }

    @Transactional(readOnly = true)
    public IntelligenceDtos.AlertasResponse alertas(AuthPrincipal principal, UUID homeId) {
        homeService.requireAccess(principal, homeId);
        // Um texto reprovado no guardrail some da lista em vez de derrubá-la com 422: os outros
        // avisos continuam valendo para quem cuida.
        List<IntelligenceDtos.Alerta> aprovados = intelligence.listarAlertas(homeId, MAX_ALERTAS).stream()
                .filter(this::passaNoGuardrail)
                .toList();
        return new IntelligenceDtos.AlertasResponse(intelligence.engine(), aprovados);
    }

    @Transactional
    public IntelligenceDtos.ProcessarResponse processar(AuthPrincipal principal, UUID homeId) {
        homeService.requireAccess(principal, homeId);
        return new IntelligenceDtos.ProcessarResponse(intelligence.engine(), intelligence.registrarAlertas(homeId));
    }

    @Transactional
    public IntelligenceDtos.VistoResponse marcarVisto(AuthPrincipal principal, UUID alertaId) {
        UUID homeId = intelligence.casaDoAlerta(alertaId).orElseThrow(() -> ApiException.notFound("Aviso"));
        homeService.requireAccess(principal, homeId);
        intelligence.marcarVisto(alertaId);
        return new IntelligenceDtos.VistoResponse(alertaId, "visto");
    }

    @Transactional(readOnly = true)
    public IntelligenceDtos.RelatorioConsumoResponse relatorioConsumo(AuthPrincipal principal, UUID homeId,
                                                                      LocalDate de, LocalDate ate) {
        homeService.requireAccess(principal, homeId);
        LocalDate fim = ate == null ? LocalDate.now(BRASILIA) : ate;
        LocalDate inicio = de == null ? fim.minusDays(PERIODO_PADRAO_DIAS - 1L) : de;
        return intelligence.relatorioConsumo(homeId, inicio, fim);
    }

    @Transactional(readOnly = true)
    public IntelligenceDtos.IndicadoresResponse indicadores() {
        return intelligence.indicadores();
    }

    @Transactional
    public IntelligenceDtos.ConsolidarResponse consolidar() {
        return new IntelligenceDtos.ConsolidarResponse(intelligence.engine(), intelligence.consolidarIndicadores(null));
    }

    private boolean passaNoGuardrail(IntelligenceDtos.Alerta alerta) {
        try {
            guardrail.assertNonPrescriptive(alerta.mensagem());
            return true;
        } catch (ApiException e) {
            log.warn("Aviso {} da regra {} omitido: texto reprovado no guardrail", alerta.id(), alerta.regra());
            return false;
        }
    }
}
