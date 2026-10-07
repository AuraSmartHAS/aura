import React from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';
import type { ActiveEmergency } from '../api';
import {
  careAgo,
  isOpenEmergency,
  careClock,
  sourceLabel,
  stockLabel,
  takenLine,
  type CareActivity,
  type MedicationToday,
} from '../careToday';
import { fontFamily, minTouchTarget, radius, spacing, theme } from '../theme';

/** Estoque que já pede reposição. */
export const LOW_STOCK = 3;

type SosProps = {
  emergency: ActiveEmergency;
  patientFirstName: string;
  acknowledging: boolean;
  acknowledgeFailed: boolean;
  onAcknowledge: () => void;
  now: Date;
};

/**
 * Faixa de SOS: o que a família não pode deixar de ver, e a única ação
 * ("Estou indo") que fecha o ciclo aberto pelo agente de voz ou pelo botão.
 */
export function SosAlertCard({
  emergency,
  patientFirstName,
  acknowledging,
  acknowledgeFailed,
  onAcknowledge,
  now,
}: SosProps) {
  const acknowledged = emergency.state === 'acknowledged';
  const open = isOpenEmergency(emergency);
  // Aberto: vermelho. Confirmado: verde. Encerrado (cancelou, ou ninguém sabe como): neutro — não
  // há mais o que fazer, mas o aviso não some calado.
  const color = open ? theme.danger : acknowledged ? theme.confirm : theme.text;
  const since = emergency.createdAt ? careAgo(new Date(emergency.createdAt), now) : null;

  const detail = (() => {
    switch (emergency.state) {
      case 'waiting_cancel':
        return `${patientFirstName} ainda pode cancelar nos próximos segundos. O aviso sai logo em seguida.`;
      case 'dispatched':
        return 'O aviso saiu e ninguém confirmou ainda.';
      case 'escalated':
        return 'Ninguém respondeu a tempo, e o aviso foi para os outros contatos.';
      case 'acknowledged':
        return emergency.acknowledgedByName
          ? `${emergency.acknowledgedByName} avisou que está indo.`
          : 'Você avisou que está indo.';
      case 'cancelled':
        return 'Foi engano. Nada precisa ser feito.';
      case 'closed':
        return 'O pedido deixou de estar em aberto.';
      default:
        return 'Confirme para quem está cuidando que você viu.';
    }
  })();
  const title = (() => {
    switch (emergency.state) {
      case 'acknowledged':
        return `${patientFirstName} pediu ajuda · alguém está indo`;
      case 'cancelled':
        return `${patientFirstName} cancelou o pedido de ajuda`;
      case 'closed':
        return `Pedido de ajuda de ${patientFirstName} encerrado`;
      default:
        return `${patientFirstName} pediu ajuda`;
    }
  })();

  return (
    <View
      accessible
      accessibilityLiveRegion="assertive"
      accessibilityLabel={`${title}. ${detail}`}
      style={[styles.sos, { borderColor: color, backgroundColor: `${color}14` }]}
    >
      <Text style={styles.sosTitle}>{title}</Text>
      {since !== null && <Text style={styles.meta}>{`Pedido ${since}`}</Text>}
      <Text style={styles.sosDetail}>{detail}</Text>
      {acknowledgeFailed && <Text style={styles.sosError}>Não consegui confirmar agora. Tente de novo.</Text>}
      {open && (
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Estou indo"
          disabled={acknowledging}
          onPress={onAcknowledge}
          style={({ pressed }) => [styles.sosButton, (pressed || acknowledging) && styles.pressed]}
        >
          {acknowledging ? (
            <ActivityIndicator color="#FFFFFF" />
          ) : (
            <Text style={styles.sosButtonText}>Estou indo</Text>
          )}
        </Pressable>
      )}
    </View>
  );
}

type MedsProps = {
  items: MedicationToday[];
  now: Date;
  /** Falso quando os remédios ou os sinais não carregaram: lista vazia não quer dizer "nenhum remédio". */
  available?: boolean;
  onPress?: () => void;
};

