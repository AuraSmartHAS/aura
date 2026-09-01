package br.com.fiap.aura.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.UUID;

public final class ReplenishmentDtos {

    private ReplenishmentDtos() { }

    @Schema(description = """
            Projeção de reposição de uma medicação com estoque controlado. A conta viaja aberta:
            burn rate = doses confirmadas na janela ÷ dias da janela; a régua dispara quando
            `daysOfSupply` fica abaixo do lead time da cadeia mais a margem de segurança.
            `suggested=false` quando falta história (`min-history-days`) ou o estoque está folgado.
            Nada aqui cria pedido: a aprovação humana continua sendo a única porta (RN-022).""")
    public record Projection(UUID medicationId, String medicationName, Integer stockDoses,
                             @Schema(example = "2.8") Double avgDosesPerDay,
                             @Schema(example = "4.7", description = "Nulo sem consumo confirmado na janela")
                             Double daysOfSupply,
                             @Schema(example = "24") int leadTimeHours,
                             @Schema(example = "4") int safetyStockDays,
                             @Schema(example = "5.0") double thresholdDays,
                             boolean suggested,
                             @Schema(description = "Recomendação criada ou reusada quando a régua dispara")
                             UUID recommendationId,
                             String reason) { }
}
