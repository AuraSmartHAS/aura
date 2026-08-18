package br.com.fiap.aura.web;

import br.com.fiap.aura.web.dto.OpsDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirements;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
@Tag(name = "0. Meta", description = "Saúde do serviço")
public class MetaController {

    private final Environment env;
    private final String version;

    public MetaController(Environment env, @Value("${aura.version:1.0.0}") String version) {
        this.env = env;
        this.version = version;
    }

    @GetMapping("/health")
    @SecurityRequirements
    @Operation(summary = "Health check usado pelo monitoramento e pelos apps")
    public OpsDtos.HealthResponse health() {
        String profile = env.getActiveProfiles().length == 0 ? "default" : env.getActiveProfiles()[0];
        return new OpsDtos.HealthResponse("ok", version, profile);
    }
}
