import React, { useEffect, useState } from 'react';
import {
  KeyboardAvoidingView,
  Modal,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import type { MedicationRecord } from '../api';
import {
  appendSchedule,
  parseScheduleInput,
  stockFromText,
  trimmedOrNull,
  type MedicationInput,
} from '../medications';
import { fontFamily, minTouchTarget, radius, spacing, theme } from '../theme';
import AuraButton from './AuraButton';

type Props = {
  visible: boolean;
  /** `null` = cadastrar; um remédio = editar. */
  medication: MedicationRecord | null;
  onCancel: () => void;
  /** Devolve o texto do erro quando não salvou: o formulário continua aberto e nada do que se digitou se perde. */
  onSubmit: (input: MedicationInput) => Promise<string | null>;
};

const SUGGESTIONS: [label: string, time: string][] = [
  ['Manhã', '08:00'],
  ['Tarde', '14:00'],
  ['Noite', '20:00'],
  ['Antes de dormir', '22:00'],
];

/** Formulário de cadastro e edição, em folha. Mesmos campos e regras do app Flutter. */
export default function MedicationFormModal({ visible, medication, onCancel, onSubmit }: Props) {
  const isEdit = medication !== null;
  const [name, setName] = useState('');
  const [dosage, setDosage] = useState('');
  const [schedule, setSchedule] = useState('');
  const [stock, setStock] = useState('');
  const [notes, setNotes] = useState('');
  const [nameError, setNameError] = useState<string | null>(null);
  const [scheduleError, setScheduleError] = useState<string | null>(null);
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  // Cada abertura começa do registro que está sendo editado (ou do zero).
  useEffect(() => {
    if (!visible) return;
    setName(medication?.name ?? '');
    setDosage(medication?.dosage ?? '');
    setSchedule(medication?.schedule.join(', ') ?? '');
    setStock(medication?.stockDoses != null ? String(medication.stockDoses) : '');
    setNotes(medication?.notes ?? '');
    setNameError(null);
    setScheduleError(null);
    setSubmitError(null);
    setSaving(false);
  }, [visible, medication]);

  async function save() {
    const nameMissing = name.trim().length === 0;
    const parsed = parseScheduleInput(schedule);
    if (nameMissing || parsed.error !== null) {
      setNameError(nameMissing ? 'Informe o nome do medicamento.' : null);
      setScheduleError(parsed.error);
      return;
    }
    setSaving(true);
    setSubmitError(null);
    const error = await onSubmit({
      name: name.trim(),
      dosage: trimmedOrNull(dosage),
      times: parsed.times,
      notes: trimmedOrNull(notes),
      stockDoses: stockFromText(stock),
    });
    if (error !== null) {
      setSubmitError(error);
      setSaving(false);
    }
  }

  return (
    <Modal
      visible={visible}
      animationType="slide"
      transparent
      // O botão voltar do Android não fecha o formulário no meio do salvamento: se a chamada
      // falhasse, o erro não teria onde aparecer e tudo o que foi digitado se perderia.
      onRequestClose={() => {
        if (!saving) onCancel();
      }}
    >
      <KeyboardAvoidingView
        style={styles.backdrop}
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      >
        <View style={styles.sheet}>
          <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={styles.content}>
            <Text accessibilityRole="header" style={styles.title}>
              {isEdit ? 'Editar medicamento' : 'Novo medicamento'}
            </Text>
            <Text style={styles.subtitle}>Os dados ajudam a lembrar a rotina de cuidado.</Text>

            <Text style={styles.group}>Identificação</Text>
            <Field label="Nome" error={nameError}>
              <TextInput
                value={name}
                onChangeText={(v) => {
                  setName(v);
                  if (nameError) setNameError(null);
                }}
                placeholder="Ex.: Losartana"
                placeholderTextColor={theme.muted}
                autoCapitalize="sentences"
                autoFocus={!isEdit}
                accessibilityLabel="Nome"
                style={[styles.input, nameError !== null && styles.inputError]}
              />
            </Field>
            <Field label="Dosagem">
              <TextInput
                value={dosage}
                onChangeText={setDosage}
                placeholder="Ex.: 500mg, 1 comprimido"
                placeholderTextColor={theme.muted}
                accessibilityLabel="Dosagem"
                style={styles.input}
              />
            </Field>

            <Text style={styles.group}>Quando tomar</Text>
            <Field
              label="Horários"
              error={scheduleError}
              helper="Formato HH:mm, separados por vírgula. Ou use uma sugestão abaixo."
            >
              <TextInput
                value={schedule}
                onChangeText={(v) => {
                  setSchedule(v);
                  if (scheduleError) setScheduleError(null);
                }}
                placeholder="Ex.: 08:00, 20:00"
                placeholderTextColor={theme.muted}
                accessibilityLabel="Horários"
                style={[styles.input, scheduleError !== null && styles.inputError]}
              />
            </Field>
            <View style={styles.chips}>
              {SUGGESTIONS.map(([label, time]) => (
                <Pressable
                  key={time}
                  accessibilityRole="button"
                  accessibilityLabel={`Adicionar horário ${label} ${time}`}
                  onPress={() => {
                    setSchedule((current) => appendSchedule(current, time));
                    setScheduleError(null);
                  }}
                  style={({ pressed }) => [styles.chip, pressed && styles.pressed]}
                >
                  <Text style={styles.chipText}>{`+ ${label} · ${time}`}</Text>
                </Pressable>
              ))}
            </View>

            <Text style={styles.group}>Estoque em casa</Text>
            <Field
              label={isEdit ? 'Doses em estoque' : 'Estoque inicial'}
              helper='Opcional. Em doses; cada "Tomei" desconta uma.'
            >
              <TextInput
                value={stock}
                // Só dígitos, como o campo do Flutter.
                onChangeText={(v) => setStock(v.replace(/\D/g, ''))}
                placeholder="Ex.: 30"
                placeholderTextColor={theme.muted}
                keyboardType="number-pad"
                accessibilityLabel={isEdit ? 'Doses em estoque' : 'Estoque inicial'}
                style={styles.input}
              />
            </Field>

            <Field label="Observações">
              <TextInput
                value={notes}
                onChangeText={setNotes}
                placeholder="Ex.: tomar com alimento"
                placeholderTextColor={theme.muted}
                autoCapitalize="sentences"
                multiline
                accessibilityLabel="Observações"
                style={[styles.input, styles.multiline]}
              />
            </Field>

            {submitError !== null && (
              <Text accessibilityLiveRegion="polite" style={styles.submitError}>
                {submitError}
              </Text>
            )}

            <View style={styles.actions}>
              <AuraButton
                title={isEdit ? 'Salvar alterações' : 'Adicionar'}
                onPress={save}
                loading={saving}
              />
              <View style={styles.gap} />
              <AuraButton title="Cancelar" variant="outline" onPress={onCancel} disabled={saving} />
            </View>
          </ScrollView>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

function Field({
  label,
  helper,
  error,
  children,
}: {
  label: string;
  helper?: string;
  error?: string | null;
  children: React.ReactNode;
}) {
  return (
    <View style={styles.field}>
      <Text style={styles.label}>{label}</Text>
      {children}
      {error ? (
        <Text accessibilityLiveRegion="polite" style={styles.error}>
          {error}
        </Text>
      ) : helper ? (
        <Text style={styles.helper}>{helper}</Text>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, justifyContent: 'flex-end', backgroundColor: 'rgba(16,48,60,0.45)' },
  sheet: {
    maxHeight: '92%',
    backgroundColor: theme.bg,
    borderTopLeftRadius: radius.lg + 8,
    borderTopRightRadius: radius.lg + 8,
  },
  content: { padding: spacing.lg, paddingBottom: spacing.xl },
  title: { color: theme.ink, fontSize: 20, fontFamily: fontFamily.displaySemibold },
  subtitle: { color: theme.text, fontSize: 13, marginTop: spacing.xs, fontFamily: fontFamily.body },
  group: { color: theme.text, fontSize: 13, marginTop: spacing.lg, fontFamily: fontFamily.bodyBold },
  field: { marginTop: spacing.sm },
  label: { color: theme.ink, fontSize: 13, marginBottom: spacing.xs, fontFamily: fontFamily.bodyBold },
  input: {
    minHeight: minTouchTarget,
    backgroundColor: theme.surface,
    borderColor: theme.border,
    borderWidth: 1,
    borderRadius: radius.md,
    paddingHorizontal: spacing.md,
    color: theme.ink,
    fontSize: 15,
    fontFamily: fontFamily.body,
  },
  inputError: { borderColor: theme.danger, borderWidth: 2 },
  multiline: { minHeight: 72, paddingTop: spacing.sm + 2, textAlignVertical: 'top' },
  helper: { color: theme.muted, fontSize: 12, marginTop: spacing.xs, fontFamily: fontFamily.body },
  error: { color: theme.danger, fontSize: 12, marginTop: spacing.xs, fontFamily: fontFamily.bodyBold },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, marginTop: spacing.sm },
  chip: {
    minHeight: minTouchTarget,
    justifyContent: 'center',
    paddingHorizontal: spacing.md,
    backgroundColor: theme.surfaceAlt,
    borderRadius: radius.sm,
  },
  chipText: { color: theme.ink, fontSize: 13, fontFamily: fontFamily.body },
  pressed: { opacity: 0.7 },
  submitError: { color: theme.danger, fontSize: 13, marginTop: spacing.md, fontFamily: fontFamily.bodyBold },
  actions: { marginTop: spacing.lg },
  gap: { height: spacing.sm + 2 },
});
