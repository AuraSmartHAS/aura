package br.com.fiap.aura.service;

import br.com.fiap.aura.config.AuraProperties;
import br.com.fiap.aura.domain.Emergency;
import br.com.fiap.aura.domain.Home;
import br.com.fiap.aura.domain.HomeMember;
import br.com.fiap.aura.domain.Signal;
import br.com.fiap.aura.domain.UserAccount;
import br.com.fiap.aura.domain.enums.EmergencyChannel;
import br.com.fiap.aura.domain.enums.EmergencyState;
import br.com.fiap.aura.domain.enums.HomeMemberRole;
import br.com.fiap.aura.domain.enums.PushKind;
import br.com.fiap.aura.domain.enums.SignalSource;
import br.com.fiap.aura.domain.enums.SignalType;
import br.com.fiap.aura.repository.EmergencyRepository;
import br.com.fiap.aura.repository.HomeMemberRepository;
import br.com.fiap.aura.repository.HomeRepository;
import br.com.fiap.aura.repository.SignalRepository;
import br.com.fiap.aura.repository.UserAccountRepository;
import br.com.fiap.aura.security.AuthPrincipal;
import br.com.fiap.aura.web.dto.EmergencyDtos;
import br.com.fiap.aura.web.error.ApiException;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.lang.Nullable;
import org.springframework.scheduling.TaskScheduler;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/**
 * O caminho de socorro do AURA (C3). Antes desta classe o produto não tinha nenhum — nem botão, nem
 * comando de voz — num aplicativo cuja tese é prevenir queda.
 *
 * <h2>Se você está depurando isto às 2h da manhã, leia estes seis parágrafos primeiro</h2>
 *
 * <p><b>1. O AURA não é central de emergência.</b> Ele avisa um humano, rápido e de forma
 * verificável. Não promete resposta 24h, não chama ambulância, não substitui o 192. Quem liga é uma
 * pessoa. Se alguma linha aqui começar a prometer mais que isso, ela está errada.
 *
 * <p><b>2. A contagem de cancelamento mora aqui, não no aparelho.</b> Cronômetro de cliente morre
 * quando o telefone cai da mão, a tela apaga ou o app vai a segundo plano — exatamente o que
 * acontece com quem caiu. Então {@link #trigger} grava a emergência e devolve <i>na hora</i>, e o
 * disparo em T+5s é responsabilidade deste servidor. Perder o aparelho no meio da janela não perde
 * o socorro.
 *
 * <p><b>3. "Dentro da janela" é uma corrida, não uma conta de relógio.</b> Quem cancela vence se
 * chegar antes do disparador — ver {@link EmergencyRepository#compareAndSetState}. Comparar
 * {@code now < dispatchDueAt} teria uma fresta em que o cancelamento "dá certo" com o push já na
 * rua, e a Ana ficaria dirigindo enquanto o app diz "foi engano".
 *
 * <p><b>4. Duas redes de segurança, porque uma só falha em silêncio.</b> O disparo é agendado no
 * {@link TaskScheduler} (preciso, mas vive na memória da JVM) <i>e</i> varrido por
 * {@link #sweep()} a cada segundo (impreciso, mas sobrevive a restart). As duas chamam o mesmo
 * ponto idempotente. Se você removeu uma das duas, o socorro passou a depender de o processo não
 * reiniciar nos 5 segundos mais importantes do produto.
 *
 * <p><b>5. O aviso pode não ter saído, e a resposta diz isso.</b> Três causas — push simulado
 * (regra 1), casa sem aparelho registrado, disparo contido pela mitigação de abuso — produzem
 * {@code canPromiseAlert=false} com o motivo. A tela então troca o botão por uma ligação. Nunca,
 * em nenhum caminho, esta classe responde como se o aviso tivesse saído quando não saiu.
 *
 * <p><b>6. O corpo do push não carrega fator clínico.</b> Isso é decidido no
 * {@link NotificationService}, não aqui, de propósito: um lugar só.
 */
@Service
public class EmergencyService {

    private static final Logger log = LoggerFactory.getLogger(EmergencyService.class);

    /** Motivos de degradação — o mesmo vocabulário que a tela lê para decidir cair na ligação. */
    private static final String DEGRADED_SIMULATED = "simulated_transport";
    private static final String DEGRADED_NO_DEVICE = "no_registered_device";
    private static final String DEGRADED_THROTTLED = "throttled";

    private final EmergencyRepository emergencies;
    private final HomeRepository homes;
    private final HomeMemberRepository members;
    private final UserAccountRepository users;
    private final SignalRepository signals;
    private final NotificationService notifications;
    private final FcmService fcm;
    private final HomeService homeService;
    private final TaskScheduler scheduler;
    private final AuraProperties props;

