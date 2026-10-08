import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../shared/utils/care_time.dart';
import '../../domain/entities/care_signal.dart';
import '../../domain/entities/care_today.dart';
import '../bloc/dashboard_bloc.dart';

/// Faixa de SOS: o que a família não pode deixar de ver, e a única ação
/// ("Estou indo") que fecha o ciclo aberto pelo agente de voz ou pelo botão.
class SosAlertCard extends StatelessWidget {
  const SosAlertCard({
    super.key,
    required this.emergency,
    required this.patientFirstName,
    required this.acknowledging,
    required this.acknowledgeFailed,
    this.now,
  });

  final ActiveEmergency emergency;
  final String patientFirstName;
  final bool acknowledging;
  final bool acknowledgeFailed;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final acknowledged = emergency.state == 'acknowledged';
    final open = emergency.isOpen;
    // Aberto: vermelho. Confirmado: verde. Encerrado (cancelou, ou ninguém sabe
    // como): neutro — não há mais o que fazer, mas o aviso não some calado.
    final color = open
        ? AppColors.error
        : acknowledged
            ? AppColors.confirm
            : AppColors.textSecondary;
    final since = careAgo(emergency.createdAt.toLocal(), now ?? DateTime.now());

    final detail = switch (emergency.state) {
      'waiting_cancel' =>
        '$patientFirstName ainda pode cancelar nos próximos segundos. '
            'O aviso sai logo em seguida.',
      'dispatched' => 'O aviso saiu e ninguém confirmou ainda.',
      'escalated' =>
        'Ninguém respondeu a tempo, e o aviso foi para os outros contatos.',
      'acknowledged' => emergency.acknowledgedByName == null
          ? 'Você avisou que está indo.'
          : '${emergency.acknowledgedByName} avisou que está indo.',
      'cancelled' => 'Foi engano. Nada precisa ser feito.',
      'closed' => 'O pedido deixou de estar em aberto.',
      _ => 'Confirme para quem está cuidando que você viu.',
    };
    final title = switch (emergency.state) {
      'acknowledged' => '$patientFirstName pediu ajuda · alguém está indo',
      'cancelled' => '$patientFirstName cancelou o pedido de ajuda',
      'closed' => 'Pedido de ajuda de $patientFirstName encerrado',
      _ => '$patientFirstName pediu ajuda',
    };

    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title. $detail'
          '${acknowledgeFailed ? '. Não consegui confirmar agora.' : ''}',
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // O rótulo do contêiner já lê este bloco: sem excluí-lo o leitor de
            // tela anunciaria tudo duas vezes. O botão fica de fora, alcançável.
            ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                          open
                              ? Icons.sos_rounded
                              : acknowledged
                                  ? Icons.check_circle
                                  : Icons.info_outline,
                          color: color),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(child: Text(title, style: text.titleLarge)),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.xs),
                  Text('Pedido $since',
                      style: text.labelMedium
                          ?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: AppDimensions.sm),
                  Text(detail, style: text.bodyLarge),
                  if (acknowledgeFailed) ...[
                    const SizedBox(height: AppDimensions.sm),
                    Text(
                      'Não consegui confirmar agora. Tente de novo.',
                      style: text.bodyMedium?.copyWith(color: AppColors.error),
                    ),
                  ],
                ],
              ),
            ),
            if (open) ...[
              const SizedBox(height: AppDimensions.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(
                        AppDimensions.comfortableTouchTarget),
                  ),
                  onPressed: acknowledging
                      ? null
                      : () => context
                          .read<DashboardBloc>()
                          .add(AcknowledgeEmergencyEvent(emergency.id)),
                  icon: acknowledging
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.directions_run),
                  label: const Text('Estou indo'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Remédios de hoje": a resposta para "a Maria já tomou?".
class TodayMedicationsCard extends StatelessWidget {
  const TodayMedicationsCard({
    super.key,
    required this.items,
    required this.patientFirstName,
    this.available = true,
    this.now,
  });

  final List<MedicationToday> items;
  final String patientFirstName;

  /// Falso quando os remédios ou os sinais não carregaram: aí a lista vazia
  /// não quer dizer "nenhum remédio" — a tela diz que não conseguiu carregar.
  final bool available;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final clock = now ?? DateTime.now();
    final late = items
        .where((m) => m.status == DoseStatus.late || m.declinedToday)
        .length;

    if (!available) {
      return const _CardShell(
        title: 'Remédios de hoje',
        child: _LoadFailed('Não consegui carregar os remédios de hoje agora.'),
      );
    }

    final summary = items.isEmpty
        ? 'Nenhum remédio cadastrado ainda.'
        : late > 0
            ? '$late ${late == 1 ? 'pede' : 'pedem'} atenção'
            : 'Tudo em dia até agora';
    final summaryColor = late > 0 ? AppColors.warning : AppColors.confirm;

    return _CardShell(
      title: 'Remédios de hoje',
      trailing: items.isEmpty
          ? null
          : Text(summary,
              style: text.labelLarge?.copyWith(color: summaryColor)),
      onTap: () => context.push(AppRoutes.medications),
      semanticsHint: 'Abrir medicamentos',
      child: items.isEmpty
          ? Text(summary,
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary))
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: AppDimensions.lg),
                  _MedicationRow(item: items[i], now: clock),
                ],
              ],
            ),
    );
  }
}

