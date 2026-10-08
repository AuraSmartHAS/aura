import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/platform/phone_dialer.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../features/home_setup/domain/usecases/get_home_usecase.dart';
import '../../domain/usecases/care_feed_usecases.dart';
import '../bloc/emergency_alert_cubit.dart';

/// Abre o mapa do aparelho no destino. Injetável para o teste não sair do app.
typedef ExternalUrlOpener = Future<bool> Function(Uri uri);

Future<bool> _openExternal(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// "Pedido de ajuda": a tela que o toque no aviso de SOS abre no celular de
/// quem cuida. Uma decisão só em destaque — "Estou indo" — e os dois caminhos
/// que vêm logo depois: chegar lá (mapa) e chamar socorro (discador).
class EmergencyAlertPage extends StatelessWidget {
  const EmergencyAlertPage({
    super.key,
    required this.emergencyId,
    this.homeId,
    this.address,
    this.lat,
    this.lng,
    this.cubit,
    this.phoneDialer,
    this.openExternal,
    this.emergencyPhone,
  });

  final String emergencyId;
  final String? homeId;
  final String? address;
  final double? lat;
  final double? lng;

  /// Visíveis para teste.
  final EmergencyAlertCubit? cubit;
  final PhoneDialer? phoneDialer;
  final ExternalUrlOpener? openExternal;
  final String? emergencyPhone;

  @override
  Widget build(BuildContext context) {
    // A chave é o id: o router reaproveita a página quando só o id muda (um
    // segundo SOS tocado com esta tela aberta), e sem ela o cubit do pedido
    // anterior continuaria na tela, dizendo "Ana avisou que está indo" para um
    // pedido que ninguém confirmou.
    return BlocProvider<EmergencyAlertCubit>(
      key: ValueKey(emergencyId),
      create: (_) => (cubit ??
          EmergencyAlertCubit(
            emergencyId: emergencyId,
            homeId: homeId,
            address: address,
            lat: lat,
            lng: lng,
            getEmergency: sl<GetEmergencyOutcomeUseCase>(),
            acknowledge: sl<AcknowledgeEmergencyUseCase>(),
            getHome: sl<GetHomeUseCase>(),
          ))
        ..start(),
      child: _EmergencyAlertView(
        phoneDialer: phoneDialer ?? sl<PhoneDialer>(),
        openExternal: openExternal ?? _openExternal,
        emergencyPhone: emergencyPhone ?? AppConfig.sosEmergencyPhone,
      ),
    );
  }
}

class _EmergencyAlertView extends StatelessWidget {
  const _EmergencyAlertView({
    required this.phoneDialer,
    required this.openExternal,
    required this.emergencyPhone,
  });

  final PhoneDialer phoneDialer;
  final ExternalUrlOpener openExternal;
  final String emergencyPhone;

  static String _firstName(String? name) {
    final first = (name ?? '').trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? 'Alguém da casa' : first;
  }

  Uri? _mapUri(EmergencyAlertState s) {
    final String query;
    if (s.lat != null && s.lng != null) {
      query = '${s.lat},${s.lng}';
    } else if (s.address != null) {
      query = s.address!;
    } else {
      return null;
    }
    return Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query});
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return BlocBuilder<EmergencyAlertCubit, EmergencyAlertState>(
      builder: (context, s) {
        final emergency = s.emergency;
        final quem = _firstName(s.patientName);
        final state = emergency?.state;
        final open = emergency?.isOpen ?? true;
        final acknowledged = state == 'acknowledged';
        final color = open
            ? AppColors.error
            : acknowledged
                ? AppColors.confirm
                : AppColors.textSecondary;

        final title = switch (state) {
          'acknowledged' => '$quem pediu ajuda · alguém está indo',
          'cancelled' => '$quem cancelou o pedido de ajuda',
          'closed' => 'Pedido de ajuda encerrado',
          _ => '$quem pediu ajuda',
        };
        final detail = switch (state) {
          null when s.loadFailed =>
            'Não consegui ver o estado do pedido agora. Mesmo assim, você pode ir até lá.',
          null => 'Carregando o pedido…',
          'waiting_cancel' => '$quem ainda pode cancelar nos próximos segundos.',
          'dispatched' => 'Ninguém confirmou ainda. Se você vai, avise.',
          'escalated' =>
            'Ninguém respondeu a tempo e o aviso foi para os outros contatos.',
          'acknowledged' => emergency?.acknowledgedByName == null
              ? 'Você avisou que está indo.'
              : '${emergency!.acknowledgedByName} avisou que está indo.',
          'cancelled' => 'Foi engano. Nada precisa ser feito.',
          _ => 'O pedido deixou de estar em aberto.',
        };
        final mapUri = _mapUri(s);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Pedido de ajuda'),
            leading: IconButton(
              tooltip: 'Voltar ao painel',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.dashboard),
            ),
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => context.read<EmergencyAlertCubit>().refresh(),
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.lg),
                children: [
                  Semantics(
                    container: true,
                    liveRegion: true,
                    label: '$title. $detail',
                    child: ExcludeSemantics(
                      child: Container(
                        padding: const EdgeInsets.all(AppDimensions.lg),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusLg),
                          border: Border.all(color: color, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: text.headlineSmall?.copyWith(
                                    color: color, fontWeight: FontWeight.w700)),
                            const SizedBox(height: AppDimensions.sm),
                            Text(detail, style: text.bodyLarge),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  if (s.homeLabel != null)
                    Text(s.homeLabel!, style: text.titleLarge),
                  if (s.address != null) ...[
                    const SizedBox(height: AppDimensions.xs),
                    Text(s.address!, style: text.bodyLarge),
                  ],
                  const SizedBox(height: AppDimensions.xl),
                  if (open) ...[
                    SizedBox(
                      height: AppDimensions.comfortableTouchTarget,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.confirm),
                        onPressed: s.canAcknowledge
                            ? () => context.read<EmergencyAlertCubit>().acknowledge()
                            : null,
                        icon: s.acknowledging
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.directions_run),
                        label: const Text('Estou indo'),
                      ),
                    ),
                    if (s.acknowledgeFailed) ...[
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        'Não consegui confirmar agora. Tente de novo ou ligue.',
                        style: text.bodyMedium?.copyWith(color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.md),
                  ],
                  if (mapUri != null)
                    SizedBox(
                      height: AppDimensions.minTouchTarget,
                      child: OutlinedButton.icon(
                        onPressed: () => openExternal(mapUri),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Abrir no mapa'),
                      ),
                    ),
                  const SizedBox(height: AppDimensions.md),
                  SizedBox(
                    height: AppDimensions.minTouchTarget,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          phoneDialer.openDialer(emergencyPhone),
                      icon: const Icon(Icons.call),
                      label: Text('Ligar $emergencyPhone'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
