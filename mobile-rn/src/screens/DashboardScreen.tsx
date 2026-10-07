import { useFocusEffect } from '@react-navigation/native';
import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Image,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { api, isSessionExpired, SESSION_EXPIRED_MESSAGE, type ActiveEmergency, type CareSignal, type Home, type MedicationRecord, type Score } from '../api';
import AuraButton from '../components/AuraButton';
import { ConnectionNotice, MedicationsTodayCard, SosAlertCard, TimelineCard } from '../components/TodayCards';
import {
  careAgo,
  careClock,
  emergencyOutcome,
  emergencyReadIsStale,
  firstName,
  isOpenEmergency,
  medicationsToday,
  nextEmergencyStep,
  startOfToday,
  startOfYesterday,
  timeline,
} from '../careToday';
import { pesoBr } from '../format';
import type { ScreenProps } from '../navigation';
import { fontFamily, levelColor, radius, spacing, theme } from '../theme';

type Props = ScreenProps<'Dashboard'>;

const dimensionLabels: Record<string, string> = {
  mobility: 'Mobilidade',
  sleep: 'Sono',
  cognition: 'Cognição',
  environment: 'Ambiente',
};

/** O nível fala com a família: estado da casa, não nota de prova — sem sigla, sem percentual. */
const levelLabels: Record<string, string> = {
  low: 'Tudo certo',
  medium: 'Atenção',
  high: 'Risco alto',
};

/** De quanto em quanto tempo se pergunta ao servidor por SOS e sinais novos (não há push nesta versão). */
const POLL_MS = 5000;
/** O desfecho do SOS (confirmado, cancelado) fica na tela por um instante em vez de sumir no primeiro polling. */
const FINAL_LINGER_MS = 45_000;
/** Falhas seguidas do polling a partir das quais a tela avisa que o que mostra pode estar velho. */
const STALE_AFTER_FAILURES = 2;

/**
 * Painel da cuidadora: o dia da Maria (remédios, o que ela disse e fez, SOS em aberto)
 * e, abaixo, o risco por dimensão — sempre com os fatores que explicam o número.
 */
