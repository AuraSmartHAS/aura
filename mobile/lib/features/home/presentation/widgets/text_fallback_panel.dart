import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';

/// Frase pronta do caminho não-vocal: um toque vira uma mensagem.
class QuickIntent {
  const QuickIntent({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// As três intenções que resolvem o dia da Maria sem falar e sem escrever.
/// O ícone não é enfeite: com 29% de analfabetismo funcional no país, é ele
/// (mais o anúncio em voz ao receber foco) que torna o chip usável.
const List<QuickIntent> kQuickIntents = [
  QuickIntent(label: 'Tomei o remédio', icon: Icons.medication_outlined),
  QuickIntent(label: 'Estou com dor', icon: Icons.healing_outlined),
  QuickIntent(label: 'Quero falar com a Ana', icon: Icons.phone_in_talk_outlined),
];

/// Caminho não-vocal completo (correção C4): frases prontas, campo de texto e
/// "Ouvir de novo". Tudo escreve na *mesma* sessão de conversa — não é uma tela
/// separada, é a mesma conversa por outro caminho de entrada.
class TextFallbackPanel extends StatefulWidget {
  const TextFallbackPanel({
    super.key,
    required this.onSend,
    required this.onRepeat,
    required this.onVoice,
    this.intentsHighlighted = false,
  });

  /// Recebe tanto o texto digitado quanto a frase de um chip.
  final ValueChanged<String> onSend;
  final VoidCallback onRepeat;
  final VoidCallback onVoice;
  final bool intentsHighlighted;

  @override
  State<TextFallbackPanel> createState() => _TextFallbackPanelState();
}

class _TextFallbackPanelState extends State<TextFallbackPanel> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntentChipsRow(
          onIntent: widget.onSend,
          highlighted: widget.intentsHighlighted,
        ),
        const SizedBox(height: AppDimensions.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ConstrainedBox(
                // Alvo confortável para mão que treme: bem acima dos 48dp.
                constraints: const BoxConstraints(
                  minHeight: AppDimensions.comfortableTouchTarget,
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _submit(),
                  // Corpo do paciente (>=18sp) — a escala do app, sem número
                  // mágico.
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Escreva aqui para a Aura',
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Semantics(
              button: true,
              label: 'Enviar mensagem para a Aura',
              child: SizedBox(
                width: AppDimensions.comfortableTouchTarget,
                height: AppDimensions.comfortableTouchTarget,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.square(
                      AppDimensions.comfortableTouchTarget,
                    ),
                  ),
                  child: const Icon(Icons.send, size: AppDimensions.lg),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        Row(
          children: [
            Expanded(
              child: _SecondaryAction(
                label: 'Ouvir de novo',
                icon: Icons.replay,
                onTap: widget.onRepeat,
              ),
            ),
            Expanded(
              child: _SecondaryAction(
                label: 'Prefiro falar',
                icon: Icons.mic_none,
                onTap: widget.onVoice,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Linha das frases prontas. Fica visível também no modo de voz quando a Aura
/// não entendeu — é assim que a pessoa é *levada* ao caminho não-vocal em vez
/// de precisar descobri-lo sozinha.
class IntentChipsRow extends StatelessWidget {
  const IntentChipsRow({
    super.key,
    required this.onIntent,
    this.highlighted = false,
  });

  final ValueChanged<String> onIntent;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.sm,
      children: [
        for (final intent in kQuickIntents)
          _IntentChip(
            intent: intent,
            highlighted: highlighted,
            onTap: () => onIntent(intent.label),
          ),
      ],
    );
  }
}

class _IntentChip extends StatelessWidget {
  const _IntentChip({
    required this.intent,
    required this.onTap,
    required this.highlighted,
  });

  final QuickIntent intent;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background =
        highlighted ? theme.colorScheme.primaryContainer : AppColors.surface;
    final border = highlighted ? AppColors.primary : AppColors.borderColor;

    return Semantics(
      button: true,
      label: intent.label,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          // O chip se anuncia ao receber foco. Sem TTS próprio no app, o leitor
          // de tela é o canal de áudio disponível para quem não lê o rótulo.
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              SemanticsService.sendAnnouncement(
                View.of(context),
                intent.label,
                Directionality.of(context),
              );
            }
          },
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppDimensions.comfortableTouchTarget,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.md,
              vertical: AppDimensions.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: border, width: highlighted ? 2 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  intent.icon,
                  size: AppDimensions.lg,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppDimensions.sm),
                Text(
                  intent.label,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: AppDimensions.lg),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppDimensions.comfortableTouchTarget),
        ),
      ),
    );
  }
}
