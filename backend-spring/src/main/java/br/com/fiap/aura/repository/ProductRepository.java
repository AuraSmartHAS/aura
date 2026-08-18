package br.com.fiap.aura.repository;

import br.com.fiap.aura.domain.Product;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProductRepository extends JpaRepository<Product, String> {

    List<Product> findByRiskTagOrderByNameAsc(String riskTag);

    /**
     * Item primário do risco: instalável primeiro e, entre eles, o de maior cobertura.
     * Ex.: fall_bathroom → Kit Barra de Apoio antes do piso antiderrapante complementar.
     */
    Optional<Product> findFirstByRiskTagOrderByInstallableDescPriceDesc(String riskTag);
}
