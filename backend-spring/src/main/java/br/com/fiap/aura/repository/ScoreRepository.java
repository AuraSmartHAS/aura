package br.com.fiap.aura.repository;

import br.com.fiap.aura.domain.Score;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ScoreRepository extends JpaRepository<Score, UUID> {

    List<Score> findByHomeIdOrderByExplainedAtDesc(UUID homeId);

    void deleteByHomeId(UUID homeId);
}
