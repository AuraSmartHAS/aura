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
     * <p>As transições do {@code EmergencyService} usam as variantes abaixo
     * ({@link #iniciaDisparo}, {@link #cancelaNaJanela}, {@link #confirma},
     * {@link #iniciaEscalonamento}): a mesma trava, mas com os dados da transição gravados no
     * <b>mesmo</b> {@code UPDATE}, para que nenhum leitor veja o estado novo sem eles.
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

    /**
     * O CAS do <b>disparo</b>: a mesma trava de {@link #compareAndSetState}, mas gravando no mesmo
     * {@code UPDATE} tudo o que o disparo sabe <i>antes</i> da rede — o instante, o prazo do
     * escalonamento, o transporte — e marcando {@code notifiedCount} como
     * {@link Emergency#ENVIO_EM_ANDAMENTO}.
     *
     * <p><b>Por que num {@code UPDATE} só:</b> a versão anterior virava o estado para
     * {@code DISPATCHED} e só depois do push gravava {@code dispatchedAt} e {@code notifiedCount}.
     * Cada chamada de repositório commita sozinha (o disparo não tem transação, de propósito, para
     * não segurar conexão durante o FCM), então quem lesse no meio via {@code dispatched} com
     * {@code dispatchedAt} nulo e zero aparelhos — e o servidor dizia "não consegui avisar a Ana"
     * enquanto o aviso ainda estava saindo. Aqui nenhum leitor vê estado sem os dados dele.
     *
     * @return 1 se este chamador venceu e deve enviar, 0 se cancelaram ou outro já disparou
     */
    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update Emergency e
               set e.state = br.com.fiap.aura.domain.enums.EmergencyState.DISPATCHED,
                   e.stateChangedAt = :agora, e.dispatchedAt = :agora,
                   e.escalateDueAt = :escalarEm, e.transportReal = :transportReal,
                   e.notifiedCount = -1
             where e.id = :id and e.state = br.com.fiap.aura.domain.enums.EmergencyState.WAITING_CANCEL
            """)
    int iniciaDisparo(@Param("id") UUID id,
                      @Param("agora") Instant agora,
                      @Param("escalarEm") Instant escalarEm,
                      @Param("transportReal") boolean transportReal);

    /**
     * Resultado do push principal. Só a coluna do resultado, nunca a entidade inteira: um
     * {@code save} da entidade carregada antes do envio regravaria o estado antigo por cima de um
     * "estou indo" ou de uma escalada que aconteceu enquanto o FCM respondia.
     */
    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update Emergency e set e.notifiedCount = :enviados
             where e.id = :id and e.notifiedCount = -1
            """)
    int registraResultadoDoDisparo(@Param("id") UUID id, @Param("enviados") int enviados);

    /** CAS do escalonamento, com {@code escalatedAt} no mesmo {@code UPDATE} do estado. */
    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update Emergency e
               set e.state = br.com.fiap.aura.domain.enums.EmergencyState.ESCALATED,
                   e.stateChangedAt = :agora, e.escalatedAt = :agora
             where e.id = :id and e.state = br.com.fiap.aura.domain.enums.EmergencyState.DISPATCHED
            """)
    int iniciaEscalonamento(@Param("id") UUID id, @Param("agora") Instant agora);

    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update Emergency e set e.escalatedCount = :enviados where e.id = :id")
    int registraResultadoDoEscalonamento(@Param("id") UUID id, @Param("enviados") int enviados);

    /** CAS da confirmação: estado, instante e autor no mesmo {@code UPDATE}. */
    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update Emergency e
               set e.state = br.com.fiap.aura.domain.enums.EmergencyState.ACKNOWLEDGED,
                   e.stateChangedAt = :agora, e.acknowledgedAt = :agora,
                   e.acknowledgedByUserId = :autor
             where e.id = :id and e.state = :esperado
            """)
    int confirma(@Param("id") UUID id,
                 @Param("esperado") EmergencyState esperado,
                 @Param("agora") Instant agora,
                 @Param("autor") UUID autor);

    /** CAS do cancelamento dentro da janela, com {@code cancelledAt} no mesmo {@code UPDATE}. */
    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("""
            update Emergency e
               set e.state = br.com.fiap.aura.domain.enums.EmergencyState.CANCELLED,
                   e.stateChangedAt = :agora, e.cancelledAt = :agora
             where e.id = :id and e.state = br.com.fiap.aura.domain.enums.EmergencyState.WAITING_CANCEL
            """)
    int cancelaNaJanela(@Param("id") UUID id, @Param("agora") Instant agora);

    /** Cancelamento fora da janela: o estado não muda (nada é desfeito), só o carimbo. */
    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update Emergency e set e.cancelledAt = :agora where e.id = :id")
    int registraCancelamentoForaDaJanela(@Param("id") UUID id, @Param("agora") Instant agora);

    @Transactional
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update Emergency e set e.retractionSent = :enviada where e.id = :id")
    int registraRetracao(@Param("id") UUID id, @Param("enviada") boolean enviada);

    /** A última emergência da casa — base da deduplicação de toque repetido. */
    Optional<Emergency> findFirstByHomeIdOrderByCreatedAtDesc(UUID homeId);

    /**
     * A emergência mais recente da casa entre os estados dados. Filtrar no banco (e não "pegar a última
     * e olhar o estado") importa: se a mais nova foi cancelada e uma anterior segue aberta, a família
     * ainda precisa vê-la.
     */
    Optional<Emergency> findFirstByHomeIdAndStateInOrderByCreatedAtDesc(
            UUID homeId, java.util.Collection<EmergencyState> states);

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

    /**
     * Exclusão de conta (LGPD): o SOS que a pessoa disparou ou confirmou numa casa que não é dela
     * continua sendo registro do dono da casa; só o vínculo com quem saiu é apagado. Nulo aqui passa
     * a significar também "titular excluído", e não apenas "SOS sem sessão". É a regra do
     * {@code ON DELETE SET NULL} do esquema Oracle, aplicada no Java para valer em todo banco.
     */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update Emergency e set e.triggeredByUserId = null where e.triggeredByUserId = :userId")
    int detachTriggeredBy(@Param("userId") UUID userId);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update Emergency e set e.acknowledgedByUserId = null where e.acknowledgedByUserId = :userId")
    int detachAcknowledgedBy(@Param("userId") UUID userId);
}
