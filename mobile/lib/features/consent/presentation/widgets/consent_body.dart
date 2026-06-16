import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../bloc/consent_bloc.dart';

/// LGPD consent gate (RN-001) — the door before any health data.
///
/// Restyled as scannable, iconographic trust cards: what data is used, why,
/// that this is "bem-estar, não diagnóstico", and that consent can be revoked
/// at any time. The promises are the focal element; everything else stays calm
/// (flat cards on warm bg, hairline borders, generous spacing) so this reads as
/// the credibility moment it is — for families and for the Leroy Merlin pitch.
class ConsentBody extends StatelessWidget {
  const ConsentBody({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade e consentimento')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.lg,
                  AppDimensions.lg,
                  AppDimensions.lg,
                  AppDimensions.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero: the promise ─────────────────────────────
                    Semantics(
                      header: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: AppDimensions.xxl,
                            height: AppDimensions.xxl,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.borderColor),
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.md),
                          Text(
                            'Sua privacidade vem primeiro',
                            style: text.headlineMedium,
                          ),
                          const SizedBox(height: AppDimensions.sm),
                          Text(
                            'O AURA cuida do bem-estar de quem você ama. Antes de '
                            'começar, queremos ser claros sobre o que usamos, por '
                            'que usamos e o seu controle total sobre isso.',
                            style: text.bodyLarge
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.lg),

                    // ── Trust cards ───────────────────────────────────
                    const _TrustCard(
                      icon: Icons.favorite_outline,
                      title: 'Quais dados usamos',
                      body:
                          'Relatos de voz, sinais de risco no dia a dia (como '
                          'quase-quedas) e — só se você quiser — dados de '
                          'wearable, como passos e frequência cardíaca.',
                    ),
                    const SizedBox(height: AppDimensions.md),
                    const _TrustCard(
                      icon: Icons.security_outlined,
                      title: 'Por que usamos',
                      body:
                          'Com um único objetivo: prevenir acidentes e acionar a '
                          'cadeia de cuidado antes que algo aconteça.',
                    ),
                    const SizedBox(height: AppDimensions.md),
                    const _TrustCard(
                      icon: Icons.spa_outlined,
                      title: 'Bem-estar, não diagnóstico',
                      body:
                          'Nada aqui é diagnóstico médico. Toda recomendação é '
                          'encaminhada à pessoa cuidadora e, quando crítico, ao '
                          'profissional de saúde.',
                      highlight: true,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    const _TrustCard(
                      icon: Icons.lock_open_outlined,
                      title: 'Você está no controle',
                      body:
                          'Seus dados são protegidos conforme a LGPD. Você pode '
                          'revogar o consentimento e pedir a exclusão dos dados a '
                          'qualquer momento.',
                    ),
                  ],
                ),
              ),
            ),

            // ── Sticky accept action ──────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(
                  top: BorderSide(color: AppColors.borderColor),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.lg,
                AppDimensions.md,
                AppDimensions.lg,
                AppDimensions.md,
              ),
              child: BlocBuilder<ConsentBloc, ConsentState>(
                builder: (context, state) {
                  final isLoading = state is ConsentLoading;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: AppDimensions.minTouchTarget,
                        child: FilledButton.icon(
                          onPressed: isLoading
                              ? null
                              : () => context
                                  .read<ConsentBloc>()
                                  .add(const AcceptConsentEvent()),
                          icon: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: Text(isLoading ? 'Confirmando…' : 'Aceito'),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        'Ao tocar em “Aceito”, você confirma que leu e concorda '
                        'com a coleta descrita acima.',
                        textAlign: TextAlign.center,
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.textTertiary),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single iconographic trust promise — a flat card on the warm background.
/// The "Bem-estar, não diagnóstico" card is gently highlighted (care-green)
/// because it is the heart of the product's honesty.
class _TrustCard extends StatelessWidget {
  const _TrustCard({
    required this.icon,
    required this.title,
    required this.body,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = highlight ? AppColors.careGreen : AppColors.primary;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$title. $body',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: highlight ? AppColors.surfaceVariant : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(
            color: highlight ? AppColors.careGreen : AppColors.borderColor,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  const SizedBox(height: AppDimensions.xs),
                  Text(
                    body,
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
