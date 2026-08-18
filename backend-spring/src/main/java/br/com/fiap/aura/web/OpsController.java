package br.com.fiap.aura.web;

import br.com.fiap.aura.service.OpsService;
import br.com.fiap.aura.web.dto.OpsDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/ops")
@Tag(name = "6. Torre de Controle", description = "KPIs de operação (somente admin)")
public class OpsController {

    private final OpsService ops;

    public OpsController(OpsService ops) {
        this.ops = ops;
    }

    @GetMapping("/kpis")
    @Operation(summary = "OTIF, fill rate, lead time, SLA e volume monitorado")
    public OpsDtos.KpiResponse kpis() {
        return ops.kpis();
    }
}
