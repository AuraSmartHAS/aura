import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/models/severity_level.dart';
import '../../../../shared/utils/care_time.dart';
import '../../../../shared/widgets/async_state_views.dart';
import '../../../../shared/widgets/factor_bar.dart';
import '../../../../shared/widgets/severity_chip.dart';
import '../../../wellbeing360/domain/entities/score.dart';
import '../bloc/dashboard_bloc.dart';
import 'family_today_cards.dart';

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

    final who = state.patientFirstName;

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.md),
      children: [
        // O SOS vem antes de tudo: é a única coisa que não espera.
        if (state.activeEmergency != null) ...[
          SosAlertCard(
            emergency: state.activeEmergency!,
            patientFirstName: who,
            acknowledging: state.acknowledging,
            acknowledgeFailed: state.acknowledgeFailed,
            now: state.asOf,
          ),
          const SizedBox(height: AppDimensions.lg),
        ],
        // Não sei se há SOS: dizer "nada" seria mentir. Dizer que não deu para
        // verificar é a única resposta honesta.
        if (!state.emergencyKnown && state.activeEmergency == null) ...[
          ConnectionNotice(
            message: 'Não consegui verificar se há um pedido de ajuda agora.',
            onRetry: () => context
                .read<DashboardBloc>()
                .add(const DashboardPolledEvent()),
          ),
          const SizedBox(height: AppDimensions.md),
        ],
        // O polling vem falhando: o que está na tela pode estar velho.
        if (state.staleSince != null) ...[
          ConnectionNotice(
            message: 'Sem conexão com o servidor. O que você vê pode estar '
                'desatualizado (última atualização às '
                '${careClock(state.lastSyncAt ?? state.staleSince!, state.asOf ?? state.staleSince!)}).',
          ),
          const SizedBox(height: AppDimensions.md),
        ],
        DashboardHeader(
          userFirstName: state.userFirstName,
          patientName: patient,
          address: detail.home.address,
          lastActivityAt: state.lastActivityAt,
          needsAttention: state.needsAttention,
          dataComplete: state.dataComplete,
          now: state.asOf,
        ),
        const SizedBox(height: AppDimensions.lg),

        // O dia dela: remédios e o que ela disse e fez — o que a família quer
        // saber antes de qualquer nota de risco.
        TodayMedicationsCard(
          items: state.medicationsToday,
          patientFirstName: who,
          available: state.todayAvailable,
          now: state.asOf,
        ),
        const SizedBox(height: AppDimensions.md),
        TimelineCard(
          items: state.timeline,
          patientFirstName: who,
          available: state.signalsLoaded,
          now: state.asOf,
        ),
        const SizedBox(height: AppDimensions.lg),

        // Risk drives attention. Its treatment escalates with severity
        // (calm green → amber → red alert banner for high).
        _TopRiskHero(top: top, loaded: state.scoresLoaded),
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
///
/// A saudação usa o primeiro nome de quem está logado; sem um nome utilizável
/// fica só "Boa noite" — nunca um nome inventado.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.userFirstName,
    required this.patientName,
    required this.address,
    this.lastActivityAt,
    this.needsAttention = false,
    this.dataComplete = true,
    this.now,
  });

  final String? userFirstName;
  final String patientName;
  final String address;

  /// "Tudo em ordem" só quando nada pede atenção E tudo carregou.
  bool get _ok => !needsAttention && dataComplete;

  /// Quando a paciente fez ou disse algo pela última vez; `null` esconde a
  /// linha em vez de afirmar "atualizado agora" sem saber.
  final DateTime? lastActivityAt;

  /// Há algo que pede olhar (SOS, dose atrasada, risco alto).
  final bool needsAttention;

  /// Tudo carregou e está atualizado. Falso: a tela não pode dizer "Tudo em ordem".
  final bool dataComplete;

  /// Relógio da última leitura (testável); `null` usa a hora atual.
  final DateTime? now;

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
          userFirstName == null ? greeting : '$greeting, $userFirstName',
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
            Icon(
              _ok ? Icons.check_circle_outline : Icons.error_outline,
              size: 16,
              color: _ok ? AppColors.confirm : AppColors.warning,
            ),
            const SizedBox(width: AppDimensions.xs),
            Text(
              needsAttention
                  ? 'Há pontos de atenção'
                  : dataComplete
                      ? 'Tudo em ordem'
                      : 'Não consegui atualizar tudo',
              style: text.labelMedium?.copyWith(
                color: _ok ? AppColors.confirm : AppColors.warning,
              ),
            ),
            if (lastActivityAt != null) ...[
              const SizedBox(width: AppDimensions.sm),
              const Icon(
                Icons.schedule,
                size: 16,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: AppDimensions.xs),
              Flexible(
                child: Text(
                  'Última atividade ${careAgo(lastActivityAt!, now ?? DateTime.now())}',
                  style: text.labelMedium
                      ?.copyWith(color: AppColors.textTertiary),
                ),
              ),
            ],
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
  const _TopRiskHero({required this.top, this.loaded = true});

  final Score? top;

  /// Falso quando o risco não carregou: "sem leituras" e "não consegui
  /// carregar" não podem ser a mesma frase.
  final bool loaded;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    if (!loaded) {
      return _HeroShell(
        level: SeverityLevel.attention,
        semanticsLabel: 'Não consegui carregar o risco agora.',
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.warning),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(
                'Não consegui carregar o risco agora. Puxe a tela para baixo '
                'para tentar de novo.',
                style: text.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

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
    return (score.factorLabel(bestIndex), bestWeight);
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
        label: 'O que a casa precisa',
        hint: 'Com o motivo de cada recomendação',
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
