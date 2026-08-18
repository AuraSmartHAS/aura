package br.com.fiap.aura.repository;

import br.com.fiap.aura.domain.Recommendation;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RecommendationRepository extends JpaRepository<Recommendation, UUID> {

    List<Recommendation> findByHomeIdOrderByCreatedAtDesc(UUID homeId);

    void deleteByHomeId(UUID homeId);
}
