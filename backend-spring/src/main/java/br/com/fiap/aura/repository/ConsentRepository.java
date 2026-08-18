package br.com.fiap.aura.repository;

import br.com.fiap.aura.domain.Consent;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ConsentRepository extends JpaRepository<Consent, UUID> {

    boolean existsByUserId(UUID userId);

    void deleteByUserId(UUID userId);
}
