import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/utils/care_time.dart';
import '../../../caregiver_dashboard/domain/entities/care_today.dart';
import '../../domain/entities/medication.dart';
import '../bloc/medication_bloc.dart';

/// O que a família vê no lugar de "Tomei / Não tomei": o resultado de hoje.
/// Quem confirma a dose é a Maria (pela voz ou pelo app); confirmar por ela
/// aqui sujaria a adesão que o resto do sistema lê.
class CaregiverDoseStatus extends StatelessWidget {
  const CaregiverDoseStatus({super.key, required this.medication, this.now});

  final Medication medication;
  final DateTime? now;

  /// Estoque que já pede reposição.
  static const int lowStock = 3;

  @override
  Widget build(BuildContext context) {
    final today = context.select<MedicationBloc, MedicationToday?>(
      (bloc) => bloc.state.todayById[medication.id],
    );
    final text = Theme.of(context).textTheme;
    final stock = medication.stockDoses;
    final clock = now ?? DateTime.now();

    final todayStatus = context.select<MedicationBloc, TodayStatus>(
      (bloc) => bloc.state.todayStatus,
    );

    final lines = <_Line>[
      if (todayStatus == TodayStatus.failed)
        const _Line(Icons.cloud_off_outlined,
            'Não consegui carregar o status de hoje', AppColors.warning),
      if (today != null) _statusLine(today, clock),
      if (today != null && today.declinedToday)
        const _Line(Icons.cancel_outlined, 'Disse que não tomou', AppColors.error),
      if (stock != null)
        stock == 0
            ? const _Line(
                Icons.inventory_2_outlined, 'Estoque esgotado', AppColors.error)
            : stock <= lowStock
                ? _Line(Icons.inventory_2_outlined,
                    'Estoque baixo: ${MedicationBloc.stockLabel(stock)}',
                    AppColors.warning)
                : _Line(Icons.inventory_2_outlined,
                    'Estoque: ${MedicationBloc.stockLabel(stock)}',
                    AppColors.textSecondary),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();

    return Semantics(
      container: true,
      label: lines.map((l) => l.text).join('. '),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.xs),
                child: Row(
                  children: [
                    Icon(line.icon, size: 18, color: line.color),
                    const SizedBox(width: AppDimensions.xs),
                    Flexible(
                      child: Text(
                        line.text,
                        style: text.bodyMedium?.copyWith(color: line.color),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  _Line _statusLine(MedicationToday today, DateTime clock) {
    String taken() {
      final at = today.lastTakenAt;
      if (at == null) return 'Tomou';
      final src = today.lastSource;
      return 'Tomou às ${careClock(at, clock).replaceFirst('ontem ', '')}'
          '${src == null ? '' : ' · ${src.label}'}';
    }

    switch (today.status) {
      case DoseStatus.complete:
        return _Line(Icons.check_circle, taken(), AppColors.confirm);
      case DoseStatus.onTrack:
        return today.takenCount > 0
            ? _Line(Icons.check_circle_outline,
                '${taken()} · próxima ${today.nextTime}', AppColors.confirm)
            : _Line(Icons.schedule, 'Próxima às ${today.nextTime}',
                AppColors.confirm);
      case DoseStatus.late:
        return _Line(
          Icons.error_outline,
          today.takenCount > 0
              ? 'Atrasada: era às ${today.nextTime} · ${taken()}'
              : 'Atrasada: era às ${today.nextTime}',
          AppColors.warning,
        );
      case DoseStatus.asNeeded:
        return const _Line(
            Icons.more_horiz, 'Quando necessário', AppColors.textTertiary);
    }
  }
}

class _Line {
  const _Line(this.icon, this.text, this.color);

  final IconData icon;
  final String text;
  final Color color;
}