    public EmergencyService(EmergencyRepository emergencies, HomeRepository homes,
                            HomeMemberRepository members, UserAccountRepository users,
                            SignalRepository signals, NotificationService notifications,
                            FcmService fcm, HomeService homeService, TaskScheduler scheduler,
                            AuraProperties props) {
        this.emergencies = emergencies;
        this.homes = homes;
        this.members = members;
        this.users = users;
        this.signals = signals;
        this.notifications = notifications;
        this.fcm = fcm;
        this.homeService = homeService;
        this.scheduler = scheduler;
        this.props = props;
    }

    // =================================================================================
    // 1. REGISTRO — o toque
    // =================================================================================

    /**
     * Registra o pedido de socorro e agenda o disparo. Responde <b>antes</b> de qualquer chamada de
     * rede: quem está no chão não pode esperar o Firebase para saber que foi ouvido.
     *
     * <p><b>Sem {@code @Transactional}, e é intencional.</b> A gravação da emergência e a do sinal
     * de auditoria são independentes de propósito: se o sinal falhar, a emergência <b>não</b> pode
     * ser desfeita junto. Falha de auditoria não pode custar um socorro — e a ordem garante que o
     * caso ruim seja "emergência sem sinal", nunca "sinal sem emergência".
     *
     * @param principal quem disparou, <b>ou {@code null}</b>: o SOS não fica atrás de login
     *                  (regra 3). Ver {@link #contidoPorAbuso} para a mitigação e o risco residual.
     */
    public EmergencyDtos.TriggerResponse trigger(@Nullable AuthPrincipal principal,
                                                 EmergencyDtos.TriggerRequest req) {
        // 404 e não 403: sem sessão não há o que autorizar, e "esta casa não existe" é a única
        // resposta honesta possível para um identificador que não bate
        Home home = homes.findById(req.homeId())
                .orElseThrow(() -> ApiException.notFound("Casa"));

        EmergencyChannel channel = req.channel() == null ? EmergencyChannel.TOUCH : req.channel();
        Instant agora = Instant.now();

        Optional<Emergency> jaAberta = emergenciaParaReaproveitar(home.getId(), agora);
        if (jaAberta.isPresent()) {
            // toque duplo acidental, ou tentativa de flood: devolve a MESMA emergência. Nada de
            // segunda linha, nada de segundo push — e sem 429, que num SOS seria pior que o abuso
            Emergency existente = jaAberta.get();
            log.info("SOS repetido na casa {} dentro de {}s — devolvendo a emergência {} em vez de criar outra",
                    home.getId(), props.sos().minIntervalSeconds(), existente.getId());
            return responseDoRegistro(existente, home, true);
        }

        boolean contido = contidoPorAbuso(principal, home.getId(), agora);
        int janela = props.sos().cancelWindowSeconds();

        Emergency emergencia = emergencies.save(Emergency.builder()
                .homeId(home.getId())
                .triggeredByUserId(principal == null ? null : principal.userId())
                .channel(channel)
                // contido nasce em estado terminal: o registro existe e é auditável, o push não sai
                .state(contido ? EmergencyState.THROTTLED : EmergencyState.WAITING_CANCEL)
                .createdAt(agora)
                .dispatchDueAt(agora.plusSeconds(janela))
                .stateChangedAt(agora)
                .transportReal(fcm.transportReal())
                .lat(home.getLat())
                .lng(home.getLng())
                .build());

        registraSinal(emergencia, channel, principal, contido);

        if (contido) {
            log.warn("SOS CONTIDO na casa {} — teto de {}/hora para disparo sem sessão atingido. "
                            + "Emergência {} gravada, nenhum push enviado; o cliente tem de cair na ligação.",
                    home.getId(), props.sos().maxPerHour(), emergencia.getId());
            return responseDoRegistro(emergencia, home, false);
        }

        agendaDisparo(emergencia.getId(), emergencia.getDispatchDueAt());
        log.info("SOS registrado na casa {} (emergência {}, canal {}, sessão {}) — disparo do servidor em {}",
                home.getId(), emergencia.getId(), channel.value(),
                principal == null ? "ausente" : "presente", emergencia.getDispatchDueAt());

        return responseDoRegistro(emergencia, home, false);
    }

    /**
     * Deduplicação: a mesma emergência serve o toque repetido.
     *
     * <p><b>O detalhe que não pode ser perdido em refatoração:</b> só reaproveitamos emergência
     * <b>aberta</b>. Se a última foi cancelada ("foi engano") ou confirmada, um toque novo tem de
     * criar emergência nova — mesmo três segundos depois. Reaproveitar uma cancelada engoliria um
     * pedido de socorro real com a desculpa de que houve outro parecido há pouco, e é o tipo de
     * "otimização" que mata alguém.
     */
    private Optional<Emergency> emergenciaParaReaproveitar(UUID homeId, Instant agora) {
        Instant limite = agora.minusSeconds(props.sos().minIntervalSeconds());
        return emergencies.findFirstByHomeIdOrderByCreatedAtDesc(homeId)
                .filter(e -> e.getState().aberta())
                .filter(e -> e.getCreatedAt().isAfter(limite));
    }

