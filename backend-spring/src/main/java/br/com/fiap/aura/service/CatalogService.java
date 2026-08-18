package br.com.fiap.aura.service;

import br.com.fiap.aura.domain.Product;
import br.com.fiap.aura.repository.ProductRepository;
import br.com.fiap.aura.web.dto.CatalogDtos;
import br.com.fiap.aura.web.error.ApiException;
import java.util.Comparator;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Catálogo de acessibilidade (NBR 9050) — leitura para todos, escrita só para admin. */
@Service
public class CatalogService {

    private final ProductRepository products;

    public CatalogService(ProductRepository products) {
        this.products = products;
    }

    @Transactional(readOnly = true)
    public List<CatalogDtos.CatalogItemResponse> list(String riskTag) {
        List<Product> found = (riskTag == null || riskTag.isBlank())
                ? products.findAll()
                : products.findByRiskTagOrderByNameAsc(riskTag);
        return found.stream()
                .sorted(Comparator.comparing(Product::getName))
                .map(CatalogService::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public CatalogDtos.CatalogItemResponse get(String sku) {
        return toResponse(require(sku));
    }

    @Transactional
    public CatalogDtos.CatalogItemResponse create(String sku, CatalogDtos.UpsertProductRequest req) {
        if (products.existsById(sku)) {
            throw ApiException.conflict("Já existe produto com o SKU " + sku + ".");
        }
        return toResponse(products.save(Product.builder()
                .sku(sku).name(req.name()).category(req.category()).price(req.price())
                .installable(req.installable()).normRef(req.normRef()).riskTag(req.riskTag())
                .stockNearby(req.stockNearby())
                .build()));
    }

    @Transactional
    public CatalogDtos.CatalogItemResponse update(String sku, CatalogDtos.UpsertProductRequest req) {
        Product product = require(sku);
        product.setName(req.name());
        product.setCategory(req.category());
        product.setPrice(req.price());
        product.setInstallable(req.installable());
        product.setNormRef(req.normRef());
        product.setRiskTag(req.riskTag());
        product.setStockNearby(req.stockNearby());
        return toResponse(product);
    }

    @Transactional
    public void delete(String sku) {
        products.delete(require(sku));
    }

    private Product require(String sku) {
        return products.findById(sku).orElseThrow(() -> ApiException.notFound("Produto " + sku));
    }

    static CatalogDtos.CatalogItemResponse toResponse(Product p) {
        return new CatalogDtos.CatalogItemResponse(p.getSku(), p.getName(), p.getCategory(), p.getPrice(),
                p.isInstallable(), p.getNormRef(), p.getRiskTag(), p.getStockNearby());
    }
}
