import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';
import 'package:aura/features/medications/domain/entities/medication.dart';
import 'package:aura/features/medications/domain/repositories/medication_repository.dart';
import 'package:aura/features/medications/domain/usecases/confirm_dose_usecase.dart';
import 'package:aura/features/medications/domain/usecases/delete_medication_usecase.dart';
import 'package:aura/features/medications/domain/usecases/get_medications_usecase.dart';
import 'package:aura/features/medications/domain/usecases/save_medication_usecase.dart';
import 'package:aura/features/medications/presentation/bloc/medication_bloc.dart';
import 'package:aura/features/medications/presentation/widgets/medications_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositório em memória no papel do servidor.
class _FakeMedications implements MedicationRepository {
  _FakeMedications(this.meds);

  List<Medication> meds;
  final List<(String, bool)> confirmations = [];
  final List<(String?, MedicationInput)> saves = [];
  Object? confirmFailure;

  @override
  Future<Result<List<Medication>>> getMedications(String homeId) async =>
      Success(List.of(meds));

  @override
  Future<Result<Medication>> create(
      String homeId, MedicationInput input) async {
    saves.add((null, input));
    final med = Medication(
      id: 'novo',
      homeId: homeId,
      name: input.name,
      times: input.times,
      stockDoses: input.stockDoses,
    );
    meds = [...meds, med];
    return Success(med);
  }

  @override
  Future<Result<Medication>> update(String id, MedicationInput input) async {
    saves.add((id, input));
    final med = Medication(
      id: id,
      homeId: 'home-1',
      name: input.name,
      times: input.times,
      stockDoses: input.stockDoses,
    );
    return Success(med);
  }

  @override
  Future<Result<void>> delete(String id) async {
    meds = meds.where((m) => m.id != id).toList();
    return const Success(null);
  }

  @override
  Future<Result<DoseConfirmation>> confirmDose(
    String id, {
    required bool taken,
    String? source,
  }) async {
    confirmations.add((id, taken));
    if (confirmFailure != null) return Failure(confirmFailure);
    final med = meds.firstWhere((m) => m.id == id);
    final stock = med.stockDoses == null
        ? null
        : (taken ? med.stockDoses! - 1 : med.stockDoses!);
    return Success(
      DoseConfirmation(signalId: 'sig', taken: taken, stockDoses: stock),
    );
  }
}

const _losartana = Medication(
  id: 'med-1',
  homeId: 'home-1',
  name: 'Losartana',
  dosage: '50mg',
  times: ['08:00'],
  stockDoses: 12,
);

MedicationBloc _bloc(MedicationRepository repo) {
  FlutterSecureStorage.setMockInitialValues({});
  return MedicationBloc(
    getMedicationsUseCase: GetMedicationsUseCase(repo),
    saveMedicationUseCase: SaveMedicationUseCase(repo),
    deleteMedicationUseCase: DeleteMedicationUseCase(repo),
    confirmDoseUseCase: ConfirmDoseUseCase(repo),
    session: AuthSession(TokenStore(const FlutterSecureStorage()))
      ..setHomeId('home-1'),
  );
}

Future<MedicationState> _settle(MedicationBloc bloc) async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return bloc.state;
}

