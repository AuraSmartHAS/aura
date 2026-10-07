import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';
import 'package:aura/core/session/user_role.dart';
import 'package:aura/features/caregiver_dashboard/domain/entities/care_signal.dart';
import 'package:aura/features/caregiver_dashboard/domain/repositories/care_feed_repository.dart';
import 'package:aura/features/caregiver_dashboard/domain/usecases/care_feed_usecases.dart';
import 'package:aura/features/medications/domain/entities/medication.dart';
import 'package:aura/features/medications/domain/repositories/medication_repository.dart';
import 'package:aura/features/medications/domain/usecases/confirm_dose_usecase.dart';
import 'package:aura/features/medications/domain/usecases/delete_medication_usecase.dart';
import 'package:aura/features/medications/domain/usecases/get_medications_usecase.dart';
import 'package:aura/features/medications/domain/usecases/save_medication_usecase.dart';
import 'package:aura/features/medications/presentation/bloc/medication_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// O estado de hoje dos remédios é da família: sem os sinais ele NÃO existe, e a
/// tela diz que não carregou — nunca "atrasada" calculado só pelo relógio.
void main() {
  late AuthSession session;
  late _Meds meds;
  late _Feed feed;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    session = AuthSession(TokenStore(const FlutterSecureStorage()));
    await session.onLoggedIn(UserRole.cuidadora);
    session.setHomeId('home-1');
    meds = _Meds();
    feed = _Feed();
  });

  MedicationBloc build({bool withFeed = true}) => MedicationBloc(
        getMedicationsUseCase: GetMedicationsUseCase(meds),
        saveMedicationUseCase: SaveMedicationUseCase(meds),
        deleteMedicationUseCase: DeleteMedicationUseCase(meds),
        confirmDoseUseCase: ConfirmDoseUseCase(meds),
        session: session,
        getCareSignalsUseCase:
            withFeed ? GetCareSignalsUseCase(feed) : null,
        now: () => DateTime(2026, 10, 7, 12, 40),
      );

  test('a lista aparece primeiro; o status de hoje chega depois, só da família',
      () async {
    final bloc = build();
    addTearDown(bloc.close);

    final states = <MedicationState>[];
    final sub = bloc.stream.listen(states.add);
    addTearDown(sub.cancel);
    bloc.add(const LoadMedicationsEvent());
    await bloc.stream
        .firstWhere((s) => s.todayStatus == TodayStatus.loaded);

    final ready = states.where((s) => s.status == MedicationStatus.ready);
    // 1º ready: a lista, com o status ainda carregando (não atrasa os remédios).
    expect(ready.first.medications, isNotEmpty);
    expect(ready.first.todayStatus, TodayStatus.loading);
    expect(bloc.state.todayById, contains('med-los'));
    // O recorte pedido é só de adesão, desde hoje.
    expect(feed.typesRequested.single, 'adherence');
    expect(feed.sinceRequested.single, DateTime(2026, 10, 7));
  });

  test('sinais que falharam: failed, mapa vazio — não "atrasada" pelo relógio',
      () async {
    feed.failure = const AppFailure.networkError(message: 'caiu');
    final bloc = build();
    addTearDown(bloc.close);

    bloc.add(const LoadMedicationsEvent());
    await bloc.stream.firstWhere((s) => s.todayStatus == TodayStatus.failed);

    expect(bloc.state.todayById, isEmpty);
    expect(bloc.state.medications, isNotEmpty);
  });

  test('a paciente não carrega o estado de hoje (é ela quem confirma a dose)',
      () async {
    await session.onLoggedIn(UserRole.paciente);
    session.setHomeId('home-1');
    final bloc = build();
    addTearDown(bloc.close);

    bloc.add(const LoadMedicationsEvent());
    await bloc.stream.firstWhere((s) => s.status == MedicationStatus.ready);

    expect(bloc.state.todayStatus, TodayStatus.notApplicable);
    expect(feed.typesRequested, isEmpty);
  });
}

class _Meds implements MedicationRepository {
  @override
  Future<Result<List<Medication>>> getMedications(String homeId) async =>
      const Success([
        Medication(
          id: 'med-los',
          homeId: 'home-1',
          name: 'Losartana',
          times: ['08:00'],
        ),
      ]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Feed implements CareFeedRepository {
  Object? failure;
  final List<String?> typesRequested = [];
  final List<DateTime?> sinceRequested = [];

  @override
  Future<Result<List<CareSignal>>> getSignals(String homeId,
      {int limit = 200, DateTime? since, String? type}) async {
    typesRequested.add(type);
    sinceRequested.add(since);
    if (failure != null) return Failure(failure);
    return const Success([]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
