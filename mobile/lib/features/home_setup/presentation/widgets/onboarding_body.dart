import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/home.dart';
import '../bloc/home_setup_bloc.dart';

class OnboardingBody extends StatelessWidget {
  const OnboardingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar a casa')),
      body: SafeArea(
        child: BlocBuilder<HomeSetupBloc, HomeSetupState>(
          builder: (context, state) {
            return switch (state.step) {
              SetupStep.form => const _HomeForm(),
              _ => const _ChecklistForm(),
            };
          },
        ),
      ),
    );
  }
}

class _HomeForm extends StatefulWidget {
  const _HomeForm();

  @override
  State<_HomeForm> createState() => _HomeFormState();
}

class _HomeFormState extends State<_HomeForm> {
  final _patientName = TextEditingController();
  final _cep = TextEditingController();
  final _label = TextEditingController();

  @override
  void dispose() {
    _patientName.dispose();
    _cep.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sobre quem você cuida', style: text.headlineMedium),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Usamos o CEP para localizar a casa no mapa e rotear as entregas.',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.lg),
          TextField(
            controller: _patientName,
            decoration: const InputDecoration(labelText: 'Nome do paciente'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppDimensions.md),
          TextField(
            controller: _cep,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'CEP'),
          ),
          const SizedBox(height: AppDimensions.md),
          TextField(
            controller: _label,
            decoration: const InputDecoration(
              labelText: 'Apelido da casa (opcional)',
            ),
          ),
          const SizedBox(height: AppDimensions.lg),
          BlocBuilder<HomeSetupBloc, HomeSetupState>(
            builder: (context, state) {
              return Column(
                children: [
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppDimensions.md),
                      child: Text(
                        state.errorMessage!,
                        style: text.bodySmall?.copyWith(color: AppColors.error),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: AppDimensions.minTouchTarget,
                    child: FilledButton(
                      onPressed: state.isLoading
                          ? null
                          : () => _submit(context),
                      child: state.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continuar'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _submit(BuildContext context) {
    if (_patientName.text.trim().isEmpty || _cep.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe nome e CEP.')),
      );
      return;
    }
    context.read<HomeSetupBloc>().add(
          SubmitHomeFormEvent(
            patientName: _patientName.text.trim(),
            cep: _cep.text.replaceAll(RegExp(r'\D'), ''),
            label: _label.text.trim().isEmpty ? null : _label.text.trim(),
          ),
        );
  }
}

class _ChecklistForm extends StatelessWidget {
  const _ChecklistForm();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return BlocBuilder<HomeSetupBloc, HomeSetupState>(
      builder: (context, state) {
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.lg),
                children: [
                  Text('Checklist de segurança', style: text.headlineMedium),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'Marque o que existe na casa. Itens de segurança ausentes '
                    'aumentam o risco e orientam as recomendações.',
                    style: text.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppDimensions.md),
                  for (final key in SafetyChecklistKeys.all)
                    SwitchListTile(
                      title: Text(SafetyChecklistKeys.label(key)),
                      value: state.checklist[key] ?? false,
                      onChanged: (v) => context
                          .read<HomeSetupBloc>()
                          .add(ToggleChecklistItemEvent(key, v)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: SizedBox(
                width: double.infinity,
                height: AppDimensions.minTouchTarget,
                child: FilledButton(
                  onPressed: state.isLoading
                      ? null
                      : () => context
                          .read<HomeSetupBloc>()
                          .add(const SubmitChecklistEvent()),
                  child: state.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Concluir cadastro'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