void main() {
  group('MedicationBloc', () {
    test('carrega a lista do repositório (servidor)', () async {
      final bloc = _bloc(_FakeMedications([_losartana]))
        ..add(const LoadMedicationsEvent());
      addTearDown(bloc.close);

      final state = await _settle(bloc);

      expect(state.status, MedicationStatus.ready);
      expect(state.medications, [_losartana]);
    });

    test('"Tomei" atualiza o estoque com a resposta e dá feedback', () async {
      final repo = _FakeMedications([_losartana]);
      final bloc = _bloc(repo)..add(const LoadMedicationsEvent());
      addTearDown(bloc.close);
      await _settle(bloc);

      bloc.add(const ConfirmDoseEvent('med-1', taken: true));
      final state = await _settle(bloc);

      expect(repo.confirmations, [('med-1', true)]);
      expect(state.medications.single.stockDoses, 11);
      expect(state.confirmingIds, isEmpty);
      expect(state.feedback?.message, 'Dose registrada. 11 doses em estoque.');
      expect(state.feedback?.isError, isFalse);
    });

    test('"Não tomei" registra sem descontar o estoque', () async {
      final repo = _FakeMedications([_losartana]);
      final bloc = _bloc(repo)..add(const LoadMedicationsEvent());
      addTearDown(bloc.close);
      await _settle(bloc);

      bloc.add(const ConfirmDoseEvent('med-1', taken: false));
      final state = await _settle(bloc);

      expect(repo.confirmations, [('med-1', false)]);
      expect(state.medications.single.stockDoses, 12);
      expect(
          state.feedback?.message, startsWith('Registrado: dose não tomada.'));
    });

    test('falha de rede ao confirmar vira feedback de erro e mantém a lista',
        () async {
      final repo = _FakeMedications([_losartana])
        ..confirmFailure = const AppFailure.networkError(
          message: 'Sem conexão com o servidor. Tente novamente.',
        );
      final bloc = _bloc(repo)..add(const LoadMedicationsEvent());
      addTearDown(bloc.close);
      await _settle(bloc);

      bloc.add(const ConfirmDoseEvent('med-1', taken: true));
      final state = await _settle(bloc);

      expect(state.status, MedicationStatus.ready);
      expect(state.medications.single.stockDoses, 12);
      expect(state.feedback?.isError, isTrue);
      expect(state.feedback?.message, contains('Sem conexão'));
    });

    test('cadastro envia os horários validados e entra na lista', () async {
      final repo = _FakeMedications([_losartana]);
      final bloc = _bloc(repo)..add(const LoadMedicationsEvent());
      addTearDown(bloc.close);
      await _settle(bloc);

      bloc.add(const SaveMedicationEvent(
        name: 'Atenolol',
        times: ['08:00', '20:00'],
        stockDoses: 60,
      ));
      final state = await _settle(bloc);

      expect(repo.saves.single.$1, isNull);
      expect(repo.saves.single.$2.times, ['08:00', '20:00']);
      expect(repo.saves.single.$2.stockDoses, 60);
      expect(state.medications.map((m) => m.name), ['Atenolol', 'Losartana']);
      expect(state.feedback?.message, 'Medicamento cadastrado.');
    });
  });

  group('tela de medicamentos', () {
    Future<_FakeMedications> pump(WidgetTester tester) async {
      final repo = _FakeMedications([_losartana]);
      final bloc = _bloc(repo)..add(const LoadMedicationsEvent());
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<MedicationBloc>.value(
            value: bloc,
            child: const MedicationsBody(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('cada medicamento mostra estoque e "Tomei"/"Não tomei"',
        (tester) async {
      await pump(tester);

      expect(find.text('Estoque: 12 doses'), findsOneWidget);
      expect(find.text('Tomei'), findsOneWidget);
      expect(find.text('Não tomei'), findsOneWidget);
    });

    testWidgets('lista agrupa por período a partir dos horários HH:mm',
        (tester) async {
      // Tela alta para que todos os grupos estejam montados ao mesmo tempo.
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _FakeMedications([
        _losartana,
        const Medication(
          id: 'med-2',
          homeId: 'home-1',
          name: 'Metformina',
          times: ['20:00', '13:00'],
        ),
        const Medication(id: 'med-3', homeId: 'home-1', name: 'Vitamina D'),
      ]);
      final bloc = _bloc(repo)..add(const LoadMedicationsEvent());
      addTearDown(bloc.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<MedicationBloc>.value(
            value: bloc,
            child: const MedicationsBody(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      double top(Finder f) => tester.getTopLeft(f).dy;

      // Cabeçalhos na ordem do dia.
      final manha = top(find.text('Manhã'));
      final tarde = top(find.text('Tarde'));
      final noite = top(find.text('Noite'));
      final semHorario = top(find.text('Sem horário definido'));
      expect(manha, lessThan(tarde));
      expect(tarde, lessThan(noite));
      expect(noite, lessThan(semHorario));

      // Losartana (08:00) fica na Manhã, não em "Sem horário definido".
      expect(find.text('Losartana'), findsOneWidget);
      expect(top(find.text('Losartana')), inInclusiveRange(manha, tarde));
      expect(find.text('08:00'), findsOneWidget);

      // Metformina aparece na Tarde só com 13:00 e na Noite só com 20:00.
      expect(find.text('Metformina'), findsNWidgets(2));
      expect(top(find.text('13:00')), inInclusiveRange(tarde, noite));
      expect(top(find.text('20:00')), inInclusiveRange(noite, semHorario));
      expect(find.text('13:00, 20:00'), findsNothing);

      // Só quem não tem horário fica em "Sem horário definido".
      expect(top(find.text('Vitamina D')), greaterThan(semHorario));
    });

    testWidgets('"Tomei" chama o confirm e mostra "Dose registrada"',
        (tester) async {
      final repo = await pump(tester);

      await tester.tap(find.text('Tomei'));
      await tester.pumpAndSettle();

      expect(repo.confirmations, [('med-1', true)]);
      expect(
          find.text('Dose registrada. 11 doses em estoque.'), findsOneWidget);
      expect(find.text('Estoque: 11 doses'), findsOneWidget);
    });

    testWidgets('formulário recusa horário em texto livre antes de enviar',
        (tester) async {
      final repo = await pump(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Nome'), 'Atenolol');
      await tester.enterText(
        find.widgetWithText(TextField, 'Horários'),
        '8h e 20h',
      );
      await tester.ensureVisible(find.text('Adicionar').last);
      await tester.tap(find.text('Adicionar').last);
      await tester.pumpAndSettle();

      expect(repo.saves, isEmpty);
      expect(
        find.textContaining('formato HH:mm, separados por vírgula'),
        findsOneWidget,
      );
    });

    testWidgets('sugestões inserem HH:mm e o estoque inicial é enviado',
        (tester) async {
      final repo = await pump(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Nome'), 'Atenolol');
      await tester.tap(find.text('Manhã · 08:00'));
      await tester.tap(find.text('Antes de dormir · 22:00'));
      await tester.tap(find.text('Manhã · 08:00'));
      await tester.pump();
      expect(find.text('08:00, 22:00'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Estoque inicial'),
        '30',
      );
      await tester.ensureVisible(find.text('Adicionar').last);
      await tester.tap(find.text('Adicionar').last);
      await tester.pumpAndSettle();

      expect(repo.saves.single.$2.times, ['08:00', '22:00']);
      expect(repo.saves.single.$2.stockDoses, 30);
    });
  });
}