    /**
     * Mitigação de abuso do endpoint aberto (regra 3) e o <b>risco residual</b> dela, declarado.
     *
     * <h3>Por que o endpoint é aberto</h3>
     * A alternativa — exigir sessão — tem um modo de falha que mata: sessão expirada, a Maria no
     * chão do banheiro, e o socorro dependendo de uma senha que ela não vai digitar. Nenhuma
     * mitigação de spam compra esse risco.
     *
     * <h3>A mitigação de verdade é estrutural, não este contador</h3>
     * O que realmente contém o abuso é o que o contrato <b>não</b> aceita: a requisição não nomeia
     * destino nenhum. O aviso vai só para quem já está vinculado àquela casa em {@code home_members}
     * (C0). Logo não existe amplificação e não existe uso do AURA como encaminhador de notificação
     * para telefone arbitrário. O pior que alguém com um {@code homeId} válido consegue é fazer o
     * celular de uma família específica apitar — e {@code homeId} é UUIDv4, 122 bits, não enumerável.
     *
     * <h3>Os dois freios que existem, e a assimetria entre eles</h3>
     * <ol>
     *   <li><b>Deduplicação por janela mínima</b> ({@link #emergenciaParaReaproveitar}): é o freio
     *       principal e é <b>seguro</b>, porque nunca descarta nada — coalesce no pedido que já está
     *       aberto. Limita o volume a ~2 avisos/minuto por casa.</li>
     *   <li><b>Teto por hora</b>, este método: só se aplica a disparo <b>sem sessão</b>. Um disparo
     *       autenticado nunca é contido.</li>
     * </ol>
     *
     * <h3>Risco residual — leia antes de mudar os números</h3>
     * Quem tem o {@code homeId} pode gastar o teto e, por até uma hora, fazer os SOS <b>sem sessão</b>
     * daquela casa saírem contidos. Isso é uma negação de serviço sobre a função de segurança, e é
     * o preço de ter um teto. Três coisas o tornam aceitável, e todas as três precisam continuar
     * verdadeiras: <b>(a)</b> o registro é sempre gravado, então um SOS real nunca fica invisível;
     * <b>(b)</b> o disparo autenticado — o caminho normal, com sessão válida — passa por cima do
     * teto; <b>(c)</b> contido devolve {@code canPromiseAlert=false}, e a tela é obrigada a oferecer
     * a ligação telefônica, que é o mesmo caminho de degradação da regra 1. Se algum dia (c) deixar
     * de ser verdade na tela, este teto passa a ser um bug de segurança do paciente e deve ser
     * removido — nesta ordem: primeiro conserta a tela, depois se discute o teto.
     */
    private boolean contidoPorAbuso(@Nullable AuthPrincipal principal, UUID homeId, Instant agora) {
        if (principal != null) {
            return false;
        }
        long naUltimaHora = emergencies.countByHomeIdAndCreatedAtGreaterThanEqual(
                homeId, agora.minus(1, ChronoUnit.HOURS));
        return naUltimaHora >= props.sos().maxPerHour();
    }

    /**
     * Sinal de emergência gravado — <b>regra 5</b>: nenhum valor novo em {@link SignalType}.
     *
     * <p>Criar um {@code SignalType.EMERGENCY} é a armadilha: {@code Signal.type} é
     * {@code @Enumerated(STRING)}, o Hibernate gera <i>check constraint</i>, e {@code ddl-auto:
     * update} do perfil Postgres <b>não</b> altera constraint existente — quebraria em produção
     * passando 100% verde no H2, que é onde o CI roda. Então: tipo existente ({@code MOBILITY}, que
     * é a dimensão de queda) e o evento no campo JSON, como o projeto já faz em todo lugar.
     *
     * <p><b>Efeito colateral verificado:</b> {@code event: "sos"} não corresponde a fator nenhum em
     * {@code scoring-weights.yml}, então este sinal não move o escore. Se algum dia alguém quiser
     * que mova, é uma linha de YAML — e uma decisão de produto, não um acidente.
     *
     * <p><b>Sem gate de consentimento, e a base legal é nominal:</b> LGPD art. 7º, IV e art. 11,
     * §1º — proteção da vida ou da incolumidade física do titular dispensa o consentimento. É por
     * isso que a gravação vai direto ao repositório em vez de passar pelo {@code SignalService}, que
     * (corretamente, para todo o resto) exige o aceite antes de gravar dado de saúde.
     */
    private void registraSinal(Emergency emergencia, EmergencyChannel channel,
                               @Nullable AuthPrincipal principal, boolean contido) {
        Map<String, Object> valor = new LinkedHashMap<>();
        valor.put("event", "sos");
        valor.put("channel", channel.value());
        valor.put("emergencyId", emergencia.getId().toString());
        valor.put("authenticated", principal != null);
        if (contido) {
            valor.put("throttled", true);
        }
        try {
            signals.save(Signal.builder()
                    .homeId(emergencia.getHomeId())
                    .type(SignalType.MOBILITY)
                    // voz vem da tool do agente; toque é interação com o app, não auto-relato falado
                    .source(channel == EmergencyChannel.VOICE ? SignalSource.VOICE : SignalSource.USAGE)
                    .value(valor)
                    .capturedAt(emergencia.getCreatedAt())
                    .build());
        } catch (RuntimeException e) {
            // auditoria não derruba socorro: a emergência já está gravada e o disparo já está agendado
            log.error("Falha ao gravar o sinal da emergência {} — o socorro segue, o histórico perde a linha",
                    emergencia.getId(), e);
        }
    }

