import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  AccessibilityInfo,
  ActivityIndicator,
  Alert,
  Platform,
  Pressable,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { api, isSessionExpired, SESSION_EXPIRED_MESSAGE, type CareSignal, type MedicationRecord } from '../api';
import { medicationsToday, startOfToday, stockLabel } from '../careToday';
import AuraButton from '../components/AuraButton';
import MedicationFormModal from '../components/MedicationFormModal';
import { CaregiverDoseStatus, LOW_STOCK, statusLine } from '../components/TodayCards';
import {
  createBody,
  groupByDayPeriod,
  periodLabel,
  updateBody,
  type MedicationInput,
  type MedicationPeriod,
} from '../medications';
import type { ScreenProps } from '../navigation';
import { fontFamily, minTouchTarget, radius, spacing, theme } from '../theme';

type Props = ScreenProps<'Medications'>;

/** Cor de cada período: a lista lê como uma rotina do dia (a cor nunca vai sozinha — há o nome). */
const periodColor: Record<MedicationPeriod, string> = {
  morning: theme.accent,
  afternoon: theme.primary,
  evening: theme.careGreen,
  unscheduled: theme.muted,
};

const byName = (a: MedicationRecord, b: MedicationRecord) =>
  a.name.localeCompare(b.name, 'pt-BR', { sensitivity: 'base' });

const BANNER_MS = 4000;
/** De quanto em quanto tempo o relógio da tela avança (status de dose depende da hora). */
const CLOCK_MS = 30_000;

/**
 * Medicamentos na visão da família. A cuidadora cadastra, edita e remove; o resultado de hoje
 * aparece em cada cartão. Quem confirma a dose é a Maria (pela voz ou pelo app): confirmar por
 * ela aqui sujaria a adesão que o resto do sistema lê.
 */
