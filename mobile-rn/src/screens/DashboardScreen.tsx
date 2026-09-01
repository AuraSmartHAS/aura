import React, { useCallback, useEffect, useState } from 'react';
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
import { api, Home, Score } from '../api';
import AuraButton from '../components/AuraButton';
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

/** Painel da cuidadora: risco por dimensão, sempre com os fatores que explicam o número. */
export default function DashboardScreen({ navigation }: Props) {
  const [home, setHome] = useState<Home | null>(null);
  const [scores, setScores] = useState<Score[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

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
      setScores(await api.latestScores(homes[0].id));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Falha ao carregar os dados.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  async function recompute() {
    if (!home) return;
    setLoading(true);
    try {
      await api.recompute(home.id);
      setScores(await api.latestScores(home.id));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Falha ao recalcular.');
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

  return (
    <ScrollView
      style={styles.screen}
      contentContainerStyle={styles.content}
      refreshControl={<RefreshControl refreshing={loading} onRefresh={load} tintColor={theme.primary} />}
    >
      <View style={styles.header}>
        <Image source={require('../../assets/aura-logo.png')} style={styles.avatar} />
        <View style={styles.headerText}>
          <Text style={styles.title}>{home?.patientName ?? 'Paciente'}</Text>
          <Text style={styles.muted}>{home?.address ?? 'Endereço não informado'}</Text>
        </View>
      </View>

      {error !== null && <Text style={styles.error}>{error}</Text>}

      <Text style={styles.sectionTitle}>Risco por dimensão</Text>

      {scores.length === 0 && (
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
              <Text style={styles.linkText}>Ver recomendação da Care-Chain →</Text>
            </TouchableOpacity>
          )}
        </View>
      ))}

      <View style={styles.actions}>
        <AuraButton title="Atualizar leituras" onPress={recompute} />
        <View style={styles.spacer} />
        <AuraButton title="Registrar quase-queda" onPress={registerNearFall} variant="outline" />
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
  link: { marginTop: spacing.md, minHeight: 44, justifyContent: 'center' },
  linkText: { color: theme.primary, fontSize: 13, fontFamily: fontFamily.bodyBold },
  actions: { marginTop: spacing.sm },
  spacer: { height: spacing.sm + 2 },
  error: { color: theme.danger, fontSize: 13, marginBottom: spacing.md, fontFamily: fontFamily.body },
  disclaimer: { color: theme.muted, fontSize: 11, marginTop: spacing.lg, lineHeight: 16, fontFamily: fontFamily.body },
});