    // =================================================================================
    // 2. CANCELAMENTO — "foi engano"
    // =================================================================================

    /**
     * Cancela dentro da janela. Dois desfechos, e a diferença entre eles é quem chegou primeiro:
     *
     * <ul>
     *   <li><b>Dentro</b> ({@code withinWindow=true}): o aviso original <b>não sai</b>. Ainda assim
     *       o segundo aviso ("foi engano, a Maria cancelou") vai, porque a cuidadora tem direito de
     *       saber que o botão de pânico foi apertado na casa da mãe dela — um SOS silencioso seria
     *       pior, inclusive para o caso em que quem cancelou não foi a paciente.</li>
     *   <li><b>Fora</b> ({@code withinWindow=false}): <b>nada é desfeito.</b> O estado permanece
     *       {@code DISPATCHED}/{@code ESCALATED}, {@code dispatchedAt} continua lá, e o histórico
     *       continua dizendo que o aviso saiu. O que muda é que a retração é enviada — a Ana está
     *       na rua e precisa saber que pode voltar.</li>
     * </ul>
     *
     * <p>Sem autenticação, pelo mesmo motivo do disparo: se a Maria conseguiu apertar o SOS sem
     * sessão, ela tem de conseguir dizer "foi engano" sem sessão. O identificador da emergência é um
     * UUIDv4 que só o aparelho que disparou e os aparelhos que receberam o push conhecem, e cancelar
     * <b>nunca é silencioso</b> — sempre gera a retração —, então um cancelamento indevido aparece.
     */
    public EmergencyDtos.CancelResponse cancel(UUID emergencyId) {
        Emergency emergencia = carrega(emergencyId);
        Instant agora = Instant.now();

        boolean dentroDaJanela = emergencies.compareAndSetState(
                emergencyId, EmergencyState.WAITING_CANCEL, EmergencyState.CANCELLED, agora) == 1;

        Emergency atual = carrega(emergencyId);

        if (!dentroDaJanela && atual.getState() == EmergencyState.CANCELLED) {
            // segundo toque no "foi engano": idempotente, sem uma segunda retração
            log.info("Cancelamento repetido da emergência {} — nada a fazer", emergencyId);
            return respostaDeCancelamento(atual, true, emergencia.getDispatchedAt() != null);
        }
        if (!dentroDaJanela && !atual.getState().aberta()) {
            // contida ou já encerrada: não há aviso na rua para retratar
            log.info("Cancelamento da emergência {} em estado {} — nada a retratar",
                    emergencyId, atual.getState().value());
            return respostaDeCancelamento(atual, false, atual.getDispatchedAt() != null);
        }

        boolean avisoJaSaiu = atual.getDispatchedAt() != null;
        atual.setCancelledAt(agora);

        Home home = homes.findById(atual.getHomeId()).orElse(null);
        int retratados = home == null ? 0
                : envia(PushKind.SOS_CANCELLED, home, atual, destinatariosComAparelho(home));
        atual.setRetractionSent(retratados > 0);
        emergencies.save(atual);

        log.info("Emergência {} cancelada ({}) — aviso original havia saído: {}; retração em {} aparelho(s)",
                emergencyId, dentroDaJanela ? "dentro da janela" : "FORA da janela, nada desfeito",
                avisoJaSaiu, retratados);

        return respostaDeCancelamento(atual, dentroDaJanela, avisoJaSaiu);
    }

    // =================================================================================
    // 3. CONFIRMAÇÃO — "estou indo"
    // =================================================================================