class _MedicationRow extends StatelessWidget {
  const _MedicationRow({required this.item, required this.now});

  final MedicationToday item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final med = item.medication;

    final (IconData icon, Color color, String status) = switch (item.status) {
      DoseStatus.complete => (
          Icons.check_circle,
          AppColors.confirm,
          _takenLine(),
        ),
      DoseStatus.onTrack => (
          item.takenCount > 0 ? Icons.check_circle_outline : Icons.schedule,
          AppColors.confirm,
          item.takenCount > 0
              ? '${_takenLine()} · próxima ${item.nextTime}'
              : 'Próxima às ${item.nextTime}',
        ),
      DoseStatus.late => (
          Icons.error_outline,
          AppColors.warning,
          item.takenCount > 0
              ? 'Atrasada: era às ${item.nextTime} · ${_takenLine()}'
              : 'Atrasada: era às ${item.nextTime}',
        ),
      DoseStatus.asNeeded => (
          Icons.more_horiz,
          AppColors.textTertiary,
          'Quando necessário',
        ),
    };

    return Semantics(
      container: true,
      label: '${med.name}${med.dosage == null ? '' : ' ${med.dosage}'}. $status'
          '${item.declinedToday ? '. Disse que não tomou.' : ''}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med.dosage == null ? med.name : '${med.name} · ${med.dosage}',
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(status,
                      style: text.bodyMedium?.copyWith(color: color)),
                  if (item.declinedToday)
                    Text(
                      'Disse que não tomou',
                      style: text.bodyMedium
                          ?.copyWith(color: AppColors.error),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _takenLine() {
    final at = item.lastTakenAt;
    if (at == null) return 'Tomou';
    final src = item.lastSource;
    return 'Tomou às ${careClock(at, now).replaceFirst('ontem ', '')}'
        '${src == null ? '' : ' · ${src.label}'}';
  }
}

/// "O que aconteceu": o que a Maria disse e fez, do mais novo ao mais antigo.
class TimelineCard extends StatelessWidget {
  const TimelineCard({
    super.key,
    required this.items,
    required this.patientFirstName,
    this.available = true,
    this.now,
  });

  final List<CareActivity> items;
  final String patientFirstName;

  /// Falso quando os sinais não carregaram (ver [TodayMedicationsCard.available]).
  final bool available;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final clock = now ?? DateTime.now();

    if (!available) {
      return const _CardShell(
        title: 'O que aconteceu',
        child: _LoadFailed('Não consegui carregar o que aconteceu agora.'),
      );
    }

    return _CardShell(
      title: 'O que aconteceu',
      child: items.isEmpty
          ? Text(
              'Nada registrado ainda. Quando $patientFirstName conversar com a '
              'Aura, aparece aqui.',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppDimensions.md),
                  _TimelineRow(item: items[i], now: clock),
                ],
              ],
            ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.now});

  final CareActivity item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = item.kind == ActivityKind.sos
        ? AppColors.error
        : item.concerning
            ? AppColors.warning
            : AppColors.textTertiary;
    final icon = switch (item.kind) {
      ActivityKind.dose => Icons.medication_outlined,
      ActivityKind.symptom => Icons.record_voice_over_outlined,
      ActivityKind.sos => Icons.sos_rounded,
    };
    final when = careClock(item.occurredAt, now);

    return Semantics(
      container: true,
      label: '$when. ${item.title}, ${item.source.label}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              child: Text(when,
                  style: text.labelMedium
                      ?.copyWith(color: AppColors.textTertiary)),
            ),
            Icon(icon, size: 20, color: color),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: text.bodyLarge),
                  const SizedBox(height: 2),
                  Text(
                    item.source.label,
                    style: text.labelMedium
                        ?.copyWith(color: AppColors.textTertiary),
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

/// Casca comum dos cartões do "Hoje": superfície branca, borda quente, título.
class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.title,
    required this.child,
    this.trailing,
    this.onTap,
    this.semanticsHint,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    final content = Container(
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
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: text.titleMedium),
                ),
              ),
              if (trailing != null) trailing!,
              if (onTap != null)
                const Icon(Icons.chevron_right,
                    color: AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          child,
        ],
      ),
    );

    if (onTap == null) return content;
    return Semantics(
      button: true,
      hint: semanticsHint,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        child: content,
      ),
    );
  }
}

/// "Não consegui carregar": o oposto de uma lista vazia de verdade.
class _LoadFailed extends StatelessWidget {
  const _LoadFailed(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.cloud_off_outlined,
            size: 20, color: AppColors.warning),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.warning),
          ),
        ),
      ],
    );
  }
}

/// Aviso de que a tela pode não estar mostrando a verdade: não deu para
/// verificar se há SOS, ou o polling vem falhando e o que se vê está velho.
class ConnectionNotice extends StatelessWidget {
  const ConnectionNotice({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(color: AppColors.warning),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cloud_off_outlined,
                      color: AppColors.warning),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(child: Text(message, style: text.bodyMedium)),
                ],
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppDimensions.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                        AppDimensions.minTouchTarget,
                        AppDimensions.minTouchTarget),
                  ),
                  onPressed: onRetry,
                  child: const Text('Tentar de novo'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
