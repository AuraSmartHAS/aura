package br.com.fiap.aura.repository;

import br.com.fiap.aura.domain.Medication;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface MedicationRepository extends JpaRepository<Medication, UUID> {

    List<Medication> findByHomeIdOrderByCreatedAtDesc(UUID homeId, Pageable pageable);

    void deleteByHomeId(UUID homeId);
}