    /**
     * "Estou indo". É o que fecha o loop: sem isto o SOS é só disparo, e o escalonamento nunca para.
     *
     * <p><b>Esta rota exige sessão, e é a única do fluxo que exige.</b> A assimetria é deliberada:
     * quem confirma está de pé, com o celular na mão, chegando pelo push — não no chão do banheiro.
     * E a confirmação precisa de autor: dizer à Maria "alguém está indo" sem saber quem é pior que
     * não dizer nada. O acesso é o mesmo do resto da casa ({@code requireAccess}), então um estranho
     * não confirma socorro de família alheia.
     */
    public EmergencyDtos.AckResponse acknowledge(AuthPrincipal principal, UUID emergencyId) {
        Emergency emergencia = carrega(emergencyId);
        homeService.requireAccess(principal, emergencia.getHomeId());

        Instant agora = Instant.now();
        EmergencyState anterior = emergencia.getState();

        // aceita confirmação de qualquer estado aberto, inclusive antes do disparo: quem diz "estou
        // indo" nunca deve ouvir "espere 5 segundos"
        boolean confirmou = false;
        for (EmergencyState esperado : List.of(EmergencyState.WAITING_CANCEL,
                                              EmergencyState.DISPATCHED,
                                              EmergencyState.ESCALATED)) {
            if (emergencies.compareAndSetState(emergencyId, esperado,
                    EmergencyState.ACKNOWLEDGED, agora) == 1) {
                confirmou = true;
                anterior = esperado;
                break;
            }
        }

        Emergency atual = carrega(emergencyId);
        if (!confirmou) {
            if (atual.getState() == EmergencyState.ACKNOWLEDGED) {
                // dois cuidadores tocando "estou indo" quase juntos: o primeiro é o autor, e o
                // segundo recebe sucesso — 409 aqui só assustaria quem está tentando ajudar
                return respostaDeConfirmacao(atual, false);
            }
            throw ApiException.conflict(
                    "Esta emergência já foi encerrada (%s) e não aceita confirmação."
                            .formatted(atual.getState().value()));
        }

        atual.setAcknowledgedAt(agora);
        atual.setAcknowledgedByUserId(principal.userId());
        emergencies.save(atual);

        log.info("Emergência {} confirmada por {} — escalonamento interrompido (estava em {})",
                emergencyId, principal.userId(), anterior.value());

        // escalonamento só era pendente se o aviso já havia saído e ninguém tinha respondido
        return respostaDeConfirmacao(atual, anterior == EmergencyState.DISPATCHED);
    }

    // =================================================================================
    // 4. ESTADO — a tela de pós-pedido
    // =================================================================================

    /** Estado do aviso, sem sessão e sem nada clínico — ver {@link EmergencyDtos.StatusResponse}. */
    public EmergencyDtos.StatusResponse status(UUID emergencyId) {
        Emergency e = carrega(emergencyId);
        List<UserAccount> destinatarios = homes.findById(e.getHomeId())
                .map(this::destinatariosComAparelho).orElse(List.of());
        String contato = destinatarios.stream().findFirst()
                .map(UserAccount::getName).map(EmergencyService::primeiroNome).orElse(null);
        String quemConfirmou = nomeDe(e.getAcknowledgedByUserId());
        String degradado = degradedReason(e, destinatarios.size());
        return new EmergencyDtos.StatusResponse(
                e.getId(), e.getState(), e.getCreatedAt(), e.getDispatchDueAt(), e.getDispatchedAt(),
                e.getAcknowledgedAt(), quemConfirmou,
                e.getEscalatedAt() != null, e.getNotifiedCount(),
                e.isTransportReal(), !e.isTransportReal(),
                degradado == null, degradado,
                falaDoEstado(e, degradado, quemConfirmou, contato));
    }

    // =================================================================================
    // 5. DISPARO E ESCALONAMENTO — o que o SERVIDOR faz sozinho
    // =================================================================================

    /**
     * Dispara o aviso se a janela de cancelamento fechou sem cancelamento. <b>Idempotente</b>: pode
     * ser chamado à vontade pelo agendamento pontual, pelo varredor de recuperação e pelos testes —
     * quem não vence o {@code compareAndSetState} sai sem fazer nada.
     *
     * <p>É público de propósito: é este o ponto de entrada que o teste exercita para provar o
     * comportamento de T+5s sem dormir 5 segundos na suíte. O teste chama <b>exatamente</b> o que o
     * cronômetro chama, e não um caminho paralelo escrito para o teste.
     *
     * <p>Nenhuma transação envolvendo a chamada ao Firebase: a rede fica fora do banco, senão uma
     * conexão do pool ficaria presa esperando o FCM.
     */
    public void dispatchIfDue(UUID emergencyId) {
        Instant agora = Instant.now();
        if (emergencies.compareAndSetState(emergencyId, EmergencyState.WAITING_CANCEL,
                EmergencyState.DISPATCHED, agora) != 1) {
            return;   // cancelada dentro da janela, ou outro chamador já disparou
        }

        Emergency emergencia = carrega(emergencyId);
        Home home = homes.findById(emergencia.getHomeId()).orElse(null);
        if (home == null) {
            log.error("Emergência {} aponta para casa {} que não existe mais — nada a avisar",
                    emergencyId, emergencia.getHomeId());
            return;
        }

        List<UserAccount> comAparelho = destinatariosComAparelho(home);
        // o principal é o primeiro contato COM aparelho, não necessariamente o dono: dono sem token
        // registrado não pode consumir o disparo principal e deixar o aviso sem ninguém
        List<UserAccount> principal = comAparelho.isEmpty() ? List.of() : List.of(comAparelho.get(0));

        emergencia.setTransportReal(fcm.transportReal());
        int enviados = envia(PushKind.SOS, home, emergencia, principal);

        emergencia.setDispatchedAt(agora);
        emergencia.setNotifiedCount(enviados);
        emergencia.setEscalateDueAt(agora.plusSeconds(props.sos().escalateAfterSeconds()));
        emergencies.save(emergencia);

        if (enviados == 0) {
            // 422 seria o erro certo pelo livro e o errado pela pessoa no chão: o registro fica, o
            // estado avança, e é a resposta da API que diz que não há como prometer entrega
            log.error("Emergência {} da casa {} disparada SEM DESTINATÁRIO — nenhum aparelho registrado. "
                            + "O cliente precisa oferecer ligação telefônica.",
                    emergencyId, home.getId());
        } else if (!emergencia.isTransportReal()) {
            log.error("Emergência {} da casa {} disparada em TRANSPORTE SIMULADO — nada saiu deste "
                            + "servidor. Isto NÃO é um SOS entregue.", emergencyId, home.getId());
        }

        agendaEscalonamento(emergencyId, emergencia.getEscalateDueAt());
    }

