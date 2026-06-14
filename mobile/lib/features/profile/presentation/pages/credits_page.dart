import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
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
      appBar: AppBar(
        title: const Text('Sobre'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AURA Care-Chain', style: text.headlineSmall),
                const SizedBox(height: AppDimensions.md),
                Text(
                  'Adaptação Preditiva como Serviço: o AURA capta sinais de '
                  'risco do idoso e aciona a cadeia de cuidado (recomendação → '
                  'pedido → entrega → instalação) antes do acidente.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: AppDimensions.xl),
                Text('Tecnologias', style: text.headlineSmall),
                const SizedBox(height: AppDimensions.md),
                const _TechItem(
                  title: 'Flutter',
                  description: 'Desenvolvimento multiplataforma',
                ),
                const _TechItem(
                  title: 'aura-server',
                  description: 'API REST com escore explicável e cadeia logística',
                ),
                const _TechItem(
                  title: 'ElevenLabs',
                  description: 'Agente de voz para a interface do paciente',
                ),
                const SizedBox(height: AppDimensions.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () {
                      // Logout clears the session; the router guard then
                      // redirects to /login automatically.
                      context.read<AuthBloc>().add(const LogoutEvent());
                    },
                    child: const Text('Sair'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TechItem extends StatelessWidget {
  const _TechItem({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.labelLarge),
          const SizedBox(height: AppDimensions.xs),
          Text(description, style: text.bodySmall),
        ],
      ),
    );
  }
}
