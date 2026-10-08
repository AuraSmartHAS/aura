import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/medication.dart';
import '../../domain/schedule_input.dart';
import '../bloc/medication_bloc.dart';

/// Add/edit form shown as a bottom sheet.
class MedicationFormSheet extends StatefulWidget {
  const MedicationFormSheet({super.key, this.medication});

  final Medication? medication;

  @override
  State<MedicationFormSheet> createState() => _MedicationFormSheetState();
}

class _MedicationFormSheetState extends State<MedicationFormSheet> {
  late final TextEditingController _name;
  late final TextEditingController _dosage;
  late final TextEditingController _schedule;
  late final TextEditingController _notes;
  late final TextEditingController _stock;

  /// Inline error for the name field; null when valid.
  String? _nameError;

  /// Inline error for the schedule field (server only accepts `HH:mm`).
  String? _scheduleError;

  @override
  void initState() {
    super.initState();
    final med = widget.medication;
    _name = TextEditingController(text: med?.name);
    _dosage = TextEditingController(text: med?.dosage);
    _schedule = TextEditingController(text: med?.schedule);
    _notes = TextEditingController(text: med?.notes);
    _stock = TextEditingController(text: med?.stockDoses?.toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _schedule.dispose();
    _notes.dispose();
    _stock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.medication != null;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: AppDimensions.lg,
        right: AppDimensions.lg,
        top: AppDimensions.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isEdit ? 'Editar medicamento' : 'Novo medicamento',
              style: text.titleLarge,
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'Os dados ajudam a lembrar a rotina de cuidado.',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.lg),

            // ── Identificação ──────────────────────────────────────
            const _FieldGroupLabel('Identificação'),
            const SizedBox(height: AppDimensions.sm),
            TextField(
              controller: _name,
              autofocus: !isEdit,
              decoration: InputDecoration(
                labelText: 'Nome',
                hintText: 'Ex.: Losartana',
                prefixIcon: const Icon(Icons.medication_outlined),
                errorText: _nameError,
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: AppDimensions.sm),
            TextField(
              controller: _dosage,
              decoration: const InputDecoration(
                labelText: 'Dosagem',
                hintText: 'Ex.: 500mg, 1 comprimido',
                prefixIcon: Icon(Icons.science_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppDimensions.lg),

            // ── Horário ────────────────────────────────────────────
            const _FieldGroupLabel('Quando tomar'),
            const SizedBox(height: AppDimensions.sm),
            TextField(
              controller: _schedule,
              decoration: InputDecoration(
                labelText: 'Horários',
                hintText: 'Ex.: 08:00, 20:00',
                helperText: 'Formato HH:mm, separados por vírgula. '
                    'Ou use uma sugestão abaixo.',
                helperMaxLines: 2,
                errorText: _scheduleError,
                errorMaxLines: 3,
                prefixIcon: const Icon(Icons.schedule_outlined),
              ),
              keyboardType: TextInputType.datetime,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_scheduleError != null) {
                  setState(() => _scheduleError = null);
                }
              },
            ),
            const SizedBox(height: AppDimensions.sm),
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: [
                for (final (label, time) in const [
                  ('Manhã', '08:00'),
                  ('Tarde', '14:00'),
                  ('Noite', '20:00'),
                  ('Antes de dormir', '22:00'),
                ])
                  _ScheduleSuggestion(
                    label: '$label · $time',
                    onTap: () => _applySchedule(time),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.lg),

            // ── Estoque ────────────────────────────────────────────
            const _FieldGroupLabel('Estoque em casa'),
            const SizedBox(height: AppDimensions.sm),
            TextField(
              controller: _stock,
              decoration: InputDecoration(
                labelText: isEdit ? 'Doses em estoque' : 'Estoque inicial',
                hintText: 'Ex.: 30',
                helperText: 'Opcional. Em doses; cada "Tomei" desconta uma.',
                suffixText: 'doses',
                prefixIcon: const Icon(Icons.inventory_2_outlined),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppDimensions.lg),

            // ── Observações ────────────────────────────────────────
            const _FieldGroupLabel('Observações'),
            const SizedBox(height: AppDimensions.sm),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Observações',
                hintText: 'Ex.: tomar com alimento',
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: AppDimensions.xl),

            SizedBox(
              height: AppDimensions.minTouchTarget,
              child: FilledButton.icon(
                onPressed: () => _save(context),
                icon: const Icon(Icons.check),
                label: Text(isEdit ? 'Salvar alterações' : 'Adicionar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Appends an `HH:mm` suggestion to the schedule field instead of
  /// overwriting, so the caregiver can combine several (e.g. "08:00, 20:00").
  /// A time already in the field is not repeated.
  void _applySchedule(String time) {
    final current = _schedule.text.trim();
    final present = current.split(RegExp(r'[,;\s]+')).contains(time);
    if (!present) {
      _schedule.text = current.isEmpty ? time : '$current, $time';
    }
    _schedule.selection = TextSelection.fromPosition(
      TextPosition(offset: _schedule.text.length),
    );
    if (_scheduleError != null) setState(() => _scheduleError = null);
  }

  void _save(BuildContext context) {
    final nameMissing = _name.text.trim().isEmpty;
    final schedule = parseScheduleInput(_schedule.text);
    if (nameMissing || !schedule.isValid) {
      setState(() {
        _nameError = nameMissing ? 'Informe o nome do medicamento.' : null;
        _scheduleError = schedule.error;
      });
      return;
    }
    context.read<MedicationBloc>().add(
          SaveMedicationEvent(
            id: widget.medication?.id,
            name: _name.text.trim(),
            dosage: _text(_dosage),
            times: schedule.times,
            notes: _text(_notes),
            stockDoses: int.tryParse(_stock.text.trim()),
          ),
        );
    Navigator.of(context).pop();
  }

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();
}

/// Small uppercase-ish section label that groups related fields.
class _FieldGroupLabel extends StatelessWidget {
  const _FieldGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(color: AppColors.textSecondary),
    );
  }
}

/// A tappable quick-fill chip for the Horário field.
class _ScheduleSuggestion extends StatelessWidget {
  const _ScheduleSuggestion({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Adicionar horário $label',
      child: Material(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          child: ConstrainedBox(
            // WCAG 2.5.5: keep the tappable chip at least 48dp tall.
            constraints: const BoxConstraints(
              minHeight: AppDimensions.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md,
                vertical: AppDimensions.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 16, color: AppColors.primary),
                  const SizedBox(width: AppDimensions.xs),
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
