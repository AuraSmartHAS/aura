import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/models/severity_level.dart';
import '../../../../shared/widgets/async_state_views.dart';
import '../../../../shared/widgets/factor_bar.dart';
import '../../../../shared/widgets/severity_chip.dart';
import '../../../wellbeing360/domain/entities/score.dart';
import '../bloc/dashboard_bloc.dart';

class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AURA'),
        actions: [
          IconButton(
            tooltip: 'Sobre o AURA',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(AppRoutes.credits),
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            return switch (state.status) {
              DashboardStatus.loading => const LoadingView(),
              DashboardStatus.error => ErrorRetry(
                  message: state.errorMessage ?? 'Erro ao carregar.',
                  onRetry: () => context
                      .read<DashboardBloc>()
                      .add(const LoadDashboardEvent()),
                ),
              DashboardStatus.ready => RefreshIndicator(
                  onRefresh: () async => context
                      .read<DashboardBloc>()
                      .add(const LoadDashboardEvent()),
                  child: _DashboardContent(state: state),
                ),
            };
          },
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final detail = state.homeDetail!;
    final top = state.topScore;
    final patient = detail.patientName ?? detail.home.label;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        _DashboardHeader(patientName: patient, address: detail.home.address),
        const SizedBox(height: AppDimensions.lg),

        // FOCAL ELEMENT: risk drives the screen. Its treatment escalates with
        // severity (calm green → amber → red alert banner for high).
        _TopRiskHero(top: top),
        const SizedBox(height: AppDimensions.xl),

        Text(
          'Acompanhar',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppDimensions.md),
        const _ShortcutsGrid(),
      ],
    );
  }
}

/// Warm, personalized greeting: "Como a paciente está hoje" + time-of-day and
/// the home it refers to. Sets a calm, human tone before any risk signal.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.patientName, required this.address});

  final String patientName;
  final String address;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Bom dia'
        : hour < 18
            ? 'Boa tarde'
            : 'Boa noite';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, Ana',
          style: text.labelLarge?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppDimensions.xs),
        Text(
          'Como a $patientName está hoje',
          style: text.headlineMedium,
        ),
        const SizedBox(height: AppDimensions.sm),
        Row(
          children: [
            const Icon(
              Icons.place_outlined,
              size: 18,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: AppDimensions.xs),
            Expanded(
              child: Text(
                address,
                style:
                    text.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.xs),
        Row(
          children: [
            const Icon(
              Icons.schedule,
              size: 16,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: AppDimensions.xs),
            Text(
              'Atualizado agora',
              style: text.labelMedium?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ],
    );
  }
}

/// The hero: "maior risco agora". The whole card body is colored by severity
/// (border + tint), and a high level gets a strong alert banner. Shows the top
/// risk dimension, its observable trigger (the heaviest factor as a FactorBar),
/// and a CTA into Care-Chain.
class _TopRiskHero extends StatelessWidget {
  const _TopRiskHero({required this.top});

  final Score? top;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    // No readings yet — calm, honest empty state (still the focal card).
    if (top == null) {
      return _HeroShell(
        level: SeverityLevel.ok,
        semanticsLabel:
            'Maior risco agora: sem leituras ainda. Aguardando os primeiros dados.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Maior risco agora', style: text.labelLarge),
            const SizedBox(height: AppDimensions.sm),
            Text('Sem leituras ainda', style: text.headlineSmall),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'Assim que chegarem os primeiros dados do dia, o maior risco aparece aqui — sempre com o porquê.',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final score = top!;
    final color = severityColor(score.level);
    final trigger = _topTrigger(score);

    // Semantics summary for screen readers: dimension + level + trigger.
    final levelLabel = switch (score.level) {
      SeverityLevel.high => 'risco alto',
      SeverityLevel.attention => 'atenção',
      SeverityLevel.ok => 'tudo ok',
    };
    final semantics =
        'Maior risco agora: ${score.dimension.label}, $levelLabel.'
        '${trigger == null ? '' : ' Motivo: ${trigger.$1}.'}';

    return _HeroShell(
      level: score.level,
      semanticsLabel: semantics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // High risk gets a strong, filled alert banner up top.
          if (score.level == SeverityLevel.high) ...[
            SeverityChip(level: score.level, strong: true),
            const SizedBox(height: AppDimensions.md),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Maior risco agora', style: text.labelLarge),
                    const SizedBox(height: AppDimensions.xs),
                    Text(score.dimension.label, style: text.headlineMedium),
                  ],
                ),
              ),
              if (score.level != SeverityLevel.high) ...[
                const SizedBox(width: AppDimensions.sm),
                SeverityChip(level: score.level),
              ],
            ],
          ),
          const SizedBox(height: AppDimensions.md),

          // The observable trigger — the AURA signature "porquê".
          if (trigger != null) ...[
            Text(
              'O que estamos observando',
              style: text.labelMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.xs),
            FactorBar(
              label: trigger.$1,
              weight: trigger.$2,
              level: score.level,
              icon: Icons.insights_outlined,
            ),
          ] else if (score.explanation.isNotEmpty) ...[
            Text(
              score.explanation,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppDimensions.md),

          // CTA into Care-Chain (where the recommendation lives).
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(AppDimensions.minTouchTarget),
              ),
              onPressed: () => context.push(AppRoutes.careChain),
              icon: const Icon(Icons.recommend_outlined),
              label: const Text('Ver recomendação'),
            ),
          ),
        ],
      ),
    );
  }

  /// The heaviest weighted factor, paired with its weight (0..1). Returns null
  /// when the score carries no explainable factors.
  (String, double)? _topTrigger(Score score) {
    if (score.factors.isEmpty || score.weights.isEmpty) return null;
    var bestIndex = 0;
    var bestWeight = score.weights.first;
    final n = score.factors.length < score.weights.length
        ? score.factors.length
        : score.weights.length;
    for (var i = 1; i < n; i++) {
      if (score.weights[i] > bestWeight) {
        bestWeight = score.weights[i];
        bestIndex = i;
      }
    }
    return (score.factors[bestIndex], bestWeight);
  }
}

