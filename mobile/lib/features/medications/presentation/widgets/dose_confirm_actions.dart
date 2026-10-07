import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/medication.dart';
import '../bloc/medication_bloc.dart';

/// Stock line + "Tomei" / "Não tomei" for one medication. Each tap posts
/// `/medications/{id}/confirm`: an adherence signal, never a prescription.
class DoseConfirmActions extends StatelessWidget {
  const DoseConfirmActions({super.key, required this.medication});

  final Medication medication;

  @override
  Widget build(BuildContext context) {
    final busy = context.select<MedicationBloc, bool>(
      (bloc) => bloc.state.confirmingIds.contains(medication.id),
    );
    final stock = medication.stockDoses;
    final text = Theme.of(context).textTheme;

    void confirm(bool taken) => context
        .read<MedicationBloc>()
        .add(ConfirmDoseEvent(medication.id, taken: taken));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stock != null) ...[
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: stock == 0 ? AppColors.error : AppColors.textSecondary,
              ),
              const SizedBox(width: AppDimensions.xs),
              Flexible(
                child: Text(
                  stock == 0
                      ? 'Estoque esgotado'
                      : 'Estoque: ${MedicationBloc.stockLabel(stock)}',
                  style: text.bodyMedium?.copyWith(
                    color:
                        stock == 0 ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
        ],
        Wrap(
          spacing: AppDimensions.sm,
          runSpacing: AppDimensions.sm,
          children: [
            FilledButton.icon(
              onPressed: busy ? null : () => confirm(true),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, AppDimensions.minTouchTarget),
              ),
              icon: busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                'Tomei',
                semanticsLabel: 'Tomei ${medication.name}',
              ),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : () => confirm(false),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, AppDimensions.minTouchTarget),
              ),
              icon: const Icon(Icons.close),
              label: Text(
                'Não tomei',
                semanticsLabel: 'Não tomei ${medication.name}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
