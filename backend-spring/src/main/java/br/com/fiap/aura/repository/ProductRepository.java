package br.com.fiap.aura.repository;

import br.com.fiap.aura.domain.Product;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductRepository extends JpaRepository<Product, String> {

    List<Product> findByRiskTagOrderByNameAsc(String riskTag);

    /**
     * Item primário do risco: o destaque da curadoria primeiro (kit de entrada validado com a
     * persona), depois instalável e, entre eles, o de maior cobertura. Sem o degrau do destaque,
     * um catálogo grande faria a recomendação cair no item mais premium da prateleira.
     */
    Optional<Product> findFirstByRiskTagOrderByFeaturedDescInstallableDescPriceDesc(String riskTag);
}