export default function MedicationsScreen({ route }: Props) {
  const { homeId, patientFirstName } = route.params;
  const [medications, setMedications] = useState<MedicationRecord[]>([]);
  const [signals, setSignals] = useState<CareSignal[]>([]);
  /** Falso quando os sinais não carregaram: sem eles o status de dose não existe (nada de "atrasada" só pelo relógio). */
  const [signalsLoaded, setSignalsLoaded] = useState(false);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  /** O relógio avança sozinho: sem isso "Atrasada" só aparece depois de recarregar a lista. */
  const [now, setNow] = useState(() => new Date());
  const [error, setError] = useState<string | null>(null);
  const [banner, setBanner] = useState<{ message: string; isError: boolean } | null>(null);
  /** `undefined` = fechado; `null` = cadastrando; um remédio = editando. */
  const [editing, setEditing] = useState<MedicationRecord | null | undefined>(undefined);

  const load = useCallback(async () => {
    setError(null);
    try {
      setMedications(await api.medications(homeId));
      // Sem os sinais a lista segue legível, só sem o estado de hoje — e a tela DIZ que não carregou.
      const sig = await Promise.allSettled([api.signals(homeId, startOfToday(new Date()), 200, 'adherence')]);
      if (sig[0].status === 'fulfilled') {
        setSignals(sig[0].value);
        setSignalsLoaded(true);
      } else {
        setSignals([]);
        setSignalsLoaded(false);
      }
    } catch (e) {
      // A lista pode ser a de antes; o status de hoje, calculado com sinais de antes, também seria:
      // sem prova de que está atual, ele não é mostrado.
      setSignalsLoaded(false);
      setError(isSessionExpired(e) ? SESSION_EXPIRED_MESSAGE : e instanceof Error ? e.message : 'Falha ao carregar os medicamentos.');
    } finally {
      setNow(new Date());
      setLoading(false);
      setRefreshing(false);
    }
  }, [homeId]);

  useEffect(() => {
    load();
  }, [load]);

  // O aviso some sozinho, como o SnackBar do app Flutter — e é anunciado: a região viva só vale no
  // Android, e sem isto o leitor de tela no iOS nunca diria "Medicamento removido".
  useEffect(() => {
    if (banner === null) return;
    // No Android a região viva do próprio aviso já anuncia; falar de novo repetiria a frase.
    if (Platform.OS === 'ios') AccessibilityInfo.announceForAccessibility(banner.message);
    const timer = setTimeout(() => setBanner(null), BANNER_MS);
    return () => clearTimeout(timer);
  }, [banner]);

  useEffect(() => {
    const timer = setInterval(() => setNow(new Date()), CLOCK_MS);
    return () => clearInterval(timer);
  }, []);

  // Só com os sinais carregados: calculado sem eles, "Atrasada" seria só o relógio dizendo.
  const todayById = useMemo(
    () =>
      signalsLoaded
        ? new Map(medicationsToday(medications, signals, now).map((item) => [item.medication.id, item]))
        : new Map<string, ReturnType<typeof medicationsToday>[number]>(),
    [medications, signals, signalsLoaded, now],
  );
  const active = useMemo(() => medications.filter((m) => m.active), [medications]);
  const groups = useMemo(() => groupByDayPeriod(active), [active]);

  /** Devolve o erro (o formulário fica aberto) ou null quando salvou. */
  async function save(input: MedicationInput): Promise<string | null> {
    const target = editing;
    try {
      // O servidor responde com o registro salvo: não precisa refazer a lista.
      const saved = target
        ? await api.updateMedication(target.id, updateBody(input))
        : await api.createMedication(homeId, createBody(input));
      setMedications((current) => [...current.filter((m) => m.id !== saved.id), saved].sort(byName));
      setBanner({ message: target ? 'Alterações salvas.' : 'Medicamento cadastrado.', isError: false });
      setEditing(undefined);
      return null;
    } catch (e) {
      return isSessionExpired(e)
        ? SESSION_EXPIRED_MESSAGE
        : `Não foi possível salvar: ${e instanceof Error ? e.message : 'tente de novo.'}`;
    }
  }

  function confirmRemove(med: MedicationRecord) {
    Alert.alert(
      'Remover medicamento?',
      `"${med.name}" será removido da lista. Você pode cadastrá-lo novamente depois.`,
      [
        { text: 'Cancelar', style: 'cancel' },
        { text: 'Remover', style: 'destructive', onPress: () => remove(med) },
      ],
    );
  }

  async function remove(med: MedicationRecord) {
    try {
      await api.deleteMedication(med.id);
      setMedications((current) => current.filter((m) => m.id !== med.id));
      setBanner({ message: 'Medicamento removido.', isError: false });
    } catch (e) {
      setBanner({
        message: isSessionExpired(e)
          ? SESSION_EXPIRED_MESSAGE
          : `Não foi possível remover: ${e instanceof Error ? e.message : 'tente de novo.'}`,
        isError: true,
      });
    }
  }

  if (loading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator color={theme.primary} size="large" />
        <Text style={styles.muted}>Carregando medicamentos...</Text>
      </View>
    );
  }

  return (
    <View style={styles.screen}>
      {banner !== null && (
        <View
          accessibilityLiveRegion="polite"
          style={[styles.banner, { backgroundColor: banner.isError ? theme.danger : theme.ink }]}
        >
          <Text style={styles.bannerText}>{banner.message}</Text>
        </View>
      )}

      <ScrollView
        contentContainerStyle={styles.content}
        refreshControl={<RefreshControl
            refreshing={refreshing}
            onRefresh={() => {
              setRefreshing(true);
              load();
            }}
            tintColor={theme.primary}
          />}
      >
        {error !== null && (
          <View style={styles.errorBox}>
            <Text style={styles.error}>{error}</Text>
            <AuraButton title="Tentar de novo" onPress={load} />
          </View>
        )}

        {error === null && active.length > 0 && !signalsLoaded && (
          <Text style={styles.loadFailed}>Não consegui carregar o status de hoje. Puxe a tela para baixo.</Text>
        )}

        {error === null && active.length === 0 && (
          <View style={styles.empty}>
            <Text style={styles.emptyTitle}>Nenhum medicamento ainda</Text>
            <Text style={styles.muted}>
              {'Cadastre o primeiro medicamento para acompanhar a rotina de cuidado.'}
            </Text>
            <View style={styles.emptyAction}>
              <AuraButton title="Adicionar medicamento" onPress={() => setEditing(null)} />
            </View>
          </View>
        )}

        {groups.map((group) => (
          <View key={group.period} style={styles.group}>
            <View style={styles.groupHead}>
              <View style={[styles.dot, { backgroundColor: periodColor[group.period] }]} />
              <Text accessibilityRole="header" style={styles.groupTitle}>
                {periodLabel[group.period]}
              </Text>
              <Text style={styles.count}>{group.entries.length}</Text>
            </View>

            {group.entries.map(({ medication: med, times }) => {
              const today = todayById.get(med.id);
              const statusText = [
                today ? statusLine(today, now).text : null,
                today?.declinedToday ? 'Disse que não tomou' : null,
                med.stockDoses === null
                  ? null
                  : med.stockDoses === 0
                    ? 'Estoque esgotado'
                    : med.stockDoses <= LOW_STOCK
                      ? `Estoque baixo: ${stockLabel(med.stockDoses)}`
                      : `Estoque: ${stockLabel(med.stockDoses)}`,
              ].filter((t): t is string => t !== null);
              const label = [
                med.name,
                med.dosage,
                times.length ? times.join(', ') : null,
                med.notes,
                ...statusText,
                'Editar',
              ]
                .filter(Boolean)
                .join('. ');

              return (
                // O cartão NÃO é um botão único: "Remover" é irmão da área editável. Um botão dentro de
                // outro é engolido pelo leitor de tela (editaria, mas nunca removeria).
                <View key={`${group.period}-${med.id}`} style={styles.card}>
                  <View style={styles.cardRow}>
                    <Pressable
                      accessibilityRole="button"
                      accessibilityLabel={label}
                      onPress={() => setEditing(med)}
                      style={({ pressed }) => [styles.cardMain, pressed && styles.pressed]}
                    >
                      <Text style={styles.name}>{med.name}</Text>

                      {(med.dosage || times.length > 0) && (
                        <View style={styles.chips}>
                          {med.dosage ? <Chip label={med.dosage} /> : null}
                          {times.length > 0 ? <Chip label={times.join(', ')} /> : null}
                        </View>
                      )}
                      {med.notes ? <Text style={styles.notes}>{med.notes}</Text> : null}

                      <View style={styles.status}>
                        <CaregiverDoseStatus item={today} stockDoses={med.stockDoses} now={now} />
                      </View>
                    </Pressable>

                    <Pressable
                      accessibilityRole="button"
                      accessibilityLabel={`Remover ${med.name}`}
                      onPress={() => confirmRemove(med)}
                      hitSlop={8}
                      style={styles.trash}
                    >
                      <Text style={styles.trashText}>Remover</Text>
                    </Pressable>
                  </View>
                </View>
              );
            })}
          </View>
        ))}

        <Text style={styles.disclaimer}>
          {`Quem confirma a dose é ${patientFirstName}, pela voz ou pelo app. O AURA não prescreve: horários e doses seguem a orientação do médico.`}
        </Text>
      </ScrollView>

      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Adicionar medicamento"
        onPress={() => setEditing(null)}
        style={({ pressed }) => [styles.fab, pressed && styles.pressed]}
      >
        <Text style={styles.fabText}>+ Adicionar</Text>
      </Pressable>

      <MedicationFormModal
        visible={editing !== undefined}
        medication={editing ?? null}
        onCancel={() => setEditing(undefined)}
        onSubmit={save}
      />
    </View>
  );
}

