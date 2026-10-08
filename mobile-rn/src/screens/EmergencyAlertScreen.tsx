import React, { useCallback, useEffect, useState } from 'react';
import { Linking, ScrollView, StyleSheet, Text, View } from 'react-native';
import { ActiveEmergency, api, Home } from '../api';
import AuraButton from '../components/AuraButton';
import type { ScreenProps } from '../navigation';
import { fontFamily, radius, spacing, theme } from '../theme';

type Props = ScreenProps<'EmergencyAlert'>;

const OPEN_STATES = ['waiting_cancel', 'dispatched', 'escalated'];
const EMERGENCY_PHONE = process.env.EXPO_PUBLIC_SOS_EMERGENCY_PHONE ?? '192';

function firstName(name: string | null | undefined): string {
  const first = (name ?? '').trim().split(/\s+/)[0];
  return first || 'Alguém da casa';
}

/** Link do mapa: coordenadas quando há, senão o endereço por extenso. */
export function mapUrl(lat?: number, lng?: number, address?: string | null): string | null {
  const query = lat !== undefined && lng !== undefined ? `${lat},${lng}` : address;
  return query ? `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(query)}` : null;
}

/**
 * "Pedido de ajuda": a tela que o toque no aviso de SOS abre no celular de quem cuida. Uma decisão
 * em destaque — "Estou indo" — e os dois caminhos de logo depois: chegar lá e chamar socorro.
 * O endereço do aviso vale enquanto a casa não responde: sem sinal, a tela ainda diz para onde ir.
 */
export default function EmergencyAlertScreen({ route }: Props) {
  const { emergencyId, homeId, address, lat, lng, autoAck } = route.params;
  const [emergency, setEmergency] = useState<ActiveEmergency | null>(null);
  const [home, setHome] = useState<Home | null>(null);
  const [loadFailed, setLoadFailed] = useState(false);
  const [acknowledging, setAcknowledging] = useState(false);
  const [ackFailed, setAckFailed] = useState(false);

  const refresh = useCallback(async () => {
    try {
      setEmergency(await api.emergencyOutcome(emergencyId));
      setLoadFailed(false);
    } catch {
      setLoadFailed(true);
    }
  }, [emergencyId]);

  useEffect(() => {
    // Veio do botão "Estou indo" do aviso: confirma ANTES de consultar. Os dois juntos corriam,
    // e o GET que saiu antes do ack e voltou depois mostrava "ninguém confirmou" (visto no Samsung).
    if (autoAck) {
      acknowledge();
    } else {
      refresh();
    }
    if (homeId) {
      api
        .homes()
        .then((homes) => setHome(homes.find((h) => h.id === homeId) ?? null))
        .catch(() => undefined);
    }
    // a Maria pode cancelar, outra pessoa pode dizer que está indo: o estado muda sem a gente
    const poll = setInterval(refresh, 10_000);
    return () => clearInterval(poll);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [refresh, homeId, autoAck]);

  async function acknowledge() {
    setAcknowledging(true);
    setAckFailed(false);
    try {
      setEmergency(await api.acknowledgeEmergency(emergencyId));
    } catch {
      setAckFailed(true);
      await refresh();
    } finally {
      setAcknowledging(false);
    }
  }

  const state = emergency?.state;
  const open = state === undefined || OPEN_STATES.includes(state);
  const quem = firstName(home?.patientName);
  const color = open ? theme.danger : state === 'acknowledged' ? theme.confirm : theme.text;
  const title =
    state === 'acknowledged'
      ? `${quem} pediu ajuda · alguém está indo`
      : state === 'cancelled'
        ? `${quem} cancelou o pedido de ajuda`
        : state === 'closed'
          ? 'Pedido de ajuda encerrado'
          : `${quem} pediu ajuda`;
  const detail =
    state === undefined
      ? loadFailed
        ? 'Não consegui ver o estado do pedido agora. Mesmo assim, você pode ir até lá.'
        : 'Carregando o pedido…'
      : state === 'waiting_cancel'
        ? `${quem} ainda pode cancelar nos próximos segundos.`
        : state === 'dispatched'
          ? 'Ninguém confirmou ainda. Se você vai, avise.'
          : state === 'escalated'
            ? 'Ninguém respondeu a tempo e o aviso foi para os outros contatos.'
            : state === 'acknowledged'
              ? emergency?.acknowledgedByName
                ? `${emergency.acknowledgedByName} avisou que está indo.`
                : 'Você avisou que está indo.'
              : state === 'cancelled'
                ? 'Foi engano. Nada precisa ser feito.'
                : 'O pedido deixou de estar em aberto.';
  const where = home?.address ?? address ?? null;
  const map = mapUrl(lat, lng, where);

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <View
        style={[styles.banner, { borderColor: color }]}
        accessible
        accessibilityLiveRegion="polite"
        accessibilityLabel={`${title}. ${detail}`}
      >
        <Text style={[styles.title, { color }]}>{title}</Text>
        <Text style={styles.detail}>{detail}</Text>
      </View>

      {home?.label ? <Text style={styles.home}>{home.label}</Text> : null}
      {where ? <Text style={styles.address}>{where}</Text> : null}

      <View style={styles.actions}>
        {open ? (
          <AuraButton title="Estou indo" variant="secondary" onPress={acknowledge} loading={acknowledging} disabled={!emergency} />
        ) : null}
        {ackFailed ? <Text style={styles.error}>Não consegui confirmar agora. Tente de novo ou ligue.</Text> : null}
        {map ? <AuraButton title="Abrir no mapa" variant="outline" onPress={() => Linking.openURL(map)} /> : null}
        <AuraButton
          title={`Ligar ${EMERGENCY_PHONE}`}
          variant="outline"
          onPress={() => Linking.openURL(`tel:${EMERGENCY_PHONE.replace(/[^0-9+]/g, '')}`)}
        />
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { padding: spacing.lg, gap: spacing.md },
  banner: { borderWidth: 2, borderRadius: radius.lg, padding: spacing.lg, backgroundColor: theme.surface },
  title: { fontFamily: fontFamily.display, fontSize: 22 },
  detail: { fontFamily: fontFamily.body, fontSize: 17, color: theme.textStrong, marginTop: spacing.sm },
  home: { fontFamily: fontFamily.displaySemibold, fontSize: 19, color: theme.textStrong },
  address: { fontFamily: fontFamily.body, fontSize: 17, color: theme.text },
  actions: { gap: spacing.md, marginTop: spacing.md },
  error: { fontFamily: fontFamily.body, fontSize: 15, color: theme.danger },
});
