import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class CreditsPage extends StatelessWidget {
  const CreditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthBloc>(),
      child: const _CreditsView(),
    );
  }
}

class _CreditsView extends StatelessWidget {
  const _CreditsView();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sobre'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Branded header ──────────────────────────────────
              const _BrandHeader(),
              const SizedBox(height: AppDimensions.lg),

              // ── Trust principles (color + icon + text) ──────────
              Text('Nossos princípios', style: text.headlineSmall),
              const SizedBox(height: AppDimensions.md),
              const Wrap(
                spacing: AppDimensions.sm,
                runSpacing: AppDimensions.sm,
                children: [
                  _TrustChip(icon: Icons.visibility_outlined, label: 'explicável'),
                  _TrustChip(
                    icon: Icons.medical_information_outlined,
                    label: 'nunca prescreve',
                  ),
                  _TrustChip(
                    icon: Icons.accessibility_new_outlined,
                    label: 'acessível',
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.xl),

              // ── Team credits ────────────────────────────────────
              Text('Quem construiu', style: text.headlineSmall),
              const SizedBox(height: AppDimensions.md),
              const _CreditCard(
                children: [
                  _CreditRow(
                    role: 'Projeto',
                    name: 'AURA Care-Chain',
                  ),
                  _CreditRow(
                    role: 'Instituição',
                    name: 'FIAP · Pós-Tech — Fase 4, 2026',
                  ),
                  _CreditRow(
                    role: 'Proposta',
                    name: 'Adaptação Preditiva como Serviço',
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.xl),

              // ── Technologies ────────────────────────────────────
              Text('Tecnologias', style: text.headlineSmall),
              const SizedBox(height: AppDimensions.md),
              const _CreditCard(
                children: [
                  _CreditRow(
                    role: 'Flutter',
                    name: 'Aplicativo multiplataforma',
                  ),
                  _CreditRow(
                    role: 'aura-server',
                    name: 'API REST com escore explicável e cadeia logística',
                  ),
                  _CreditRow(
                    role: 'ElevenLabs',
                    name: 'Agente de voz da interface do paciente',
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.xl),

              // ── Sign out ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize:
                        const Size.fromHeight(AppDimensions.minTouchTarget),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.md,
                    ),
                  ),
                  icon: const Icon(Icons.logout),
                  label: Text('Sair da conta', style: text.labelLarge),
                  onPressed: () => _confirmLogout(context),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                'Você poderá entrar novamente quando quiser.',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    // Capture the bloc before the async gap so we don't touch a stale context.
    final authBloc = context.read<AuthBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final text = Theme.of(dialogContext).textTheme;
        return AlertDialog(
          title: Text('Sair da conta?', style: text.headlineSmall),
          content: Text(
            'Sua sessão será encerrada neste aparelho.',
            style: text.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      // Logout clears the session; the router guard then redirects to
      // /login automatically.
      authBloc.add(const LogoutEvent());
    }
  }
}

/// Clean branded header: AURA wordmark over a calm petrol-tinted block.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      header: true,
      label: 'AURA Care-Chain, FIAP 2026',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Focal element: the AURA wordmark.
            Text(
              'AURA',
              style: text.displayMedium?.copyWith(
                color: AppColors.primary,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: AppDimensions.xs),
            Text(
              'AURA Care-Chain · FIAP 2026',
              style: text.labelMedium?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            Text(
              'Captamos sinais de risco do dia a dia e acionamos a cadeia de '
              'cuidado — recomendação, pedido, entrega e instalação — antes do '
              'acidente acontecer.',
              style: text.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small trust chip — pairs an icon with the principle text (never color-only).
class _TrustChip extends StatelessWidget {
  const _TrustChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: 'Princípio: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md,
          vertical: AppDimensions.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.careGreen),
            const SizedBox(width: AppDimensions.sm),
            Text(
              label,
              style: text.labelMedium?.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flat card on warm background with a hairline border.
class _CreditCard extends StatelessWidget {
  const _CreditCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(children: children),
    );
  }
}

/// One credit line: a quiet role label above a clear name/description.
class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.role, required this.name});

  final String role;
  final String name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            role.toUpperCase(),
            style: text.bodySmall?.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(name, style: text.bodyLarge),
        ],
      ),
    );
  }
}
