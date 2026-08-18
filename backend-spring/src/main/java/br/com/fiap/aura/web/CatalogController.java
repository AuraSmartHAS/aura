package br.com.fiap.aura.web;

import br.com.fiap.aura.service.CatalogService;
import br.com.fiap.aura.web.dto.CatalogDtos;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/catalog")
@Tag(name = "4. Catálogo", description = "Itens de acessibilidade (NBR 9050) — CRUD administrativo")
public class CatalogController {

    private final CatalogService catalog;

    public CatalogController(CatalogService catalog) {
        this.catalog = catalog;
    }

    @GetMapping
    @Operation(summary = "Lista o catálogo, opcionalmente filtrado pelo risco que o item mitiga")
    public List<CatalogDtos.CatalogItemResponse> list(@RequestParam(required = false) String riskTag) {
        return catalog.list(riskTag);
    }

    @GetMapping("/{sku}")
    @Operation(summary = "Detalhe de um item do catálogo")
    public CatalogDtos.CatalogItemResponse get(@PathVariable String sku) {
        return catalog.get(sku);
    }

    @PostMapping("/{sku}")
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Cadastra um item no catálogo (admin)")
    public CatalogDtos.CatalogItemResponse create(@PathVariable String sku,
                                                  @Valid @RequestBody CatalogDtos.UpsertProductRequest req) {
        return catalog.create(sku, req);
    }

    @PutMapping("/{sku}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Atualiza um item do catálogo (admin)")
    public CatalogDtos.CatalogItemResponse update(@PathVariable String sku,
                                                  @Valid @RequestBody CatalogDtos.UpsertProductRequest req) {
        return catalog.update(sku, req);
    }

    @DeleteMapping("/{sku}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(summary = "Remove um item do catálogo (admin)")
    public CatalogDtos.DeletedResponse delete(@PathVariable String sku) {
        catalog.delete(sku);
        return new CatalogDtos.DeletedResponse(true);
    }
}