/** "Remédios de hoje": a resposta para "a Maria já tomou?". */
export function MedicationsTodayCard({ items, now, available = true, onPress }: MedsProps) {
  if (!available) {
    return (
      <View style={styles.card}>
        <Text accessibilityRole="header" style={styles.cardTitle}>
          Remédios de hoje
        </Text>
        <Text style={styles.loadFailed}>Não consegui carregar os remédios de hoje agora.</Text>
      </View>
    );
  }

  const attention = items.filter((m) => m.status === 'late' || m.declinedToday).length;
  const summary =
    items.length === 0
      ? 'Nenhum remédio cadastrado ainda.'
      : attention > 0
        ? `${attention} ${attention === 1 ? 'pede' : 'pedem'} atenção`
        : 'Tudo em dia até agora';

  const body = (
    <View style={styles.card}>
      <View style={styles.cardHead}>
        <Text accessibilityRole="header" style={styles.cardTitle}>
          Remédios de hoje
        </Text>
        {items.length > 0 && (
          <Text style={[styles.summary, { color: attention > 0 ? theme.accent : theme.confirm }]}>{summary}</Text>
        )}
        {onPress ? <Text style={styles.chevron}>›</Text> : null}
      </View>
      {items.length === 0 ? (
        <Text style={styles.muted}>{summary}</Text>
      ) : (
        items.map((item, index) => (
          <View key={item.medication.id} style={index > 0 && styles.rowDivider}>
            <MedicationRow item={item} now={now} />
          </View>
        ))
      )}
    </View>
  );

  if (!onPress) return body;
  return (
    <Pressable accessibilityRole="button" accessibilityHint="Abrir medicamentos" onPress={onPress}>
      {body}
    </Pressable>
  );
}

/** Linha de status de um remédio: usada no card de hoje e na tela de Medicamentos. */
export function statusLine(item: MedicationToday, now: Date): { text: string; color: string } {
  const taken = takenLine(item, now);
  switch (item.status) {
    case 'complete':
      return { text: taken, color: theme.confirm };
    case 'onTrack':
      return {
        text: item.takenCount > 0 ? `${taken} · próxima ${item.nextTime}` : `Próxima às ${item.nextTime}`,
        color: theme.confirm,
      };
    case 'late':
      return {
        text:
          item.takenCount > 0
            ? `Atrasada: era às ${item.nextTime} · ${taken}`
            : `Atrasada: era às ${item.nextTime}`,
        color: theme.accent,
      };
    default:
      return { text: 'Quando necessário', color: theme.muted };
  }
}

function MedicationRow({ item, now }: { item: MedicationToday; now: Date }) {
  const med = item.medication;
  const { text, color } = statusLine(item, now);
  const name = med.dosage ? `${med.name} · ${med.dosage}` : med.name;

  return (
    <View
      accessible
      accessibilityLabel={`${name}. ${text}${item.declinedToday ? '. Disse que não tomou.' : ''}`}
      style={styles.medRow}
    >
      <Text style={styles.medName}>{name}</Text>
      <Text style={[styles.medStatus, { color }]}>{text}</Text>
      {item.declinedToday && <Text style={[styles.medStatus, { color: theme.danger }]}>Disse que não tomou</Text>}
    </View>
  );
}

type TimelineProps = {
  items: CareActivity[];
  patientFirstName: string;
  now: Date;
  /** Falso quando os sinais não carregaram. */
  available?: boolean;
};

/** "O que aconteceu": o que a Maria disse e fez, do mais novo ao mais antigo. */
export function TimelineCard({ items, patientFirstName, now, available = true }: TimelineProps) {
  if (!available) {
    return (
      <View style={styles.card}>
        <Text accessibilityRole="header" style={styles.cardTitle}>
          O que aconteceu
        </Text>
        <Text style={styles.loadFailed}>Não consegui carregar o que aconteceu agora.</Text>
      </View>
    );
  }

  return (
    <View style={styles.card}>
      <Text accessibilityRole="header" style={styles.cardTitle}>
        O que aconteceu
      </Text>
      {items.length === 0 ? (
        <Text style={styles.muted}>
          {`Nada registrado ainda. Quando ${patientFirstName} conversar com a Aura, aparece aqui.`}
        </Text>
      ) : (
        items.map((item) => {
          const when = careClock(item.occurredAt, now);
          const color = item.kind === 'sos' ? theme.danger : item.concerning ? theme.accent : theme.muted;
          return (
            <View
              key={item.id}
              accessible
              accessibilityLabel={`${when}. ${item.title}, ${sourceLabel[item.source]}`}
              style={styles.timelineRow}
            >
              <Text style={styles.timelineWhen}>{when}</Text>
              <View style={[styles.dot, { backgroundColor: color }]} />
              <View style={styles.timelineText}>
                <Text style={styles.timelineTitle}>{item.title}</Text>
                <Text style={styles.meta}>{sourceLabel[item.source]}</Text>
              </View>
            </View>
          );
        })
      )}
    </View>
  );
}

/** Aviso de que a tela pode não estar mostrando a verdade (não deu para verificar o SOS, ou o que se vê está velho). */
export function ConnectionNotice({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <View accessible accessibilityLiveRegion="polite" accessibilityLabel={message} style={styles.notice}>
      <Text style={styles.noticeText}>{message}</Text>
      {onRetry && (
        <Pressable accessibilityRole="button" accessibilityLabel="Tentar de novo" onPress={onRetry} style={styles.noticeRetry}>
          <Text style={styles.noticeRetryText}>Tentar de novo</Text>
        </Pressable>
      )}
    </View>
  );
}

