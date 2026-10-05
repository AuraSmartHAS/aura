package br.com.fiap.aura.repository;

import br.com.fiap.aura.domain.Recommendation;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RecommendationRepository extends JpaRepository<Recommendation, UUID> {

    List<Recommendation> findByHomeIdOrderByCreatedAtDesc(UUID homeId);

    /** Dedupe da reposição: uma recomendação aberta por medicação, nunca uma por check. */
    Optional<Recommendation> findFirstByHomeIdAndMedicationIdAndStatus(UUID homeId, UUID medicationId,
                                                                       String status);

    void deleteByHomeId(UUID homeId);

    /** Produto com histórico de recomendação não pode sair do catálogo (ver CatalogService.delete). */
    boolean existsBySku(String sku);

    /**
     * A recomendação de refil sobrevive à medicação excluída, só deixa de apontar para ela.
     * Mesma regra do {@code ON DELETE SET NULL} do esquema Oracle, aplicada aqui para valer também
     * em H2 e PostgreSQL, onde não há chave estrangeira.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update Recommendation r set r.medicationId = null where r.medicationId = :medicationId")
    int detachMedication(@Param("medicationId") UUID medicationId);
}
