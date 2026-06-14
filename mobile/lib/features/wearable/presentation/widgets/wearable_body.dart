import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/vitals.dart';
import '../bloc/wearable_bloc.dart';

class WearableBody extends StatelessWidget {
  const WearableBody({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Wearable')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: BlocBuilder<WearableBloc, WearableState>(
            builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.watch_outlined,
                      size: 48, color: AppColors.primary),
                  const SizedBox(height: AppDimensions.md),
                  Text('Conectar wearable', style: text.headlineMedium),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'Com sua permissão, lemos passos, frequência cardíaca e '
                    'sono do seu dispositivo (Health Connect / HealthKit). '
                    'Nada sai sem o seu opt-in.',
                    style: text.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  if (state.status == WearableStatus.ready)
                    _VitalsCard(vitals: state.vitals!),
                  if (state.status == WearableStatus.error)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimensions.md),
                      child: Text(
                        state.errorMessage ?? 'Erro ao sincronizar.',
                        style: text.bodyMedium?.copyWith(color: AppColors.error),
                      ),
                    ),
                  const Spacer(),
                  const _WellbeingDisclaimer(),
                  const SizedBox(height: AppDimensions.sm),
                  SizedBox(
                    height: AppDimensions.minTouchTarget,
                    child: FilledButton.icon(
                      onPressed: state.status == WearableStatus.loading
                          ? null
                          : () => context
                              .read<WearableBloc>()
                              .add(const ConnectWearableEvent()),
                      icon: state.status == WearableStatus.loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(
                        state.status == WearableStatus.ready
                            ? 'Sincronizar novamente'
                            : 'Conectar e sincronizar',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VitalsCard extends StatelessWidget {
  const _VitalsCard({required this.vitals});

  final Vitals vitals;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          children: [
            _row(context, Icons.directions_walk, 'Passos hoje',
                vitals.steps?.toString() ?? '—'),
            _row(context, Icons.favorite_outline, 'FC (bpm)',
                vitals.restingHeartRate?.toStringAsFixed(0) ?? '—'),
            _row(context, Icons.bedtime_outlined, 'Sono (h)',
                vitals.sleepHours?.toStringAsFixed(1) ?? '—'),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.xs),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppDimensions.sm),
          Text(label, style: text.bodyMedium),
          const Spacer(),
          Text(value, style: text.titleMedium),
        ],
      ),
    );
  }
}

class _WellbeingDisclaimer extends StatelessWidget {
  const _WellbeingDisclaimer();

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