/** O que a família vê no lugar de "Tomei / Não tomei": o resultado de hoje e o estoque. */
export function CaregiverDoseStatus({
  item,
  stockDoses,
  now,
}: {
  item: MedicationToday | undefined;
  stockDoses: number | null;
  now: Date;
}) {
  const lines: { text: string; color: string }[] = [];
  if (item) lines.push(statusLine(item, now));
  if (item?.declinedToday) lines.push({ text: 'Disse que não tomou', color: theme.danger });
  if (stockDoses !== null) {
    if (stockDoses === 0) lines.push({ text: 'Estoque esgotado', color: theme.danger });
    else if (stockDoses <= LOW_STOCK) lines.push({ text: `Estoque baixo: ${stockLabel(stockDoses)}`, color: theme.accent });
    else lines.push({ text: `Estoque: ${stockLabel(stockDoses)}`, color: theme.text });
  }
  if (lines.length === 0) return null;

  return (
    <View accessible accessibilityLabel={lines.map((l) => l.text).join('. ')}>
      {lines.map((line) => (
        <Text key={line.text} style={[styles.medStatus, { color: line.color }]}>
          {line.text}
        </Text>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  sos: { borderWidth: 2, borderRadius: radius.lg, padding: spacing.md + 4, marginBottom: spacing.md },
  sosTitle: { color: theme.ink, fontSize: 20, fontFamily: fontFamily.displaySemibold },
  sosDetail: { color: theme.textStrong, fontSize: 15, marginTop: spacing.sm, fontFamily: fontFamily.body },
  sosError: { color: theme.danger, fontSize: 13, marginTop: spacing.sm, fontFamily: fontFamily.bodyBold },
  sosButton: {
    marginTop: spacing.md,
    minHeight: 56,
    borderRadius: radius.md,
    backgroundColor: theme.danger,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sosButtonText: { color: '#FFFFFF', fontSize: 17, fontFamily: fontFamily.bodyBold },
  pressed: { opacity: 0.7 },
  card: {
    backgroundColor: theme.surface,
    borderColor: theme.border,
    borderWidth: 1,
    borderRadius: radius.lg,
    padding: spacing.md,
    marginBottom: spacing.sm + 4,
  },
  cardHead: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  cardTitle: { color: theme.ink, fontSize: 16, fontFamily: fontFamily.displaySemibold, marginBottom: spacing.sm },
  summary: { fontSize: 12, fontFamily: fontFamily.bodyBold, marginBottom: spacing.sm },
  muted: { color: theme.muted, fontSize: 13, fontFamily: fontFamily.body },
  chevron: { color: theme.muted, fontSize: 22, marginLeft: spacing.sm, marginBottom: spacing.sm },
  loadFailed: { color: theme.accent, fontSize: 13, fontFamily: fontFamily.bodyBold },
  notice: {
    borderColor: theme.accent,
    borderWidth: 1,
    backgroundColor: `${theme.accent}14`,
    borderRadius: radius.md,
    padding: spacing.md,
    marginBottom: spacing.md,
  },
  noticeText: { color: theme.textStrong, fontSize: 14, fontFamily: fontFamily.body },
  noticeRetry: { alignSelf: 'flex-end', minHeight: minTouchTarget, justifyContent: 'center', paddingHorizontal: spacing.sm },
  noticeRetryText: { color: theme.primary, fontSize: 14, fontFamily: fontFamily.bodyBold },
  meta: { color: theme.muted, fontSize: 12, fontFamily: fontFamily.body },
  rowDivider: { borderTopColor: theme.border, borderTopWidth: 1, marginTop: spacing.sm + 4, paddingTop: spacing.sm + 4 },
  medRow: { minHeight: minTouchTarget - 8, justifyContent: 'center' },
  medName: { color: theme.ink, fontSize: 15, fontFamily: fontFamily.bodyBold },
  medStatus: { fontSize: 13, marginTop: 2, fontFamily: fontFamily.body },
  timelineRow: { flexDirection: 'row', alignItems: 'flex-start', marginTop: spacing.sm + 4 },
  timelineWhen: { width: 64, color: theme.muted, fontSize: 12, fontFamily: fontFamily.body, paddingTop: 2 },
  dot: { width: 8, height: 8, borderRadius: 4, marginTop: 6, marginRight: spacing.sm },
  timelineText: { flex: 1 },
  timelineTitle: { color: theme.textStrong, fontSize: 14, fontFamily: fontFamily.body },
});
