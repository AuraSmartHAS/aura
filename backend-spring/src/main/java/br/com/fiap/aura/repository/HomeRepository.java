package br.com.fiap.aura.repository;

import br.com.fiap.aura.domain.Home;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface HomeRepository extends JpaRepository<Home, UUID> {

    List<Home> findByOwnerUserIdOrderByCreatedAtDesc(UUID ownerUserId);
}
