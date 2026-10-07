import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/async_state_views.dart';
import '../../domain/day_period_grouping.dart';
import '../../domain/entities/medication.dart';
import '../bloc/medication_bloc.dart';
import 'dose_confirm_actions.dart';
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
        child: BlocConsumer<MedicationBloc, MedicationState>(
          listenWhen: (prev, curr) =>
              curr.feedback != null && prev.feedback != curr.feedback,
          listener: (context, state) {
            final feedback = state.feedback!;
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(feedback.message),
                  backgroundColor: feedback.isError ? AppColors.error : null,
                ),
              );
          },
          builder: (context, state) {
            return switch (state.status) {
              MedicationStatus.loading => const LoadingView(
                  message: 'Carregando medicamentos...',
                ),
              MedicationStatus.error => ErrorRetry(
                  message: state.errorMessage ?? 'Erro ao carregar.',
                  onRetry: () => context
                      .read<MedicationBloc>()
                      .add(const LoadMedicationsEvent()),
                ),
              MedicationStatus.ready => state.medications.isEmpty
                  ? EmptyState(
                      title: 'Nenhum medicamento ainda',
                      message: 'Cadastre o primeiro medicamento para acompanhar '
                          'a rotina de cuidado.',
                      icon: Icons.medication_outlined,
                      actionLabel: 'Adicionar medicamento',
                      onAction: () => _openForm(context),
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
    // Grouped by period of the day from the `HH:mm` times; a medication with
    // times in several periods appears in each one (see day_period_grouping).
    final groups = groupByDayPeriod(medications);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.md,
        AppDimensions.md,
        // room so the FAB never hides the last card.
        AppDimensions.xxl + AppDimensions.xl,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final bucket = _TimeOfDay.of(group.period);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(timeOfDay: bucket, count: group.entries.length),
            const SizedBox(height: AppDimensions.sm),
            for (final entry in group.entries) ...[
              _MedicationCard(
                medication: entry.medication,
                times: entry.times,
                timeOfDay: bucket,
              ),
              const SizedBox(height: AppDimensions.sm),
            ],
            const SizedBox(height: AppDimensions.md),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.timeOfDay, required this.count});

  final _TimeOfDay timeOfDay;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(left: AppDimensions.xs),
      child: Row(
        children: [
          Icon(timeOfDay.icon, size: 20, color: timeOfDay.color),
          const SizedBox(width: AppDimensions.sm),
          Text(
            timeOfDay.label,
            style: text.titleMedium?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(width: AppDimensions.sm),
          Text(
            '$count',
            style: text.labelLarge?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({
    required this.medication,
    required this.times,
    required this.timeOfDay,
  });

  final Medication medication;

  /// Only the times of this card's period.
  final List<String> times;
  final _TimeOfDay timeOfDay;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dosage = medication.dosage;
    final schedule = times.isEmpty ? null : times.join(', ');
    final notes = medication.notes;

    return Semantics(
      button: true,
      label: '${medication.name}'
          '${dosage != null && dosage.isNotEmpty ? ', $dosage' : ''}'
          '${schedule != null && schedule.isNotEmpty ? ', $schedule' : ''}',
      child: Card(
        child: InkWell(
          onTap: () => MedicationsBody._openForm(context, medication),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time-of-day cue: tinted icon tile (color + icon, never
                // color-only).
                Container(
                  width: AppDimensions.minTouchTarget,
                  height: AppDimensions.minTouchTarget,
                  decoration: BoxDecoration(
                    color: timeOfDay.color.withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Icon(Icons.medication_outlined,
                      color: timeOfDay.color, size: 26),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
                        style: text.titleMedium
                            ?.copyWith(color: AppColors.textPrimary),
                      ),
                      if ((dosage != null && dosage.isNotEmpty) ||
                          (schedule != null && schedule.isNotEmpty)) ...[
                        const SizedBox(height: AppDimensions.sm),
                        Wrap(
                          spacing: AppDimensions.sm,
                          runSpacing: AppDimensions.xs,
                          children: [
                            if (dosage != null && dosage.isNotEmpty)
                              _InfoChip(
                                icon: Icons.science_outlined,
                                label: dosage,
                              ),
                            if (schedule != null && schedule.isNotEmpty)
                              _InfoChip(
                                icon: Icons.schedule_outlined,
                                label: schedule,
                              ),
                          ],
                        ),
                      ],
                      if (notes != null && notes.isNotEmpty) ...[
                        const SizedBox(height: AppDimensions.sm),
                        Text(
                          notes,
                          style: text.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: AppDimensions.md),
                      DoseConfirmActions(medication: medication),
                    ],
                  ),
                ),
                _DeleteButton(medication: medication),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet, readable pill carrying one fact (dosage or schedule).
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
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
    );
  }
}

/// Delete control that confirms before dispatching, so a tap can't silently
/// wipe a medication.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete_outline),
      color: AppColors.textTertiary,
      tooltip: 'Remover ${medication.name}',
      constraints: const BoxConstraints(
        minWidth: AppDimensions.minTouchTarget,
        minHeight: AppDimensions.minTouchTarget,
      ),
      onPressed: () => _confirmDelete(context),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bloc = context.read<MedicationBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover medicamento?'),
        content: Text(
          '"${medication.name}" será removido da lista. '
          'Você pode cadastrá-lo novamente depois.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(DeleteMedicationEvent(medication.id));
    }
  }
}

/// Visual cue (label, color + icon) of each [MedicationPeriod], so the list reads
/// as a daily routine.
enum _TimeOfDay {
  morning('Manhã', Icons.wb_twilight, AppColors.warning),
  afternoon('Tarde', Icons.wb_sunny_outlined, AppColors.primary),
  evening('Noite', Icons.nightlight_outlined, AppColors.careGreen),
  anytime('Sem horário definido', Icons.schedule_outlined,
      AppColors.textTertiary);

  const _TimeOfDay(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static _TimeOfDay of(MedicationPeriod period) => switch (period) {
        MedicationPeriod.morning => _TimeOfDay.morning,
        MedicationPeriod.afternoon => _TimeOfDay.afternoon,
        MedicationPeriod.evening => _TimeOfDay.evening,
        MedicationPeriod.unscheduled => _TimeOfDay.anytime,
      };
}