    /**
     * Sem confirmação em 60s, o aviso vai para os <b>demais</b> membros da casa.
     *
     * <p>Isto só é possível por causa do C0: até o vínculo {@code home_members} existir, a casa
     * tinha um único {@code ownerUserId} e "avisar os outros cuidadores" não tinha modelo de dados.
     *
     * <p>Idempotente pelo mesmo {@code compareAndSetState}. Se alguém confirmou nesse meio-tempo, o
     * estado já é {@code ACKNOWLEDGED} e este método sai sem enviar nada — que é o ponto todo de
     * existir confirmação.
     */
    public void escalateIfDue(UUID emergencyId) {
        Instant agora = Instant.now();
        if (emergencies.compareAndSetState(emergencyId, EmergencyState.DISPATCHED,
                EmergencyState.ESCALATED, agora) != 1) {
            return;   // confirmada, cancelada, ou já escalada
        }

        Emergency emergencia = carrega(emergencyId);
        Home home = homes.findById(emergencia.getHomeId()).orElse(null);
        if (home == null) {
            return;
        }

        List<UserAccount> comAparelho = destinatariosComAparelho(home);
        // pula o primeiro: ele já recebeu o aviso original e não precisa do mesmo texto duas vezes
        List<UserAccount> demais = comAparelho.size() <= 1 ? List.of()
                : comAparelho.subList(1, comAparelho.size());

        int enviados = envia(PushKind.SOS_ESCALATED, home, emergencia, demais);
        emergencia.setEscalatedAt(agora);
        emergencia.setEscalatedCount(enviados);
        emergencies.save(emergencia);

        log.warn("Emergência {} da casa {} ESCALADA sem confirmação em {}s — {} outro(s) membro(s) avisado(s)",
                emergencyId, home.getId(), props.sos().escalateAfterSeconds(), enviados);
    }

    /**
     * Rede de segurança do agendamento em memória. Roda a cada segundo e é quase sempre um no-op.
     *
     * <p><b>Não remova por parecer redundante.</b> {@link TaskScheduler#schedule} vive no heap desta
     * JVM: um deploy, um OOM ou um restart dentro dos 5 segundos da janela apagaria o disparo
     * agendado e o socorro sumiria em silêncio — a classe exata de falha que a regra 2 existe para
     * eliminar. O agendamento pontual dá precisão; esta varredura dá durabilidade.
     */
    @Scheduled(fixedDelayString = "${aura.sos.sweep-millis:1000}")
    public void sweep() {
        Instant agora = Instant.now();
        try {
            for (Emergency e : emergencies.findVencidasParaDisparo(EmergencyState.WAITING_CANCEL, agora)) {
                log.warn("Varredor recuperou o disparo da emergência {} (vencido em {}) — "
                        + "o agendamento em memória foi perdido", e.getId(), e.getDispatchDueAt());
                dispatchIfDue(e.getId());
            }
            for (Emergency e : emergencies.findVencidasParaEscalonamento(EmergencyState.DISPATCHED, agora)) {
                escalateIfDue(e.getId());
            }
        } catch (RuntimeException ex) {
            // exceção que escapa de @Scheduled derruba a próxima execução: aqui ela morre no log
            log.error("Falha na varredura de emergências — a próxima execução tenta de novo", ex);
        }
    }

    // =================================================================================
    // Agendamento
    // =================================================================================

    private void agendaDisparo(UUID emergencyId, Instant quando) {
        agenda("disparo", emergencyId, quando, () -> dispatchIfDue(emergencyId));
    }

