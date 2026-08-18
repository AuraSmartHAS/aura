package br.com.fiap.aura.web.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import java.math.BigDecimal;

public final class CatalogDtos {

    private CatalogDtos() { }

    public record CatalogItemResponse(String sku, String name, String category, BigDecimal price,
                                      boolean installable, String normRef, String riskTag, int stockNearby) { }

    public record UpsertProductRequest(
            @NotBlank String name,
            @NotBlank String category,
            @NotNull @PositiveOrZero BigDecimal price,
            boolean installable,
            @Schema(example = "NBR 9050") String normRef,
            @Schema(example = "fall_bathroom") String riskTag,
            @PositiveOrZero int stockNearby) { }

    public record DeletedResponse(boolean deleted) { }
}
