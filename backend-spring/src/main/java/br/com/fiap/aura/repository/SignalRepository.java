package br.com.fiap.aura.repository;

import br.com.fiap.aura.domain.Signal;
import br.com.fiap.aura.domain.enums.SignalType;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SignalRepository extends JpaRepository<Signal, UUID> {

    List<Signal> findByHomeIdAndCapturedAtGreaterThanEqual(UUID homeId, Instant from);

    /** Listagem paginada com filtros opcionais — um único índice (home_id, captured_at) atende. */
    @Query("""
            select s from Signal s
             where s.homeId = :homeId
               and (:type is null or s.type = :type)
               and (:from is null or s.capturedAt >= :from)
               and (:to   is null or s.capturedAt <= :to)
             order by s.capturedAt desc
            """)
    List<Signal> search(@Param("homeId") UUID homeId,
                        @Param("type") SignalType type,
                        @Param("from") Instant from,
                        @Param("to") Instant to,
                        Pageable pageable);

    long countByHomeId(UUID homeId);

    void deleteByHomeId(UUID homeId);
}