function Chip({ label }: { label: string }) {
  return (
    <View style={styles.chip}>
      <Text style={styles.chipText}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.bg },
  content: { padding: spacing.md + 4, paddingBottom: spacing.xxl * 2 },
  center: { flex: 1, backgroundColor: theme.bg, alignItems: 'center', justifyContent: 'center', gap: spacing.sm },
  banner: { paddingVertical: spacing.sm + 2, paddingHorizontal: spacing.md + 4 },
  bannerText: { color: '#FFFFFF', fontSize: 14, fontFamily: fontFamily.bodyBold },
  group: { marginBottom: spacing.md },
  groupHead: { flexDirection: 'row', alignItems: 'center', marginBottom: spacing.sm, paddingLeft: spacing.xs },
  dot: { width: 10, height: 10, borderRadius: 5, marginRight: spacing.sm },
  groupTitle: { color: theme.ink, fontSize: 16, fontFamily: fontFamily.displaySemibold },
  count: { color: theme.muted, fontSize: 13, marginLeft: spacing.sm, fontFamily: fontFamily.bodyBold },
  card: {
    backgroundColor: theme.surface,
    borderColor: theme.border,
    borderWidth: 1,
    borderRadius: radius.lg,
    padding: spacing.md,
    marginBottom: spacing.sm,
  },
  pressed: { opacity: 0.75 },
  cardRow: { flexDirection: 'row', alignItems: 'flex-start' },
  cardMain: { flex: 1, minHeight: minTouchTarget },
  name: { flex: 1, color: theme.ink, fontSize: 17, fontFamily: fontFamily.displaySemibold },
  trash: { minHeight: minTouchTarget, minWidth: minTouchTarget, alignItems: 'center', justifyContent: 'center' },
  // Ação destrutiva: não vai em cinza apagado.
  trashText: { color: theme.danger, fontSize: 13, fontFamily: fontFamily.bodyBold },
  loadFailed: { color: theme.accent, fontSize: 13, marginBottom: spacing.md, fontFamily: fontFamily.bodyBold },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginTop: spacing.xs },
  chip: { backgroundColor: theme.surfaceAlt, borderRadius: radius.sm, paddingHorizontal: spacing.sm, paddingVertical: spacing.xs },
  chipText: { color: theme.ink, fontSize: 13, fontFamily: fontFamily.body },
  notes: { color: theme.text, fontSize: 13, marginTop: spacing.sm, fontFamily: fontFamily.body },
  status: { marginTop: spacing.sm + 2 },
  empty: { alignItems: 'center', paddingVertical: spacing.xl },
  emptyTitle: { color: theme.ink, fontSize: 18, marginBottom: spacing.sm, fontFamily: fontFamily.displaySemibold },
  emptyAction: { alignSelf: 'stretch', marginTop: spacing.md },
  muted: { color: theme.muted, fontSize: 13, textAlign: 'center', fontFamily: fontFamily.body },
  errorBox: { marginBottom: spacing.md },
  error: { color: theme.danger, fontSize: 13, marginBottom: spacing.md, fontFamily: fontFamily.body },
  disclaimer: { color: theme.muted, fontSize: 11, marginTop: spacing.lg, lineHeight: 16, fontFamily: fontFamily.body },
  fab: {
    position: 'absolute',
    right: spacing.md + 4,
    bottom: spacing.lg,
    minHeight: 56,
    paddingHorizontal: spacing.lg,
    borderRadius: radius.lg,
    backgroundColor: theme.primary,
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 4,
  },
  fabText: { color: '#FFFFFF', fontSize: 16, fontFamily: fontFamily.bodyBold },
});
