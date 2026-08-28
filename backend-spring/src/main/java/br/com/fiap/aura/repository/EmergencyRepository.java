package br.com.fiap.aura.repository;

import br.com.fiap.aura.domain.Emergency;
import br.com.fiap.aura.domain.enums.EmergencyState;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface EmergencyRepository extends JpaRepository<Emergency, UUID> {

    /**
     * <b>Compare-and-set do estado, e é o coração da janela de cancelamento.</b>
     *
     * <p>"Dentro da janela" não é uma comparação de relógio — é <i>chegar antes do disparador</i>.
     * Comparar {@code now < dispatchDueAt} na aplicação deixa uma fresta real: o relógio diz 4,9s,
     * o disparador já pegou a linha, e aí o cancelamento "bem-sucedido" cancelaria uma emergência
     * cujo push já saiu — a Ana estaria na rua com o app dizendo "foi engano". Aqui quem transiciona
     * é quem consegue o {@code UPDATE} com o estado esperado; o outro recebe 0 linhas e sabe que
     * perdeu a corrida.
     *
     * <p>Também é o que torna o disparo <b>idempotente</b> com três chamadores possíveis (o
     * agendamento pontual, o varredor de recuperação e um toque duplo acidental): só um vence.
     *
     * @return 1 se a transição aconteceu, 0 se o estado já não era o esperado
     */
    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update Emergency e
               set e.state = :novo, e.stateChangedAt = :agora
             where e.id = :id and e.state = :esperado
            """)
    int compareAndSetState(@Param("id") UUID id,
                           @Param("esperado") EmergencyState esperado,
                           @Param("novo") EmergencyState novo,
                           @Param("agora") Instant agora);

    /** A última emergência da casa — base da deduplicação de toque repetido. */
    Optional<Emergency> findFirstByHomeIdOrderByCreatedAtDesc(UUID homeId);

    /** Contagem por casa numa janela — é o teto por hora da mitigação de abuso (regra 3). */
    long countByHomeIdAndCreatedAtGreaterThanEqual(UUID homeId, Instant from);

    /**
     * Rede de segurança do agendamento: o disparo pontual vive na memória da JVM e morre com ela.
     * Sem esta varredura, um restart no meio dos 5 segundos perderia o socorro em silêncio — que é
     * a classe exata de falha que a regra 2 existe para eliminar.
     */
    @Query("""
            select e from Emergency e
             where e.state = :estado and e.dispatchDueAt <= :limite
             order by e.dispatchDueAt asc
            """)
    List<Emergency> findVencidasParaDisparo(@Param("estado") EmergencyState estado,
                                            @Param("limite") Instant limite);

    /** Idem para o escalonamento: 60s sem confirmação não pode depender de a JVM ter sobrevivido. */
    @Query("""
            select e from Emergency e
             where e.state = :estado and e.escalateDueAt is not null and e.escalateDueAt <= :limite
             order by e.escalateDueAt asc
            """)
    List<Emergency> findVencidasParaEscalonamento(@Param("estado") EmergencyState estado,
                                                  @Param("limite") Instant limite);

    void deleteByHomeId(UUID homeId);
}
