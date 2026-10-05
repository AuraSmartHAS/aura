package br.com.fiap.aura.web;

import br.com.fiap.aura.intelligence.IntelligenceService;
import br.com.fiap.aura.security.CurrentUser;
import br.com.fiap.aura.web.dto.IntelligenceDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.time.LocalDate;
import java.util.UUID;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Rotas da inteligência que roda no banco (Fase 6). Cada uma termina numa function ou procedure
 * PL/SQL no perfil oracle; fora dele respondem {@code engine: "indisponivel"}.
 * As de {@code /ops} exigem ADMIN pela regra de {@code SecurityConfig}.
 */
@RestController
@RequestMapping(value = "/api/v1", produces = MediaType.APPLICATION_JSON_VALUE)
@Tag(name = "9. Inteligência no banco (Oracle)",
        description = "Avisos, relatório de consumo e indicadores calculados por PL/SQL")
public class IntelligenceController {

    private final IntelligenceService intelligence;
    private final CurrentUser currentUser;

    public IntelligenceController(IntelligenceService intelligence, CurrentUser currentUser) {
        this.intelligence = intelligence;
        this.currentUser = currentUser;
    }

    @GetMapping("/homes/{homeId}/alertas")
    @Operation(summary = "Avisos que o banco gravou para a casa, mais recentes primeiro (máx. 20)")
    public IntelligenceDtos.AlertasResponse alertas(@PathVariable UUID homeId) {
        return intelligence.alertas(currentUser.require(), homeId);
    }

    @PostMapping("/homes/{homeId}/alertas/processar")
    @Operation(summary = "Roda PRC_REGISTRAR_ALERTAS agora; repetir não duplica aviso")
    public IntelligenceDtos.ProcessarResponse processar(@PathVariable UUID homeId) {
        return intelligence.processar(currentUser.require(), homeId);
    }

    @PostMapping("/alertas/{alertaId}/visto")
    @Operation(summary = "Marca o aviso como visto por quem cuida")
    public IntelligenceDtos.VistoResponse visto(@PathVariable UUID alertaId) {
        return intelligence.marcarVisto(currentUser.require(), alertaId);
    }

    @GetMapping("/homes/{homeId}/relatorio-consumo")
    @Operation(summary = "Relatório de consumo por medicação (PRC_RELATORIO_CONSUMO); padrão: últimos 7 dias")
    public IntelligenceDtos.RelatorioConsumoResponse relatorioConsumo(
            @PathVariable UUID homeId,
            @Parameter(example = "2026-09-28") @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate de,
            @Parameter(example = "2026-10-04") @RequestParam(required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate ate) {
        return intelligence.relatorioConsumo(currentUser.require(), homeId, de, ate);
    }

    @GetMapping("/ops/indicadores")
    @Operation(summary = "Indicadores por casa do último dia consolidado (somente admin)")
    public IntelligenceDtos.IndicadoresResponse indicadores() {
        return intelligence.indicadores();
    }

    @PostMapping("/ops/indicadores/consolidar")
    @Operation(summary = "Roda PRC_CONSOLIDAR_INDICADORES agora (somente admin)")
    public IntelligenceDtos.ConsolidarResponse consolidar() {
        return intelligence.consolidar();
    }
}
