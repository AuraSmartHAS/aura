import React, { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, ScrollView, StyleSheet, Text, View } from 'react-native';
import { api, Order, Recommendation } from '../api';
import AuraButton from '../components/AuraButton';
import { pesoBr } from '../format';
import type { ScreenProps } from '../navigation';
import { fontFamily, radius, spacing, theme } from '../theme';

type Props = ScreenProps<'CareChain'>;

const stages = ['approved', 'sourcing', 'in_route', 'delivered', 'installed'];

const stageLabels: Record<string, string> = {
  approved: 'Aprovado',
  sourcing: 'Separando',
  in_route: 'Em rota',
  delivered: 'Entregue',
  installed: 'Instalado',
  returned: 'Devolvido',
};

/** Recomendação explicada → aprovação da cuidadora → pedido acompanhado até a instalação. */
export default function CareChainScreen({ route }: Props) {
  const { homeId, scoreId } = route.params;
  const [recommendation, setRecommendation] = useState<Recommendation | null>(null);
  const [orders, setOrders] = useState<Order[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setBusy(true);
    setError(null);
    try {
      const existing = await api.recommendations(homeId);
      const pending = existing.find((r) => r.status === 'recommended');
      setRecommendation(pending ?? (await api.recommend(homeId, scoreId)));
      setOrders(await api.orders(homeId));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Falha ao carregar a Care-Chain.');
    } finally {
      setBusy(false);
    }
  }, [homeId, scoreId]);

  useEffect(() => {
    load();
  }, [load]);

  async function approve() {
    if (!recommendation) return;
    setBusy(true);
    try {
      await api.approve(recommendation.recommendationId);
      setRecommendation({ ...recommendation, status: 'approved' });
      setOrders(await api.orders(homeId));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Falha ao aprovar.');
    } finally {
      setBusy(false);
    }
  }

  async function advance(order: Order) {
    setBusy(true);
    try {
      await api.advance(order.id);
      setOrders(await api.orders(homeId));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Falha ao avançar o pedido.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.content}>
      <Text style={styles.sectionTitle}>Recomendação explicada</Text>

      {busy && recommendation === null && <ActivityIndicator color={theme.primary} />}
      {error !== null && <Text style={styles.error}>{error}</Text>}

      {recommendation !== null && (
        <View style={styles.card}>
          <Text style={styles.product}>{recommendation.productName}</Text>
          <Text style={styles.reason}>{recommendation.reason}</Text>

          {recommendation.factors.length > 0 && (
            <>
              <Text style={styles.label}>Por que este item</Text>
              {recommendation.factors.map((factor, index) => (
                <Text key={factor} style={styles.factor}>
                  • {recommendation.factorLabels?.[index] ?? factor}{' '}
                  <Text style={styles.weight}>peso {pesoBr(recommendation.weights[index])}</Text>
                </Text>
              ))}
            </>
          )}

          {recommendation.status === 'recommended' ? (
            <View style={styles.button}>
              <AuraButton title="Aprovar e pedir" onPress={approve} disabled={busy} />
            </View>
          ) : (
            <Text style={styles.approved}>Aprovado pela cuidadora ✓</Text>
          )}
        </View>
      )}

      <Text style={styles.sectionTitle}>Pedidos</Text>

      {orders.length === 0 && <Text style={styles.muted}>Nenhum pedido — nada é comprado sem aprovação.</Text>}

      {orders.map((order) => (
        <View key={order.id} style={styles.card}>
          <Text style={styles.product}>{order.productName}</Text>

          <View style={styles.timeline}>
            {stages.map((stage, index) => {
              const done = index <= stages.indexOf(order.stage);
              return (
                <View
                  key={stage}
                  style={[styles.step, done && styles.stepDone, stage === order.stage && styles.stepCurrent]}
                >
                  <Text style={[styles.stepText, done && styles.stepTextDone]}>{stageLabels[stage]}</Text>
                </View>
              );
            })}
          </View>

          <Text style={order.slaBreached ? styles.slaBad : styles.sla}>
            {order.slaBreached ? 'Entrega atrasada' : 'Entrega no prazo'}
          </Text>

          {order.stage !== 'returned' && (
            <View style={styles.button}>
              <AuraButton title="Avançar estágio" onPress={() => advance(order)} disabled={busy} variant="secondary" />
            </View>
          )}
        </View>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.bg },
  content: { padding: spacing.md + 4, paddingBottom: spacing.xxl },
  sectionTitle: { color: theme.ink, fontSize: 15, fontFamily: fontFamily.displaySemibold, marginTop: spacing.sm, marginBottom: spacing.sm + 2 },
  card: {
    backgroundColor: theme.surface,
    borderColor: theme.border,
    borderWidth: 1,
    borderRadius: radius.lg,
    padding: spacing.md,
    marginBottom: spacing.md - 2,
  },
  product: { color: theme.ink, fontSize: 16, fontFamily: fontFamily.bodyBold },
  reason: { color: theme.text, fontSize: 13, marginTop: spacing.xs + 2, fontFamily: fontFamily.body },
  label: { color: theme.muted, fontSize: 11, textTransform: 'uppercase', marginTop: spacing.md, marginBottom: spacing.xs, fontFamily: fontFamily.bodyBold },
  factor: { color: theme.muted, fontSize: 12, lineHeight: 18, fontFamily: fontFamily.body },
  weight: { color: theme.primary, fontFamily: fontFamily.bodyBold },
  button: { marginTop: spacing.md },
  approved: { color: theme.success, fontSize: 13, fontFamily: fontFamily.bodyBold, marginTop: spacing.md },
  timeline: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.xs + 2, marginVertical: spacing.sm + 4 },
  step: { paddingHorizontal: spacing.sm, paddingVertical: 5, borderRadius: radius.sm, backgroundColor: theme.surfaceAlt },
  stepDone: { backgroundColor: `${theme.primary}22` },
  stepCurrent: { borderWidth: 1, borderColor: theme.accent },
  stepText: { color: theme.muted, fontSize: 11, fontFamily: fontFamily.body },
  stepTextDone: { color: theme.ink, fontFamily: fontFamily.bodyBold },
  sla: { color: theme.success, fontSize: 12, fontFamily: fontFamily.bodyBold },
  slaBad: { color: theme.danger, fontSize: 12, fontFamily: fontFamily.bodyBold },
  muted: { color: theme.muted, fontSize: 13, fontFamily: fontFamily.body },
  error: { color: theme.danger, fontSize: 13, marginBottom: spacing.md, fontFamily: fontFamily.body },
});