    private void agendaEscalonamento(UUID emergencyId, Instant quando) {
        agenda("escalonamento", emergencyId, quando, () -> escalateIfDue(emergencyId));
    }

    /**
     * Agenda a tarefa e <b>engole a falha de agendamento</b> em vez de propagá-la ao chamador.
     *
     * <p>Parece errado e não é: se o {@code TaskScheduler} estiver saturado ou em desligamento, o
     * pior desfecho possível é o registro do SOS falhar na cara de quem está pedindo ajuda. Aqui a
     * emergência já está gravada com {@code dispatchDueAt} no passado, então o {@link #sweep()}
     * pega em até um segundo. Falhar o agendamento custa 1s; falhar o registro custa o socorro.
     */
    private void agenda(String tarefa, UUID emergencyId, Instant quando, Runnable acao) {
        try {
            scheduler.schedule(() -> {
                try {
                    acao.run();
                } catch (RuntimeException e) {
                    log.error("Falha no {} agendado da emergência {} — o varredor tentará de novo",
                            tarefa, emergencyId, e);
                }
            }, quando);
        } catch (RuntimeException e) {
            log.error("Não foi possível agendar o {} da emergência {}; o varredor assume em até {}ms",
                    tarefa, emergencyId, props.sos().sweepMillis(), e);
        }
    }

    // =================================================================================
    // Destinatários
    // =================================================================================

    /**
     * Contatos de socorro da casa, em ordem de acionamento: o dono primeiro, depois os vínculos por
     * antiguidade. <b>Só quem tem aparelho registrado entra</b> — sem token não há para onde mandar.
     *
     * <p>A <b>paciente é excluída</b>: ela é quem pediu ajuda, não quem socorre. Sem esta linha, o
     * escalonamento mandaria "a Maria pediu ajuda" para o celular da Maria, que já está no chão com
     * ela.
     *
     * <p>Esta lista é toda a superfície de destino do SOS, e é a razão pela qual o endpoint aberto
     * não é um vetor de spam: não existe caminho para um destino que não esteja aqui.
     */
    private List<UserAccount> destinatariosComAparelho(Home home) {
        Map<UUID, UserAccount> ordenados = new LinkedHashMap<>();
        Set<UUID> excluidos = new LinkedHashSet<>();

        for (HomeMember m : members.findByHomeIdOrderByCreatedAt(home.getId())) {
            if (m.getRole() == HomeMemberRole.PACIENTE) {
                excluidos.add(m.getUserId());
            }
        }

        users.findById(home.getOwnerUserId())
                .filter(u -> !excluidos.contains(u.getId()))
                .ifPresent(u -> ordenados.put(u.getId(), u));

        for (HomeMember m : members.findByHomeIdOrderByCreatedAt(home.getId())) {
            if (excluidos.contains(m.getUserId()) || ordenados.containsKey(m.getUserId())) {
                continue;
            }
            users.findById(m.getUserId()).ifPresent(u -> ordenados.put(u.getId(), u));
        }

        return ordenados.values().stream()
                .filter(u -> u.getFcmToken() != null && !u.getFcmToken().isBlank())
                .toList();
    }

    /**
     * Envia para cada aparelho e devolve quantos aceitaram. <b>Falha de um não interrompe os
     * outros</b>: um token revogado da Ana não pode impedir o aviso de chegar no celular do filho.
     */
    private int envia(PushKind kind, Home home, Emergency emergencia, List<UserAccount> destinatarios) {
        int enviados = 0;
        for (UserAccount destinatario : destinatarios) {
            try {
                notifications.sendSos(kind, home, emergencia, destinatario.getFcmToken());
                enviados++;
            } catch (RuntimeException e) {
                log.error("Aviso {} da emergência {} recusado para o usuário {}: {}",
                        kind.value(), emergencia.getId(), destinatario.getId(), e.getMessage());
            }
        }
        return enviados;
    }

    // =================================================================================
    // Respostas
    // =================================================================================

    private Emergency carrega(UUID emergencyId) {
        return emergencies.findById(emergencyId)
                .orElseThrow(() -> ApiException.notFound("Emergência"));
    }

    private EmergencyDtos.TriggerResponse responseDoRegistro(Emergency e, Home home, boolean deduplicada) {
        List<UserAccount> destinatarios = destinatariosComAparelho(home);
        String contato = destinatarios.stream().findFirst()
                .map(UserAccount::getName).map(EmergencyService::primeiroNome).orElse(null);
        String degradado = degradedReason(e, destinatarios.size());
        return new EmergencyDtos.TriggerResponse(
                e.getId(), e.getHomeId(), e.getState(), e.getCreatedAt(), e.getDispatchDueAt(),
                props.sos().cancelWindowSeconds(), props.sos().escalateAfterSeconds(),
                fcm.transportReal(), !fcm.transportReal(), destinatarios.size(), contato,
                e.getState() == EmergencyState.THROTTLED, deduplicada,
                degradado == null, degradado,
                falaDoEstado(e, degradado, null, contato));
    }

