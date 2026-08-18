import React, { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Button,
  Image,
  RefreshControl,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { api, Home, Score } from '../api';
import type { ScreenProps } from '../navigation';
import { levelColor, theme } from '../theme';

type Props = ScreenProps<'Dashboard'>;

const dimensionLabels: Record<string, string> = {
  mobility: 'Mobilidade',
  sleep: 'Sono',
  cognition: 'Cognição',
  environment: 'Ambiente',
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
        <ActivityIndicator color={theme.accent} size="large" />
        <Text style={styles.muted}>Carregando o dia da Maria…</Text>
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.screen}
      contentContainerStyle={styles.content}
      refreshControl={<RefreshControl refreshing={loading} onRefresh={load} tintColor={theme.accent} />}
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
        <Text style={styles.muted}>Sem escore calculado. Toque em “Recalcular escore”.</Text>
      )}

      {scores.map((score) => (
        <View key={score.scoreId} style={styles.card}>
          <View style={styles.cardHead}>
            <Text style={styles.cardTitle}>{dimensionLabels[score.dimension] ?? score.dimension}</Text>
            <View style={[styles.badge, { backgroundColor: `${levelColor[score.level]}22` }]}>
              <Text style={[styles.badgeText, { color: levelColor[score.level] }]}>
                {score.level.toUpperCase()} · {Math.round(score.score * 100)}%
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
              • {factor} <Text style={styles.weight}>peso {score.weights[index]}</Text>
            </Text>
          ))}

          {score.level !== 'low' && (
            <TouchableOpacity
              style={styles.link}
              onPress={() => navigation.navigate('CareChain', { homeId: home!.id, scoreId: score.scoreId })}
            >
              <Text style={styles.linkText}>Ver recomendação da Care-Chain →</Text>
            </TouchableOpacity>
          )}
        </View>
      ))}

      <View style={styles.actions}>
        <Button title="Recalcular escore" color={theme.accent} onPress={recompute} />
        <View style={styles.spacer} />
        <Button title="Registrar quase-queda" color={theme.info} onPress={registerNearFall} />
      </View>

      <Text style={styles.disclaimer}>
        O AURA não prescreve nem diagnostica. Sintomas relevantes são sempre encaminhados ao médico.
      </Text>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.bg },
  content: { padding: 20, paddingBottom: 48 },
  center: { flex: 1, backgroundColor: theme.bg, alignItems: 'center', justifyContent: 'center', gap: 12 },
  header: { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 20 },
  avatar: { width: 52, height: 52, borderRadius: 14 },
  headerText: { flex: 1 },
  title: { color: theme.textStrong, fontSize: 20, fontWeight: '700' },
  muted: { color: theme.muted, fontSize: 13 },
  sectionTitle: { color: theme.textStrong, fontSize: 15, fontWeight: '700', marginBottom: 10 },
  card: {
    backgroundColor: theme.surface,
    borderColor: theme.border,
    borderWidth: 1,
    borderRadius: 14,
    padding: 16,
    marginBottom: 12,
  },
  cardHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  cardTitle: { color: theme.textStrong, fontSize: 16, fontWeight: '600' },
  badge: { paddingHorizontal: 10, paddingVertical: 3, borderRadius: 999 },
  badgeText: { fontSize: 11, fontWeight: '700' },
  bar: { height: 6, borderRadius: 999, backgroundColor: theme.surfaceAlt, marginVertical: 10, overflow: 'hidden' },
  barFill: { height: '100%', borderRadius: 999 },
  explanation: { color: theme.text, fontSize: 13, marginBottom: 8 },
  factor: { color: theme.muted, fontSize: 12, lineHeight: 18 },
  weight: { color: theme.info },
  link: { marginTop: 12 },
  linkText: { color: theme.accent, fontSize: 13, fontWeight: '600' },
  actions: { marginTop: 12 },
  spacer: { height: 10 },
  error: { color: theme.danger, fontSize: 13, marginBottom: 12 },
  disclaimer: { color: theme.muted, fontSize: 11, marginTop: 24, lineHeight: 16 },
});
