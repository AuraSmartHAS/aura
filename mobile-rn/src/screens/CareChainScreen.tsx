import React, { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, Button, ScrollView, StyleSheet, Text, View } from 'react-native';
import { api, Order, Recommendation } from '../api';
import type { ScreenProps } from '../navigation';
import { theme } from '../theme';

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

      {busy && recommendation === null && <ActivityIndicator color={theme.accent} />}
      {error !== null && <Text style={styles.error}>{error}</Text>}

      {recommendation !== null && (
        <View style={styles.card}>
          <Text style={styles.product}>{recommendation.productName}</Text>
          <Text style={styles.reason}>{recommendation.reason}</Text>

          <Text style={styles.label}>Por que este item</Text>
          {recommendation.factors.map((factor, index) => (
            <Text key={factor} style={styles.factor}>
              • {factor} <Text style={styles.weight}>peso {recommendation.weights[index]}</Text>
            </Text>
          ))}

          {recommendation.status === 'recommended' ? (
            <View style={styles.button}>
              <Button title="Aprovar e pedir" color={theme.accent} onPress={approve} disabled={busy} />
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
            {order.slaBreached ? 'SLA estourado' : 'SLA dentro do prazo'}
          </Text>

          {order.stage !== 'returned' && (
            <View style={styles.button}>
              <Button title="Avançar estágio" color={theme.info} onPress={() => advance(order)} disabled={busy} />
            </View>
          )}
        </View>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.bg },
  content: { padding: 20, paddingBottom: 48 },
  sectionTitle: { color: theme.textStrong, fontSize: 15, fontWeight: '700', marginTop: 8, marginBottom: 10 },
  card: {
    backgroundColor: theme.surface,
    borderColor: theme.border,
    borderWidth: 1,
    borderRadius: 14,
    padding: 16,
    marginBottom: 14,
  },
  product: { color: theme.textStrong, fontSize: 16, fontWeight: '700' },
  reason: { color: theme.text, fontSize: 13, marginTop: 6 },
  label: { color: theme.muted, fontSize: 11, textTransform: 'uppercase', marginTop: 14, marginBottom: 4 },
  factor: { color: theme.muted, fontSize: 12, lineHeight: 18 },
  weight: { color: theme.info },
  button: { marginTop: 16 },
  approved: { color: theme.success, fontSize: 13, fontWeight: '600', marginTop: 16 },
  timeline: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, marginVertical: 12 },
  step: { paddingHorizontal: 8, paddingVertical: 5, borderRadius: 6, backgroundColor: theme.surfaceAlt },
  stepDone: { backgroundColor: 'rgba(88,166,255,0.16)' },
  stepCurrent: { borderWidth: 1, borderColor: theme.accent },
  stepText: { color: theme.muted, fontSize: 11 },
  stepTextDone: { color: theme.textStrong },
  sla: { color: theme.success, fontSize: 12 },
  slaBad: { color: theme.danger, fontSize: 12, fontWeight: '700' },
  muted: { color: theme.muted, fontSize: 13 },
  error: { color: theme.danger, fontSize: 13, marginBottom: 12 },
});