    private EmergencyDtos.CancelResponse respostaDeCancelamento(Emergency e, boolean dentroDaJanela,
                                                                boolean avisoJaSaiu) {
        String fala = dentroDaJanela
                ? "Tudo bem, cancelei o pedido de ajuda. Fico aqui com você."
                : "Já tinha avisado, então mandei um recado dizendo que foi engano.";
        return new EmergencyDtos.CancelResponse(e.getId(), e.getState(), dentroDaJanela,
                avisoJaSaiu, e.isRetractionSent(), !e.isTransportReal(), fala);
    }

    private EmergencyDtos.AckResponse respostaDeConfirmacao(Emergency e, boolean escalonamentoParado) {
        String nome = nomeDe(e.getAcknowledgedByUserId());
        return new EmergencyDtos.AckResponse(e.getId(), e.getState(), e.getAcknowledgedAt(), nome,
                escalonamentoParado,
                nome == null ? "Alguém viu e disse que está indo."
                             : "A %s viu e disse que está indo.".formatted(nome));
    }

    /**
     * A pergunta única: o servidor pode prometer que o aviso saiu? Nulo = sim.
     *
     * <p>A ordem importa e não é arbitrária — é da causa mais fundamental para a mais circunstancial.
     * Sem transporte real nada sai, ponto; então não faz diferença quantos aparelhos existem.
     */
    private String degradedReason(Emergency e, int aparelhosRegistrados) {
        if (e.getState() == EmergencyState.THROTTLED) {
            return DEGRADED_THROTTLED;
        }
        if (!fcm.transportReal()) {
            return DEGRADED_SIMULATED;
        }
        if (aparelhosRegistrados == 0) {
            return DEGRADED_NO_DEVICE;
        }
        return null;
    }

    /**
     * Os estados falados da regra 4, ditos pelo servidor.
     *
     * <p><b>Por que a frase vem daqui e não da tela:</b> a versão 1 do produto tinha a voz dizendo
     * "avisei a Ana" sem que nenhuma notificação saísse do aparelho. Com a frase nascendo do mesmo
     * lugar que conhece {@code transportReal}, {@code notifiedCount} e o estado, é impossível a fala
     * prometer mais do que o servidor sabe. A tela pode trocar a redação; não pode aumentar a
     * promessa.
     */
    private String falaDoEstado(Emergency e, @Nullable String degradado,
                                @Nullable String quemConfirmou, @Nullable String contato) {
        String alvo = contato == null ? "sua cuidadora" : "a " + contato;
        if (degradado != null && e.getState() != EmergencyState.CANCELLED) {
            return "Não consigo avisar %s daqui. Toque no botão grande para ligar para ela."
                    .formatted(alvo);
        }
        return switch (e.getState()) {
            case WAITING_CANCEL -> "Estou avisando %s.".formatted(alvo);
            case DISPATCHED, ESCALATED -> e.getNotifiedCount() == 0
                    ? "Não consegui avisar %s. Toque no botão grande para ligar para ela.".formatted(alvo)
                    // "Saiu", não "chegou": DISPATCHED confirma a entrega ao transporte,
                    // não ao aparelho — a voz nunca afirma o que o sistema não sabe.
                    : "Pronto. O aviso saiu para o celular %s às %s. Fico aqui com você."
                            .formatted(alvo.replaceFirst("^a ", "da "), horaDe(e.getDispatchedAt()));
            case ACKNOWLEDGED -> quemConfirmou == null
                    ? "Alguém viu e disse que está indo."
                    : "A %s viu e disse que está indo.".formatted(quemConfirmou);
            case CANCELLED -> "Tudo bem, cancelei o pedido de ajuda. Fico aqui com você.";
            case THROTTLED -> "Não consigo avisar %s daqui. Toque no botão grande para ligar para ela."
                    .formatted(alvo);
        };
    }

    /** "às 14h32" — o formato que o assistente fala, no fuso de São Paulo. */
    private static String horaDe(@Nullable Instant instante) {
        if (instante == null) {
            return "agora";
        }
        LocalTime hora = instante.atZone(ZoneId.of("America/Sao_Paulo")).toLocalTime();
        return "%dh%02d".formatted(hora.getHour(), hora.getMinute());
    }

    private String nomeDe(@Nullable UUID userId) {
        return userId == null ? null
                : users.findById(userId).map(UserAccount::getName).map(EmergencyService::primeiroNome).orElse(null);
    }

    /** "Ana (cuidadora)" vira "Ana": o assistente não fala parênteses. */
    private static String primeiroNome(@Nullable String nome) {
        if (nome == null || nome.isBlank()) {
            return null;
        }
        String limpo = nome.trim().split("\\s+")[0];
        return limpo.isBlank() ? null : limpo;
    }
}
