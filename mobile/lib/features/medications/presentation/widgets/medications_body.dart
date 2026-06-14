import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/async_state_views.dart';
import '../../domain/entities/medication.dart';
import '../bloc/medication_bloc.dart';
import 'medication_form_sheet.dart';

class MedicationsBody extends StatelessWidget {
  const MedicationsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicamentos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
      body: SafeArea(
        child: BlocBuilder<MedicationBloc, MedicationState>(
          builder: (context, state) {
            return switch (state.status) {
              MedicationStatus.loading => const LoadingView(),
              MedicationStatus.error => ErrorRetry(
                  message: state.errorMessage ?? 'Erro ao carregar.',
                  onRetry: () => context
                      .read<MedicationBloc>()
                      .add(const LoadMedicationsEvent()),
                ),
              MedicationStatus.ready => state.medications.isEmpty
                  ? const EmptyState(
                      message: 'Nenhum medicamento cadastrado. Toque em '
                          'Adicionar para incluir o primeiro.',
                      icon: Icons.medication_outlined,
                    )
                  : _MedicationList(medications: state.medications),
            };
          },
        ),
      ),
    );
  }

  static void _openForm(BuildContext context, [Medication? medication]) {
    final bloc = context.read<MedicationBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: MedicationFormSheet(medication: medication),
      ),
    );
  }
}

class _MedicationList extends StatelessWidget {
  const _MedicationList({required this.medications});

  final List<Medication> medications;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: medications.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final med = medications[index];
        final subtitleParts = [
          if (med.dosage != null && med.dosage!.isNotEmpty) med.dosage!,
          if (med.schedule != null && med.schedule!.isNotEmpty) med.schedule!,
        ];
        return ListTile(
          leading: const Icon(Icons.medication_outlined),
          title: Text(med.name),
          subtitle:
              subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
          onTap: () => MedicationsBody._openForm(context, med),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remover',
            onPressed: () => context
                .read<MedicationBloc>()
                .add(DeleteMedicationEvent(med.id)),
          ),
        );
      },
    );
  }
}