/// Severity-aware container for the hero card: a flat tinted surface with a
/// colored border that grows bolder with risk (the one place we spend boldness).
class _HeroShell extends StatelessWidget {
  const _HeroShell({
    required this.level,
    required this.semanticsLabel,
    required this.child,
  });

  final SeverityLevel level;
  final String semanticsLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(level);
    final borderWidth = level == SeverityLevel.high ? 2.0 : 1.5;

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: color, width: borderWidth),
        ),
        child: child,
      ),
    );
  }
}

/// Differentiated shortcut tiles — each with a tinted icon chip and a short
/// helper line, not four identical icon squares.
class _ShortcutsGrid extends StatelessWidget {
  const _ShortcutsGrid();

  @override
  Widget build(BuildContext context) {
    const items = [
      _Shortcut(
        icon: Icons.monitor_heart_outlined,
        label: 'Monitoramento 360',
        hint: 'Sono, mobilidade, ambiente',
        tint: AppColors.primary,
        route: AppRoutes.wellbeing,
      ),
      _Shortcut(
        icon: Icons.recommend_outlined,
        label: 'Care-Chain',
        hint: 'Recomendações explicáveis',
        tint: AppColors.careGreen,
        route: AppRoutes.careChain,
      ),
      _Shortcut(
        icon: Icons.medication_outlined,
        label: 'Medicamentos',
        hint: 'Lembretes e adesão',
        tint: AppColors.warning,
        route: AppRoutes.medications,
      ),
      _Shortcut(
        icon: Icons.watch_outlined,
        label: 'Wearable',
        hint: 'Sinais do dispositivo',
        tint: AppColors.primaryLight,
        route: AppRoutes.wearable,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: AppDimensions.sm),
          items[i],
        ],
      ],
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.hint,
    required this.tint,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color tint;
  final String route;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '$label. $hint',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: InkWell(
          onTap: () => context.push(route),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Container(
            constraints:
                const BoxConstraints(minHeight: AppDimensions.minTouchTarget),
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: AppDimensions.xxl,
                  height: AppDimensions.xxl,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Icon(icon, color: tint),
                ),
                const SizedBox(width: AppDimensions.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: text.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
