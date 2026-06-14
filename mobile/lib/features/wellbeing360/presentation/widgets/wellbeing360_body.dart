import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/async_state_views.dart';
import '../../../../shared/widgets/wellbeing_dimension_row.dart';
import '../../domain/entities/score.dart';
import '../bloc/wellbeing360_bloc.dart';

class Wellbeing360Body extends StatelessWidget {
  const Wellbeing360Body({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoramento 360'),
        actions: [
          BlocBuilder<Wellbeing360Bloc, Wellbeing360State>(
            builder: (context, state) {
              return IconButton(
                tooltip: 'Recalcular risco',
                icon: state.isRecomputing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: state.isRecomputing
                    ? null
                    : () => context
                        .read<Wellbeing360Bloc>()
                        .add(const RecomputeScoresEvent()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<Wellbeing360Bloc, Wellbeing360State>(
          builder: (context, state) {
            return switch (state.status) {
              Wellbeing360Status.loading => const LoadingView(),
              Wellbeing360Status.error => ErrorRetry(
                  message: state.errorMessage ?? 'Erro ao carregar.',
                  onRetry: () => context
                      .read<Wellbeing360Bloc>()
                      .add(const LoadScoresEvent()),
                ),
              Wellbeing360Status.ready => state.scores.isEmpty
                  ? const EmptyState(
                      message: 'Sem leituras ainda. Recalcule o risco para '
                          'ver o panorama 360.',
                      icon: Icons.monitor_heart_outlined,
                    )
                  : _ScoresList(scores: state.scores),
            };
          },
        ),
      ),
    );
  }
}

class _ScoresList extends StatelessWidget {
  const _ScoresList({required this.scores});

  final List<Score> scores;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        for (final score in scores) ...[
          WellbeingDimensionRow(
            dimension: WellbeingDimension(
              label: score.dimension.label,
              level: score.level,
              icon: _iconFor(score.dimension),
              detail: score.explanation.isEmpty ? null : score.explanation,
            ),
          ),
          const Divider(),
        ],
        const SizedBox(height: AppDimensions.md),
        const _WearableBadge(),
      ],
    );
  }

  IconData _iconFor(WellbeingDimensionType type) {
    switch (type) {
      case WellbeingDimensionType.mobility:
        return Icons.directions_walk;
      case WellbeingDimensionType.sleep:
        return Icons.bedtime_outlined;
      case WellbeingDimensionType.cognition:
        return Icons.psychology_outlined;
      case WellbeingDimensionType.environment:
        return Icons.air;
    }
  }
}

/// Guardrail badge for wearable-derived data (UI-07).
class _WearableBadge extends StatelessWidget {
  const _WearableBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.info_outline, size: 16),
        const SizedBox(width: AppDimensions.xs),
        Text(
          'Bem-estar, não diagnóstico',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
