import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// A calm "Passo X de 2" progress indicator shared by both onboarding steps.
/// Color-only progress is avoided: the textual count carries the meaning and
/// the segments only reinforce it.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.current});

  /// 1-based current step (1 = form, 2 = checklist).
  final int current;

  static const _total = 2;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: 'Passo $current de $_total',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Passo $current de $_total',
            style: text.labelLarge?.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              for (var i = 1; i <= _total; i++) ...[
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= current
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                if (i < _total) const SizedBox(width: AppDimensions.sm),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Flat card on the warm background with a hairline border — the project's
/// signature surface. Used to group related fields/rows.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: child,
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

  // Inline (errorText) validation — surfaced under each field, not only via
  // a SnackBar — so the caregiver sees exactly which field needs attention.
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    // Live feedback so the CEP affordance (mask + length) updates as they type.
    _cep.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _patientName.dispose();
    _cep.dispose();
    _label.dispose();
    super.dispose();
  }

  String? get _nameError {
    if (!_showErrors) return null;
    return _patientName.text.trim().isEmpty
        ? 'Informe o nome do paciente.'
        : null;
  }

  String? get _cepError {
    if (!_showErrors) return null;
    final digits = _cep.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Informe o CEP.';
    if (digits.length != 8) return 'O CEP precisa ter 8 dígitos.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cepDigits = _cep.text.replaceAll(RegExp(r'\D'), '');
    final cepComplete = cepDigits.length == 8;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepProgress(current: 1),
          const SizedBox(height: AppDimensions.lg),
          // Warm welcome — first impression for the caregiver (Ana).
          Text('Bem-vindo à AURA', style: text.headlineMedium),
          const SizedBox(height: AppDimensions.sm),
          Text(
            'Vamos preparar o cuidado em casa, com calma. Primeiro, conte para '
            'quem você cuida e onde fica a casa.',
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppDimensions.lg),

          Text('Sobre quem você cuida', style: text.titleMedium),
          const SizedBox(height: AppDimensions.md),
          _Card(
            child: Column(
              children: [
                TextField(
                  controller: _patientName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Nome do paciente',
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: _nameError,
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                TextField(
                  controller: _cep,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_CepInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'CEP',
                    hintText: '00000-000',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    // Inline affordance: a check once the 8 digits are in.
                    suffixIcon: cepComplete
                        ? const Icon(Icons.check_circle_outline,
                            color: AppColors.success)
                        : null,
                    errorText: _cepError,
                    helperText:
                        'Usamos o CEP para localizar a casa no mapa e rotear '
                        'as entregas.',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                TextField(
                  controller: _label,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Apelido da casa (opcional)',
                    hintText: 'Ex.: Casa da mamãe',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                ),
              ],
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
                      child: _InlineError(message: state.errorMessage!),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: AppDimensions.minTouchTarget,
                    child: FilledButton(
                      onPressed:
                          state.isLoading ? null : () => _submit(context),
                      child: state.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
    setState(() => _showErrors = true);
    if (_nameError != null || _cepError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revise os campos destacados.')),
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

/// Formats CEP input as the caregiver types: 8 digits → `00000-000`.
class _CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 8 ? digits.substring(0, 8) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i == 5) buffer.write('-');
      buffer.write(capped[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 20, color: AppColors.error),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              message,
              style: text.bodyMedium?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

/// A grouped section of the safety checklist (one room/category) rendered as a
/// flat card of iconographic rows.
class _ChecklistGroup {
  const _ChecklistGroup({
    required this.title,
    required this.icon,
    required this.keys,
  });

  final String title;
  final IconData icon;
  final List<String> keys;
}

class _ChecklistForm extends StatelessWidget {
  const _ChecklistForm();

  // Group the canonical keys by where they live in the home, so the
  // risk-driving items read as meaningful, not a flat list of toggles.
  static const _groups = <_ChecklistGroup>[
    _ChecklistGroup(
      title: 'Banheiro e circulação',
      icon: Icons.bathtub_outlined,
      keys: [
        SafetyChecklistKeys.grabBarBathroom,
        SafetyChecklistKeys.slipperyFloor,
        SafetyChecklistKeys.nightLight,
      ],
    ),
    _ChecklistGroup(
      title: 'Ar e gases',
      icon: Icons.air,
      keys: [
        SafetyChecklistKeys.gasDetector,
        SafetyChecklistKeys.airPurifier,
      ],
    ),
  ];

  static IconData _iconFor(String key) {
    switch (key) {
      case SafetyChecklistKeys.grabBarBathroom:
        return Icons.accessible_outlined;
      case SafetyChecklistKeys.slipperyFloor:
        return Icons.water_drop_outlined;
      case SafetyChecklistKeys.nightLight:
        return Icons.nightlight_outlined;
      case SafetyChecklistKeys.gasDetector:
        return Icons.sensors_outlined;
      case SafetyChecklistKeys.airPurifier:
        return Icons.air_outlined;
      default:
        return Icons.check_circle_outline;
    }
  }

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
                  const _StepProgress(current: 2),
                  const SizedBox(height: AppDimensions.lg),
                  Text('Checklist de segurança', style: text.headlineMedium),
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    'Marque o que existe na casa. Itens de segurança ausentes '
                    'aumentam o risco e orientam as recomendações.',
                    style: text.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  for (final group in _groups) ...[
                    Row(
                      children: [
                        Icon(group.icon,
                            size: 20, color: AppColors.textSecondary),
                        const SizedBox(width: AppDimensions.sm),
                        Text(group.title, style: text.titleMedium),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.md),
                    _Card(
                      child: Column(
                        children: [
                          for (var i = 0; i < group.keys.length; i++) ...[
                            if (i > 0)
                              const Divider(
                                height: AppDimensions.lg,
                                color: AppColors.borderColor,
                              ),
                            _ChecklistRow(
                              itemKey: group.keys[i],
                              icon: _iconFor(group.keys[i]),
                              value: state.checklist[group.keys[i]] ?? false,
                              onChanged: (v) => context
                                  .read<HomeSetupBloc>()
                                  .add(ToggleChecklistItemEvent(
                                      group.keys[i], v)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.lg),
                  ],
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

/// A single safety item: icon + label + a short, honest status line + Switch.
/// `slippery_floor` is inverted (true = hazard present), so the helper copy and
/// status are honest about whether the toggle marks something safe or risky.
class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.itemKey,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String itemKey;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = SafetyChecklistKeys.label(itemKey);
    // Whether the *current* value is the safe condition for this item.
    final isSafe = value == SafetyChecklistKeys.trueIsSafe(itemKey);
    final statusColor = isSafe ? AppColors.success : AppColors.warning;
    final statusIcon =
        isSafe ? Icons.check_circle_outline : Icons.warning_amber_outlined;
    final statusLabel = isSafe ? 'Tudo certo' : 'Ponto de atenção';

    // MergeSemantics so the row + Switch announce as a single toggle
    // ("<label>, <status>, ligado/desligado") instead of nested controls.
    return MergeSemantics(
      child: Semantics(
        label: '$label. $statusLabel',
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(minHeight: AppDimensions.minTouchTarget),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: AppColors.primary),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: text.titleSmall),
                    const SizedBox(height: AppDimensions.xs),
                    // Severity is never color-only: icon + text + color together.
                    Row(
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: AppDimensions.xs),
                        Flexible(
                          child: Text(
                            statusLabel,
                            style:
                                text.labelMedium?.copyWith(color: statusColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
