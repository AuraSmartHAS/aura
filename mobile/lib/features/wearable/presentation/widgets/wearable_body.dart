import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/widgets/async_state_views.dart';
import '../../domain/entities/vitals.dart';
import '../bloc/wearable_bloc.dart';

class WearableBody extends StatelessWidget {
  const WearableBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wearable')),
      body: SafeArea(
        child: BlocBuilder<WearableBloc, WearableState>(
          builder: (context, state) {
            final isLoading = state.status == WearableStatus.loading;
            final isReady = state.status == WearableStatus.ready;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Scrollable content area — replaces the old Spacer void so the
                // layout never floats apart and respects text scaling.
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.lg,
                      AppDimensions.lg,
                      AppDimensions.lg,
                      AppDimensions.md,
                    ),
                    children: [
                      _ConnectionHero(connected: isReady),
                      const SizedBox(height: AppDimensions.lg),
                      if (isReady) ...[
                        _VitalsSection(vitals: state.vitals!),
                        const SizedBox(height: AppDimensions.lg),
                      ],
                      if (state.status == WearableStatus.error) ...[
                        ErrorRetry(
                          message:
                              state.errorMessage ?? 'Não foi possível sincronizar.',
                          onRetry: () => context
                              .read<WearableBloc>()
                              .add(const ConnectWearableEvent()),
                        ),
                        const SizedBox(height: AppDimensions.lg),
                      ],
                      const _WellbeingDisclaimer(),
                    ],
                  ),
                ),
                // Stable bottom action bar — CTA always anchored, never adrift.
                _BottomActionBar(isLoading: isLoading, isReady: isReady),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Connection-state hero: a layered device illustration (not a lone tiny watch)
/// + the value proposition. Calm, high-contrast, state-aware.
class _ConnectionHero extends StatelessWidget {
  const _ConnectionHero({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = connected ? AppColors.careGreen : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          _DeviceGlyph(accent: accent, connected: connected),
          const SizedBox(height: AppDimensions.md),
          if (connected)
            _ConnectedBadge()
          else
            Text(
              'Conecte seu wearable',
              textAlign: TextAlign.center,
              style: text.headlineMedium,
            ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            connected
                ? 'Tudo certo. Lemos passos, frequência cardíaca e sono direto '
                    'do seu dispositivo. Você controla o acesso e pode revogá-lo '
                    'a qualquer momento.'
                : 'Com a sua permissão, lemos passos, frequência cardíaca e sono '
                    'do seu aparelho (Health Connect / HealthKit). Nada sai sem o '
                    'seu opt-in.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Layered device glyph: a soft tinted disc holding a watch with a small,
/// overlapping sync/heart accent — a proper illustrative header.
class _DeviceGlyph extends StatelessWidget {
  const _DeviceGlyph({required this.accent, required this.connected});

  final Color accent;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: connected ? 'Dispositivo conectado' : 'Dispositivo não conectado',
      child: SizedBox(
        width: 112,
        height: 96,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.watch_outlined, size: 46, color: accent),
            ),
            Positioned(
              right: 0,
              bottom: 4,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Icon(
                  connected ? Icons.check_rounded : Icons.bluetooth,
                  size: 20,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Conectado" pill shown in the hero once vitals have synced.
class _ConnectedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.careGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle,
              size: 20, color: AppColors.careGreen),
          const SizedBox(width: AppDimensions.xs),
          Text(
            'Conectado e sincronizado',
            style: text.titleMedium?.copyWith(color: AppColors.careGreen),
          ),
        ],
      ),
    );
  }
}

/// Synced vitals rendered as health-grade metric tiles in a responsive Wrap.
class _VitalsSection extends StatelessWidget {
  const _VitalsSection({required this.vitals});

  final Vitals vitals;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppDimensions.xs),
          child: Text('Leituras de hoje', style: text.titleMedium),
        ),
        const SizedBox(height: AppDimensions.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            // Two tiles per row when there's room, else full width.
            const gap = AppDimensions.md;
            final twoUp = constraints.maxWidth >= 360;
            final tileWidth =
                twoUp ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: tileWidth,
                  child: _MetricTile(
                    icon: Icons.directions_walk,
                    label: 'Passos',
                    value: vitals.steps?.toString() ?? '—',
                    unit: 'hoje',
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _MetricTile(
                    icon: Icons.favorite,
                    label: 'Freq. cardíaca',
                    value: vitals.restingHeartRate?.toStringAsFixed(0) ?? '—',
                    unit: 'bpm em repouso',
                    color: AppColors.careGreen,
                  ),
                ),
                SizedBox(
                  width: tileWidth,
                  child: _MetricTile(
                    icon: Icons.bedtime,
                    label: 'Sono',
                    value: vitals.sleepHours?.toStringAsFixed(1) ?? '—',
                    unit: 'horas',
                    color: AppColors.primaryLight,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A bold, health-grade metric tile: a ringed icon, the value as the hero,
/// the unit beneath and the label on top. Flat card, hairline border, calm.
class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$label: $value $unit',
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(width: AppDimensions.sm),
                Expanded(
                  child: Text(
                    label,
                    style: text.labelLarge
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              value,
              style: text.displaySmall?.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              unit,
              style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stable bottom area: the trust note never collides with this; the CTA is
/// always anchored here regardless of content length.
class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({required this.isLoading, required this.isReady});

  final bool isLoading;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.borderColor)),
      ),
      child: FilledButton.icon(
        // Minimum (not fixed) height: meets the 48dp target yet can grow with
        // text scaling so the label never clips.
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppDimensions.minTouchTarget),
        ),
        onPressed: isLoading
            ? null
            : () => context
                .read<WearableBloc>()
                .add(const ConnectWearableEvent()),
        icon: isLoading
            ? const SizedBox(
                height: AppDimensions.md,
                width: AppDimensions.md,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(isReady ? Icons.sync : Icons.bluetooth_connected),
        label: Text(
          isLoading
              ? 'Sincronizando…'
              : (isReady
                  ? 'Sincronizar novamente'
                  : 'Conectar e sincronizar'),
        ),
      ),
    );
  }
}

/// Trust note rendered as a real, bordered note — not a stray caption.
class _WellbeingDisclaimer extends StatelessWidget {
  const _WellbeingDisclaimer();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bem-estar, não diagnóstico',
                  style: text.labelLarge
                      ?.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppDimensions.xs),
                Text(
                  'Estes sinais ajudam a acompanhar o dia a dia. Não substituem '
                  'avaliação médica.',
                  style: text.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