export default function DashboardScreen({ navigation }: Props) {
  const [home, setHome] = useState<Home | null>(null);
  const [scores, setScores] = useState<Score[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [medications, setMedications] = useState<MedicationRecord[]>([]);
  const [signals, setSignals] = useState<CareSignal[]>([]);
  /** Confirmações de dose (type=adherence), em chamada PRÓPRIA: o status de dose não pode depender de a
   *  confirmação caber entre os N sinais mais novos, que leituras do relógio enchem. */
  const [adherence, setAdherence] = useState<CareSignal[]>([]);
  const [emergency, setEmergency] = useState<ActiveEmergency | null>(null);
  const [acknowledging, setAcknowledging] = useState(false);
  const [acknowledgeFailed, setAcknowledgeFailed] = useState(false);
  const [now, setNow] = useState(() => new Date());
  // Cada bloco secundário diz se CARREGOU: lista vazia por falha não é lista vazia de verdade.
  const [scoresLoaded, setScoresLoaded] = useState(true);
  const [sessionExpired, setSessionExpired] = useState(false);
  const [medicationsLoaded, setMedicationsLoaded] = useState(true);
  const [signalsLoaded, setSignalsLoaded] = useState(true);
  const [emergencyKnown, setEmergencyKnown] = useState(true);
  const [staleSince, setStaleSince] = useState<Date | null>(null);
  const [lastSync, setLastSync] = useState<Date | null>(null);
  const resolvedAt = useRef<number | null>(null);
  const failures = useRef(0);
  const emergencyRef = useRef<ActiveEmergency | null>(null);
  emergencyRef.current = emergency;
  const medicationsLoadedRef = useRef(true);
  medicationsLoadedRef.current = medicationsLoaded;
  const homeId = home?.id ?? null;
  // A tela pode ser desmontada com uma chamada em voo: não se atualiza estado de tela morta.
  const mounted = useRef(true);
  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);
  // Sobe a cada transição local do "estou indo". Um poll que COMEÇOU antes dela traz uma leitura
  // anterior à confirmação: aplicá-la faria a faixa voltar a "pediu ajuda" com o botão de novo,
  // negando uma confirmação que o servidor já registrou.
  const ackEpoch = useRef(0);
  const acknowledgingRef = useRef(false);

  const load = useCallback(async () => {
    setError(null);
    try {
      const homes = await api.homes();
      if (homes.length === 0) {
        setError('Nenhuma casa cadastrada nesta conta.');
        setLoading(false);
        return;
      }
      setHome(homes[0]);
      // Tudo o que vem depois da casa é "o que der": uma chamada que falha não derruba o painel —
      // mas a falha é DITA (cada bloco diz se carregou), nunca disfarçada de lista vazia.
      const [scoreRes, meds, sigTimeline, sigAdherence, sos] = await Promise.allSettled([
        api.latestScores(homes[0].id),
        api.medications(homes[0].id),
        api.signals(homes[0].id, startOfYesterday(new Date())),
        api.signals(homes[0].id, startOfToday(new Date()), 200, 'adherence'),
        api.activeEmergency(homes[0].id),
      ]);
      // As duas leituras de sinais precisam vir para o dia ser afirmável.
      const sig = sigTimeline.status === 'fulfilled' && sigAdherence.status === 'fulfilled' ? sigTimeline : null;
      if (!mounted.current) return;
      if ([scoreRes, meds, sigTimeline, sigAdherence, sos].some((r) => r.status === 'rejected' && isSessionExpired(r.reason))) {
        setSessionExpired(true);
      }
      setScoresLoaded(scoreRes.status === 'fulfilled');
      setMedicationsLoaded(meds.status === 'fulfilled');
      setSignalsLoaded(sig !== null);
      setEmergencyKnown(sos.status === 'fulfilled');
      setScores(scoreRes.status === 'fulfilled' ? scoreRes.value : []);
      setMedications(meds.status === 'fulfilled' ? meds.value : []);
      setSignals(sig !== null ? sig.value : []);
      setAdherence(sigAdherence.status === 'fulfilled' && sig !== null ? sigAdherence.value : []);
      setEmergency(sos.status === 'fulfilled' ? sos.value : null);
      failures.current = 0;
      resolvedAt.current = null;
      setStaleSince(null);
      setNow(new Date());
      setLastSync(new Date());
    } catch (e) {
      if (!mounted.current) return;
      if (isSessionExpired(e)) setSessionExpired(true);
      setError(e instanceof Error ? e.message : 'Falha ao carregar os dados.');
    } finally {
      if (mounted.current) setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const polling = useRef(false);

  /**
   * Atualização silenciosa: SOS em aberto e sinais novos. Falha de rede mantém a última leitura,
   * mas depois de algumas falhas seguidas a tela diz que o que mostra pode estar velho.
   */
  const poll = useCallback(async (forceMedications = false) => {
    // Uma atualização por vez: em link lento, duas em voo deixariam a mais velha vencer a mais nova.
    if (!homeId || polling.current) return;
    polling.current = true;
    try {
      const epoch = ackEpoch.current;
      const [sos, sigTimeline, sigAdherence, meds] = await Promise.allSettled([
        api.activeEmergency(homeId),
        api.signals(homeId, startOfYesterday(new Date())),
        api.signals(homeId, startOfToday(new Date()), 200, 'adherence'),
        // Se os remédios não carregaram na abertura, o polling tenta de novo.
        medicationsLoadedRef.current && !forceMedications ? Promise.resolve(null) : api.medications(homeId),
      ]);

      // O desfecho do SOS pode pedir mais uma ida ao servidor: decide antes, aplica depois.
      let emergencyNext: { set?: ActiveEmergency | null; stopLinger?: boolean; startLinger?: boolean } | null = null;
      if (sos.status === 'fulfilled') {
        const current = emergencyRef.current;
        const step = nextEmergencyStep(current, sos.value, resolvedAt.current, Date.now(), FINAL_LINGER_MS);
        if (step.kind === 'show') emergencyNext = { set: step.emergency, stopLinger: true };
        else if (step.kind === 'clear') emergencyNext = { set: null, stopLinger: true };
        else if (step.kind === 'lookup' && current !== null) {
          // Estava em aberto e deixou de estar: outra pessoa confirmou, ou a Maria cancelou. Sumir
          // calada seria pior que não ter mostrado — pergunta ao servidor como terminou.
          let outcome: ActiveEmergency | null = null;
          try {
            outcome = await api.emergencyOutcome(step.emergencyId);
          } catch {
            // Não deu para saber como terminou: diz só que deixou de estar em aberto.
          }
          emergencyNext = { set: emergencyOutcome(current, outcome), startLinger: true };
        } else if (current !== null && current.state === 'closed') {
          // "Encerrado" é o desfecho de quem não conseguiu saber como terminou: tenta de novo
          // enquanto está na tela (a rede pode ter voltado).
          try {
            const outcome = await api.emergencyOutcome(current.emergencyId);
            if (!isOpenEmergency(outcome)) emergencyNext = { set: emergencyOutcome(current, outcome) };
          } catch {
            // segue "encerrado"
          }
        }
      }
      if (!mounted.current) return;
      const ackRaced = emergencyReadIsStale(epoch, ackEpoch.current, acknowledgingRef.current);

      const sig = sigTimeline.status === 'fulfilled' && sigAdherence.status === 'fulfilled' ? sigTimeline : null;
      if ([sos, sigTimeline, sigAdherence, meds].some((r) => r.status === 'rejected' && isSessionExpired(r.reason))) {
        setSessionExpired(true);
      }
      if (meds.status === 'fulfilled' && meds.value !== null) {
        setMedications(meds.value);
        setMedicationsLoaded(true);
      }
      if (sig !== null && sigAdherence.status === 'fulfilled') {
        setSignals(sig.value);
        setAdherence(sigAdherence.value);
        setSignalsLoaded(true);
      }
      if (sos.status === 'fulfilled') {
        setEmergencyKnown(true);
        // Corrida com o "estou indo": a leitura é anterior à confirmação; o próximo poll já vê o
        // servidor depois dela.
        if (emergencyNext !== null && !ackRaced) {
          if (emergencyNext.set !== undefined) setEmergency(emergencyNext.set);
          if (emergencyNext.stopLinger) resolvedAt.current = null;
          if (emergencyNext.startLinger) resolvedAt.current = Date.now();
        }
      } else {
        // Não sei se há SOS: a tela diz que não conseguiu verificar.
        setEmergencyKnown(false);
      }

      if (sos.status === 'rejected' || sig === null) {
        failures.current += 1;
        if (failures.current >= STALE_AFTER_FAILURES) setStaleSince((current) => current ?? new Date());
      } else {
        failures.current = 0;
        setStaleSince(null);
        setLastSync(new Date());
      }
      setNow(new Date());
    } finally {
      polling.current = false;
    }
  }, [homeId]);

  // Só pergunta enquanto a tela está à vista (e a sessão vale).
  useFocusEffect(
    useCallback(() => {
      if (sessionExpired) return undefined;
      // Ao (re)ganhar o foco já se atualiza: voltando de Medicamentos, um remédio removido ou criado
      // lá não pode continuar (ou faltar) no "Remédios de hoje" até a próxima abertura.
      poll(true);
      const timer = setInterval(() => poll(), POLL_MS);
      return () => clearInterval(timer);
    }, [poll, sessionExpired]),
  );

  async function acknowledge() {
    if (!emergency || acknowledging) return;
    ackEpoch.current += 1;
    acknowledgingRef.current = true;
    setAcknowledging(true);
    setAcknowledgeFailed(false);
    try {
      const result = await api.acknowledgeEmergency(emergency.emergencyId);
      if (!mounted.current) return;
      resolvedAt.current = Date.now();
      // O AckResponse não traz o horário do pedido: mantém o que já se sabia.
      setEmergency({ ...emergency, ...result, createdAt: result.createdAt ?? emergency.createdAt });
    } catch {
      // Sem sucesso falso: o alerta continua na tela e a falha é dita.
      if (mounted.current) setAcknowledgeFailed(true);
    } finally {
      acknowledgingRef.current = false;
      ackEpoch.current += 1;
      if (mounted.current) setAcknowledging(false);
    }
  }

  const who = firstName(home?.patientName);
  const todayAvailable = medicationsLoaded && signalsLoaded;
  const dataComplete = scoresLoaded && todayAvailable && emergencyKnown && staleSince === null;
  const today = useMemo(() => medicationsToday(medications, adherence, now), [medications, adherence, now]);
  const activities = useMemo(() => timeline(signals, medications, who), [signals, medications, who]);
  const needsAttention =
    (emergency !== null && isOpenEmergency(emergency)) ||
    scores.some((s) => s.level === 'high') ||
    (todayAvailable && today.some((m) => m.status === 'late' || m.declinedToday));
  const lastActivity = activities[0]?.occurredAt ?? null;
  const statusOk = !needsAttention && dataComplete;

  async function recompute() {
    if (!home) return;
    setLoading(true);
    try {
      await api.recompute(home.id);
    } catch (e) {
      setError(isSessionExpired(e) ? SESSION_EXPIRED_MESSAGE : e instanceof Error ? e.message : 'Falha ao recalcular.');
      setLoading(false);
      return;
    }
    // O recálculo deu certo; ler o resultado é outra chamada, e a falha dela NÃO pode deixar
    // "Tudo em ordem" sobre as notas de antes do recálculo. A flag acompanha a leitura, nos dois sentidos.
    try {
      setScores(await api.latestScores(home.id));
      setScoresLoaded(true);
      setLastSync(new Date());
    } catch (e) {
      setScoresLoaded(false);
      setError(isSessionExpired(e) ? SESSION_EXPIRED_MESSAGE : e instanceof Error ? e.message : 'Falha ao ler o resultado.');
    } finally {
      setLoading(false);
    }
  }

  async function registerNearFall() {
    if (!home) return;
    try {
      await api.registerSignal(home.id, 'near_fall');
      await recompute();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Falha ao registrar o sinal.');
    }
  }

  if (loading && scores.length === 0) {
    return (
      <View style={styles.center}>
        <ActivityIndicator color={theme.primary} size="large" />
        <Text style={styles.muted}>Carregando o dia da Maria…</Text>
      </View>
    );
  }

  // Sem a casa carregada não há o que afirmar: "Tudo em ordem" e "Nenhum remédio" seriam falsos,
  // só porque a chamada falhou. Fica o erro e a saída.
  if (home === null || sessionExpired) {
    return (
      <View style={styles.center}>
        <Text style={styles.error}>
          {sessionExpired ? SESSION_EXPIRED_MESSAGE : (error ?? 'Não foi possível carregar os dados.')}
        </Text>
        <View style={styles.errorActions}>
          {!sessionExpired && (
            <>
              <AuraButton
                title="Tentar de novo"
                onPress={() => {
                  setLoading(true);
                  load();
                }}
              />
              <View style={styles.spacer} />
            </>
          )}
          <AuraButton title="Entrar de novo" variant="outline" onPress={() => navigation.replace('Login')} />
        </View>
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.screen}
      contentContainerStyle={styles.content}
      refreshControl={<RefreshControl refreshing={loading} onRefresh={load} tintColor={theme.primary} />}
    >
      {/* O SOS vem antes de tudo: é a única coisa que não espera. */}
      {emergency !== null && (
        <SosAlertCard
          emergency={emergency}
          patientFirstName={who}
          acknowledging={acknowledging}
          acknowledgeFailed={acknowledgeFailed}
          onAcknowledge={acknowledge}
          now={now}
        />
      )}

      {/* Não sei se há SOS: dizer "nada" seria mentir. Dizer que não deu para verificar é a resposta honesta. */}
      {!emergencyKnown && emergency === null && (
        <ConnectionNotice message="Não consegui verificar se há um pedido de ajuda agora." onRetry={() => poll()} />
      )}
      {/* O polling vem falhando: o que está na tela pode estar velho. */}
      {staleSince !== null && (
        <ConnectionNotice
          message={`Sem conexão com o servidor. O que você vê pode estar desatualizado (última atualização às ${careClock(lastSync ?? staleSince, now)}).`}
        />
      )}

      <View style={styles.header}>
        <Image source={require('../../assets/aura-logo.png')} style={styles.avatar} />
        <View style={styles.headerText}>
          <Text style={styles.title}>{home?.patientName ?? 'Paciente'}</Text>
          <Text style={styles.muted}>{home?.address ?? 'Endereço não informado'}</Text>
          <Text style={[styles.status, { color: statusOk ? theme.confirm : theme.accent }]}>
            {needsAttention ? 'Há pontos de atenção' : dataComplete ? 'Tudo em ordem' : 'Não consegui atualizar tudo'}
            {lastActivity !== null && (
              <Text style={styles.muted}>{`  ·  Última atividade ${careAgo(lastActivity, now)}`}</Text>
            )}
          </Text>
        </View>
      </View>

      {error !== null && <Text style={styles.error}>{error}</Text>}

      {/* O dia dela: o que a família quer saber antes de qualquer nota de risco. */}
      <MedicationsTodayCard
        items={today}
        now={now}
        available={todayAvailable}
        onPress={home ? () => navigation.navigate('Medications', { homeId: home.id, patientFirstName: who }) : undefined}
      />
      <TimelineCard items={activities} patientFirstName={who} now={now} available={signalsLoaded} />

      <Text style={[styles.sectionTitle, styles.sectionGap]}>Risco por dimensão</Text>

      {!scoresLoaded && <Text style={styles.loadFailed}>Não consegui carregar o risco agora. Puxe a tela para baixo.</Text>}
      {scoresLoaded && scores.length === 0 && (
        <Text style={styles.muted}>Ainda não há leituras. Toque em "Atualizar leituras".</Text>
      )}

      {scores.map((score) => (
        <View key={score.scoreId} style={styles.card}>
          <View style={styles.cardHead}>
            <Text style={styles.cardTitle}>{dimensionLabels[score.dimension] ?? score.dimension}</Text>
            <View style={[styles.badge, { backgroundColor: `${levelColor[score.level]}22` }]}>
              <Text style={[styles.badgeText, { color: levelColor[score.level] }]}>
                {levelLabels[score.level] ?? score.level}
              </Text>
            </View>
          </View>

          <View style={styles.bar}>
            <View
              style={[
                styles.barFill,
                { width: `${Math.round(score.score * 100)}%`, backgroundColor: levelColor[score.level] },
              ]}
            />
          </View>

          <Text style={styles.explanation}>{score.explanation}</Text>

          {score.factors.map((factor, index) => (
            <Text key={factor} style={styles.factor}>
              • {score.factorLabels?.[index] ?? factor} <Text style={styles.weight}>peso {pesoBr(score.weights[index])}</Text>
            </Text>
          ))}

          {score.level !== 'low' && (
            <TouchableOpacity
              style={styles.link}
              accessibilityRole="button"
              onPress={() => navigation.navigate('CareChain', { homeId: home!.id, scoreId: score.scoreId })}
            >
              <Text style={styles.linkText}>Ver o que a casa precisa →</Text>
            </TouchableOpacity>
          )}
        </View>
      ))}

      <View style={styles.actions}>
        <AuraButton title="Atualizar leituras" onPress={recompute} />
        <View style={styles.spacer} />
        <AuraButton title="Registrar quase-queda (demonstração)" onPress={registerNearFall} variant="outline" />
      </View>

      <Text style={styles.disclaimer}>
        O AURA não prescreve nem diagnostica. Ele te avisa do que percebe — decisões de saúde ficam com o médico.
      </Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.bg },
  content: { padding: spacing.md + 4, paddingBottom: spacing.xxl },
  center: { flex: 1, backgroundColor: theme.bg, alignItems: 'center', justifyContent: 'center', gap: spacing.sm },
  header: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginBottom: spacing.lg - 4 },
  avatar: { width: 52, height: 52, borderRadius: radius.lg },
  headerText: { flex: 1 },
  title: { color: theme.ink, fontSize: 20, fontFamily: fontFamily.displaySemibold },
  muted: { color: theme.muted, fontSize: 13, fontFamily: fontFamily.body },
  loadFailed: { color: theme.accent, fontSize: 13, fontFamily: fontFamily.bodyBold },
  status: { fontSize: 13, marginTop: 2, fontFamily: fontFamily.bodyBold },
  sectionGap: { marginTop: spacing.sm },
  sectionTitle: { color: theme.ink, fontSize: 15, fontFamily: fontFamily.displaySemibold, marginBottom: spacing.sm + 2 },
  card: {
    backgroundColor: theme.surface,
    borderColor: theme.border,
    borderWidth: 1,
    borderRadius: radius.lg,
    padding: spacing.md,
    marginBottom: spacing.sm + 4,
  },
  cardHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  cardTitle: { color: theme.ink, fontSize: 16, fontFamily: fontFamily.bodyBold },
  badge: { paddingHorizontal: spacing.sm + 2, paddingVertical: 3, borderRadius: 999 },
  badgeText: { fontSize: 11, fontFamily: fontFamily.bodyBold },
  bar: { height: 6, borderRadius: 999, backgroundColor: theme.surfaceAlt, marginVertical: spacing.sm + 2, overflow: 'hidden' },
  barFill: { height: '100%', borderRadius: 999 },
  explanation: { color: theme.text, fontSize: 13, marginBottom: spacing.sm, fontFamily: fontFamily.body },
  factor: { color: theme.muted, fontSize: 12, lineHeight: 18, fontFamily: fontFamily.body },
  weight: { color: theme.primary, fontFamily: fontFamily.bodyBold },
  link: { marginTop: spacing.md, minHeight: 48, justifyContent: 'center' },
  linkText: { color: theme.primary, fontSize: 13, fontFamily: fontFamily.bodyBold },
  actions: { marginTop: spacing.sm },
  spacer: { height: spacing.sm + 2 },
  errorActions: { alignSelf: 'stretch', paddingHorizontal: spacing.md + 4, marginTop: spacing.sm },
  error: { color: theme.danger, fontSize: 13, marginBottom: spacing.md, fontFamily: fontFamily.body },
  disclaimer: { color: theme.muted, fontSize: 11, marginTop: spacing.lg, lineHeight: 16, fontFamily: fontFamily.body },
});
