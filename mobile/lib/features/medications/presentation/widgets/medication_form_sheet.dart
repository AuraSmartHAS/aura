import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    return Padding(
      padding: EdgeInsets.only(
        left: AppDimensions.lg,
        right: AppDimensions.lg,
        top: AppDimensions.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimensions.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEdit ? 'Editar medicamento' : 'Novo medicamento',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppDimensions.md),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nome'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppDimensions.sm),
          TextField(
            controller: _dosage,
            decoration: const InputDecoration(labelText: 'Dosagem (ex.: 500mg)'),
          ),
          const SizedBox(height: AppDimensions.sm),
          TextField(
            controller: _schedule,
            decoration:
                const InputDecoration(labelText: 'Horário (ex.: 8h e 20h)'),
          ),
          const SizedBox(height: AppDimensions.sm),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Observações'),
          ),
          const SizedBox(height: AppDimensions.lg),
          SizedBox(
            height: AppDimensions.minTouchTarget,
            child: FilledButton(
              onPressed: () => _save(context),
              child: const Text('Salvar'),
            ),
          ),
        ],
      ),
    );
  }

  void _save(BuildContext context) {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do medicamento.')),
      );
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
