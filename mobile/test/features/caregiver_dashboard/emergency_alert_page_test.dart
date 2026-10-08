import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/platform/phone_dialer.dart';
import 'package:aura/features/caregiver_dashboard/domain/entities/care_signal.dart';
import 'package:aura/features/caregiver_dashboard/domain/repositories/care_feed_repository.dart';
import 'package:aura/features/caregiver_dashboard/domain/usecases/care_feed_usecases.dart';
import 'package:aura/features/caregiver_dashboard/presentation/bloc/emergency_alert_cubit.dart';
import 'package:aura/features/caregiver_dashboard/presentation/pages/emergency_alert_page.dart';
import 'package:aura/features/home_setup/domain/entities/home.dart';
import 'package:aura/features/home_setup/domain/repositories/home_repository.dart';
import 'package:aura/features/home_setup/domain/usecases/get_home_usecase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFeed implements CareFeedRepository {
  ActiveEmergency status = ActiveEmergency(
      id: 'em-1', state: 'dispatched', createdAt: DateTime(2026, 10, 7, 3));
  Object? statusFailure;
  Object? ackFailure;
  final acknowledged = <String>[];

  @override
  Future<Result<ActiveEmergency>> getEmergencyOutcome(String id) async =>
      statusFailure != null ? Failure(statusFailure) : Success(status);

  @override
  Future<Result<ActiveEmergency>> acknowledge(String id) async {
    acknowledged.add(id);
    if (ackFailure != null) return Failure(ackFailure);
    status = ActiveEmergency(
        id: id,
        state: 'acknowledged',
        createdAt: DateTime(2026, 10, 7),
        acknowledgedByName: 'Ana');
    return Success(status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeHomes implements HomeRepository {
  bool fail = false;

  @override
  Future<Result<HomeDetail>> getHome(String homeId) async => fail
      ? const Failure(AppFailure.networkError(message: 'x'))
      : const Success(HomeDetail(
          home: Home(
              id: 'home-1',
              label: 'Casa da Maria',
              address: 'Av. Paulista, 1000',
              lat: -23.56,
              lng: -46.65),
          patientName: 'Maria S.',
          checklist: {},
        ));

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeDialer implements PhoneDialer {
  final dialed = <String>[];
  @override
  Future<bool> openDialer(String phoneNumber) async {
    dialed.add(phoneNumber);
    return true;
  }
}

void main() {
  late _FakeFeed feed;
  late _FakeHomes homes;
  late _FakeDialer dialer;
  late List<Uri> opened;

  setUp(() {
    feed = _FakeFeed();
    homes = _FakeHomes();
    dialer = _FakeDialer();
    opened = [];
  });

  Future<void> pump(WidgetTester tester, {String? homeId = 'home-1'}) async {
    final cubit = EmergencyAlertCubit(
      emergencyId: 'em-1',
      homeId: homeId,
      address: 'Endereço do aviso',
      lat: -23.0,
      lng: -46.0,
      getEmergency: GetEmergencyOutcomeUseCase(feed),
      acknowledge: AcknowledgeEmergencyUseCase(feed),
      getHome: GetHomeUseCase(homes),
      pollEvery: const Duration(hours: 1),
    );
    await tester.pumpWidget(MaterialApp(
      home: EmergencyAlertPage(
        emergencyId: 'em-1',
        cubit: cubit,
        phoneDialer: dialer,
        openExternal: (uri) async {
          opened.add(uri);
          return true;
        },
        emergencyPhone: '192',
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra casa, endereço e o "Estou indo" fecha o loop',
      (tester) async {
    await pump(tester);

    expect(find.text('Maria pediu ajuda'), findsOneWidget);
    expect(find.text('Casa da Maria'), findsOneWidget);
    expect(find.text('Av. Paulista, 1000'), findsOneWidget);

    await tester.tap(find.text('Estou indo'));
    await tester.pumpAndSettle();

    expect(feed.acknowledged, ['em-1']);
    expect(find.text('Ana avisou que está indo.'), findsOneWidget);
    expect(find.text('Estou indo'), findsNothing,
        reason: 'confirmado, o botão sai: não há o que confirmar duas vezes');
  });

  testWidgets('sem a casa (rede fora), vale o endereço que veio no aviso',
      (tester) async {
    homes.fail = true;
    await pump(tester);

    expect(find.text('Endereço do aviso'), findsOneWidget);
    await tester.tap(find.text('Abrir no mapa'));
    expect(opened.single.queryParameters['query'], '-23.0,-46.0');
  });

  testWidgets('mapa usa as coordenadas da casa e o discador oferece o 192',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Abrir no mapa'));
    expect(opened.single.host, 'www.google.com');
    expect(opened.single.queryParameters['query'], '-23.56,-46.65');

    await tester.tap(find.text('Ligar 192'));
    expect(dialer.dialed, ['192']);
  });

  testWidgets('pedido cancelado não oferece "Estou indo"', (tester) async {
    feed.status = ActiveEmergency(
        id: 'em-1', state: 'cancelled', createdAt: DateTime(2026, 10, 7));
    await pump(tester);

    expect(find.text('Maria cancelou o pedido de ajuda'), findsOneWidget);
    expect(find.text('Estou indo'), findsNothing);
  });

  testWidgets('falha ao confirmar avisa e mantém o botão', (tester) async {
    feed.ackFailure = const AppFailure.networkError(message: 'x');
    await pump(tester);

    await tester.tap(find.text('Estou indo'));
    await tester.pumpAndSettle();

    expect(find.text('Não consegui confirmar agora. Tente de novo ou ligue.'),
        findsOneWidget);
    expect(find.text('Estou indo'), findsOneWidget);
  });

  testWidgets('segundo SOS com a tela aberta troca o pedido, não reaproveita o anterior',
      (tester) async {
    final cubits = <String, EmergencyAlertCubit>{};
    EmergencyAlertCubit cubitFor(String id) => cubits.putIfAbsent(
        id,
        () => EmergencyAlertCubit(
              emergencyId: id,
              homeId: null,
              getEmergency: GetEmergencyOutcomeUseCase(feed),
              acknowledge: AcknowledgeEmergencyUseCase(feed),
              getHome: GetHomeUseCase(homes),
              pollEvery: const Duration(hours: 1),
            ));
    Widget keyed(String id) => MaterialApp(
          home: EmergencyAlertPage(
            emergencyId: id,
            cubit: cubitFor(id),
            phoneDialer: dialer,
            openExternal: (_) async => true,
            emergencyPhone: '192',
          ),
        );
    await tester.pumpWidget(keyed('em-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estou indo'));
    await tester.pumpAndSettle();
    expect(find.text('Ana avisou que está indo.'), findsOneWidget);

    // chega outro SOS, ainda sem confirmação
    feed.status = ActiveEmergency(
        id: 'em-2', state: 'dispatched', createdAt: DateTime(2026, 10, 7, 4));
    await tester.pumpWidget(keyed('em-2'));
    await tester.pumpAndSettle();

    expect(find.text('Ana avisou que está indo.'), findsNothing);
    expect(find.text('Estou indo'), findsOneWidget);
  });
}
