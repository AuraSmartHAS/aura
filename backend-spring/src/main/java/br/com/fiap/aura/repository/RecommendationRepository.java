package br.com.fiap.aura.repository;

import br.com.fiap.aura.domain.Recommendation;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RecommendationRepository extends JpaRepository<Recommendation, UUID> {

    List<Recommendation> findByHomeIdOrderByCreatedAtDesc(UUID homeId);

    /** Dedupe da reposição: uma recomendação aberta por medicação, nunca uma por check. */
    Optional<Recommendation> findFirstByHomeIdAndMedicationIdAndStatus(UUID homeId, UUID medicationId,
                                                                       String status);

    void deleteByHomeId(UUID homeId);
}
