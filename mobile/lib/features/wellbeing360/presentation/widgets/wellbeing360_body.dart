import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/models/severity_level.dart';
import '../../../../shared/widgets/async_state_views.dart';
import '../../../../shared/widgets/factor_bar.dart';
import '../../../../shared/widgets/severity_chip.dart';
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
    // Worst dimension drives the headline ("Maior atenção: ...").
    final worst = _worstScore(scores);
    final overall = worst.level;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        _OverviewCard(scores: scores, overall: overall, worst: worst),
        const SizedBox(height: AppDimensions.lg),
        Text(
          'As quatro dimensões',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: AppDimensions.sm),
        for (final score in scores) ...[
          WellbeingDimensionRow(
            dimension: WellbeingDimension(
              label: score.dimension.label,
              level: score.level,
              icon: _iconFor(score.dimension),
              detail: score.explanation.isEmpty ? null : score.explanation,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
        ],
        const SizedBox(height: AppDimensions.sm),
        const _TrustNote(),
      ],
    );
  }

  Score _worstScore(List<Score> scores) {
    // Highest severity wins; ties broken by raw score.
    final sorted = [...scores]..sort((a, b) {
        final byLevel = _rank(b.level).compareTo(_rank(a.level));
        if (byLevel != 0) return byLevel;
        return b.score.compareTo(a.score);
      });
    return sorted.first;
  }

  static int _rank(SeverityLevel level) => switch (level) {
        SeverityLevel.ok => 0,
        SeverityLevel.attention => 1,
        SeverityLevel.high => 2,
      };

  static IconData _iconFor(WellbeingDimensionType type) {
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

/// The focal element: a single composite card that lets the caregiver grasp the
/// whole picture in one glance — an aggregate headline + a stacked FactorBar
/// breakdown of every dimension (each bar colored by its own severity).
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.scores,
    required this.overall,
    required this.worst,
  });

  final List<Score> scores;
  final SeverityLevel overall;
  final Score worst;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = severityColor(overall);

    final (headline, sub) = switch (overall) {
      SeverityLevel.high => (
          'Maior atenção: ${worst.dimension.label.toLowerCase()}',
          'Uma dimensão está em risco alto hoje. Vale um olhar agora.',
        ),
      SeverityLevel.attention => (
          'Maior atenção: ${worst.dimension.label.toLowerCase()}',
          'Uma dimensão pede atenção hoje. As demais seguem estáveis.',
        ),
      SeverityLevel.ok => (
          'Tudo tranquilo hoje',
          'As quatro dimensões estão dentro do esperado.',
        ),
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.borderColor),
      ),
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: AppDimensions.sm,
                  height: AppDimensions.sm,
                  margin: const EdgeInsets.only(right: AppDimensions.sm),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    headline,
                    style: text.headlineSmall
                        ?.copyWith(color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(width: AppDimensions.sm),
                SeverityChip(
                  level: overall,
                  strong: overall == SeverityLevel.high,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            sub,
            style: text.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.lg),
          Container(height: 1, color: AppColors.borderColor),
          const SizedBox(height: AppDimensions.md),
          Text(
            'Panorama por dimensão',
            style: text.labelLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.xs),
          // Stacked, severity-colored breakdown — the signature "show the why".
          for (final score in scores)
            FactorBar(
              label: score.dimension.label,
              weight: score.score.clamp(0.0, 1.0),
              level: score.level,
              icon: _ScoresList._iconFor(score.dimension),
            ),
        ],
      ),
    );
  }
}

/// Surfaces the "Bem-estar, não diagnóstico" guardrail as an honest trust note
/// (UI-07) instead of a tiny gray footnote.
class _TrustNote extends StatelessWidget {
  const _TrustNote();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.shield_outlined,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bem-estar, não diagnóstico',
                    style: text.titleSmall
                        ?.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  Text(
                    'Estas leituras vêm de sensores e do wearable para apoiar o '
                    'cuidado. Não substituem avaliação médica.',
                    style: text.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
