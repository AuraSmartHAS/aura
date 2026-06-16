import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/medication.dart';
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

  /// Inline error for the name field; null when valid.
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final med = widget.medication;
    _name = TextEditingController(text: med?.name);
    _dosage = TextEditingController(text: med?.dosage);
    _schedule = TextEditingController(text: med?.schedule);
    _notes = TextEditingController(text: med?.notes);
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _schedule.dispose();
    _notes.dispose();
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
              decoration: const InputDecoration(
                labelText: 'Horário',
                hintText: 'Ex.: 8h e 20h',
                helperText: 'Escreva os horários ou use uma sugestão abaixo.',
                prefixIcon: Icon(Icons.schedule_outlined),
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppDimensions.sm),
            Wrap(
              spacing: AppDimensions.sm,
              runSpacing: AppDimensions.sm,
              children: [
                for (final suggestion in const [
                  'Manhã (8h)',
                  'Tarde (14h)',
                  'Noite (20h)',
                  'Antes de dormir',
                ])
                  _ScheduleSuggestion(
                    label: suggestion,
                    onTap: () => _applySchedule(suggestion),
                  ),
              ],
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

  /// Appends a suggestion to the schedule field instead of overwriting, so the
  /// caregiver can combine several (e.g. "8h e 20h").
  void _applySchedule(String suggestion) {
    final current = _schedule.text.trim();
    _schedule.text = current.isEmpty ? suggestion : '$current, $suggestion';
    _schedule.selection = TextSelection.fromPosition(
      TextPosition(offset: _schedule.text.length),
    );
  }

  void _save(BuildContext context) {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = 'Informe o nome do medicamento.');
      return;
    }
    context.read<MedicationBloc>().add(
          SaveMedicationEvent(
            id: widget.medication?.id,
            name: _name.text.trim(),
            dosage: _text(_dosage),
            schedule: _text(_schedule),
            notes: _text(_notes),
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
