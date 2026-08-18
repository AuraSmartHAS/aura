package br.com.fiap.aura.repository;

import br.com.fiap.aura.domain.StockNode;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StockNodeRepository extends JpaRepository<StockNode, UUID> {
}
