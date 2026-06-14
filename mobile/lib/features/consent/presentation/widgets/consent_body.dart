import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../bloc/consent_bloc.dart';

class ConsentBody extends StatelessWidget {
  const ConsentBody({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade e consentimento')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.privacy_tip_outlined,
                  size: 48, color: AppColors.primary),
              const SizedBox(height: AppDimensions.md),
              Text('Sua privacidade vem primeiro (LGPD)',
                  style: text.headlineMedium),
              const SizedBox(height: AppDimensions.md),
              const Expanded(child: _PolicyText()),
              const SizedBox(height: AppDimensions.md),
              BlocBuilder<ConsentBloc, ConsentState>(
                builder: (context, state) {
                  final isLoading = state is ConsentLoading;
                  return SizedBox(
                    width: double.infinity,
                    height: AppDimensions.minTouchTarget,
                    child: FilledButton(
                      onPressed: isLoading
                          ? null
                          : () => context
                              .read<ConsentBloc>()
                              .add(const AcceptConsentEvent()),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Li e aceito a Política'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyText extends StatelessWidget {
  const _PolicyText();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Text(
        'O AURA coleta dados de saúde e bem-estar do paciente (relatos de voz, '
        'sinais de risco como quase-quedas, e — se você optar — dados de '
        'wearable como passos e frequência cardíaca) com um único objetivo: '
        'prevenir acidentes e acionar a cadeia de cuidado antes que algo '
        'aconteça.\n\n'
        'Nada é diagnóstico médico. Toda recomendação é encaminhada à pessoa '
        'cuidadora e, quando crítico, ao profissional de saúde.\n\n'
        'Seus dados são protegidos conforme a LGPD. Você pode revogar o '
        'consentimento e solicitar a exclusão dos dados a qualquer momento. '
        'Ao continuar, você confirma que leu e concorda com a coleta descrita '
        'acima.',
        style: text.bodyLarge,
      ),
    );
  }
}
