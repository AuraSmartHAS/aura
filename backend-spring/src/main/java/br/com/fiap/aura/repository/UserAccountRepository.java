package br.com.fiap.aura.repository;

import br.com.fiap.aura.domain.UserAccount;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserAccountRepository extends JpaRepository<UserAccount, UUID> {

    Optional<UserAccount> findByEmailIgnoreCase(String email);

    boolean existsByEmailIgnoreCase(String email);

    /** Quem mais está com este aparelho: um token FCM pertence a uma pessoa só. */
    List<UserAccount> findByFcmToken(String fcmToken);
}
