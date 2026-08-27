package br.com.fiap.aura.repository;

import br.com.fiap.aura.domain.HomeMember;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface HomeMemberRepository extends JpaRepository<HomeMember, UUID> {

    boolean existsByHomeIdAndUserId(UUID homeId, UUID userId);

    List<HomeMember> findByHomeIdOrderByCreatedAt(UUID homeId);

    @Query("select m.homeId from HomeMember m where m.userId = :userId")
    List<UUID> findHomeIdsByUserId(UUID userId);

    void deleteByHomeId(UUID homeId);

    void deleteByUserId(UUID userId);
}
