import 'package:aura/features/home_setup/domain/entities/home.dart';
import 'package:aura/features/home_setup/domain/repositories/home_repository.dart';
import 'package:aura/features/home_setup/domain/usecases/create_home_usecase.dart';
import 'package:aura/features/home_setup/domain/usecases/update_checklist_usecase.dart';
import 'package:aura/features/home_setup/presentation/bloc/home_setup_bloc.dart';
import 'package:aura/features/home_setup/presentation/widgets/onboarding_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// The checklist step never hits the repository while toggling.
class _UnusedRepository implements HomeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('not used by the checklist toggle');
}

/// Real bloc (so toggles really change state) that records every event.
class _RecordingBloc extends HomeSetupBloc {
  _RecordingBloc()
      : super(
          createHomeUseCase: CreateHomeUseCase(_UnusedRepository()),
          updateChecklistUseCase: UpdateChecklistUseCase(_UnusedRepository()),
        );

  final events = <HomeSetupEvent>[];

  @override
  void onEvent(HomeSetupEvent event) {
    events.add(event);
    super.onEvent(event);
  }
}

const _grabBar = SafetyChecklistKeys.grabBarBathroom;

Future<_RecordingBloc> _pumpChecklist(WidgetTester tester) async {
  final bloc = _RecordingBloc()
    // ignore: invalid_use_of_visible_for_testing_member
    ..emit(HomeSetupState.initial().copyWith(step: SetupStep.checklist));
  addTearDown(bloc.close);
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<HomeSetupBloc>.value(
        value: bloc,
        child: const OnboardingBody(),
      ),
    ),
  );
  await tester.pump();
  return bloc;
}

Finder _rowLabel() => find.text(SafetyChecklistKeys.label(_grabBar));

Switch _firstSwitch(WidgetTester tester) =>
    tester.widget<Switch>(find.byType(Switch).first);

void main() {
  testWidgets('tocar no rotulo da linha alterna e dispara o evento do bloc',
      (tester) async {
    final bloc = await _pumpChecklist(tester);
    expect(_firstSwitch(tester).value, isFalse);
    expect(find.text('Ponto de atenção'), findsWidgets);

    await tester.tap(_rowLabel());
    await tester.pump();

    expect(bloc.events, [const ToggleChecklistItemEvent(_grabBar, true)]);
    expect(bloc.state.checklist[_grabBar], isTrue);
    expect(_firstSwitch(tester).value, isTrue);
    expect(find.text('Tudo certo'), findsOneWidget);

    // Tapping the row again flips it back.
    await tester.tap(_rowLabel());
    await tester.pump();
    expect(bloc.events.last, const ToggleChecklistItemEvent(_grabBar, false));
    expect(bloc.state.checklist[_grabBar], isFalse);
  });

  testWidgets('tocar no Switch continua alternando (um unico evento)',
      (tester) async {
    final bloc = await _pumpChecklist(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(bloc.events, [const ToggleChecklistItemEvent(_grabBar, true)]);
    expect(_firstSwitch(tester).value, isTrue);
  });

  testWidgets('a linha inteira tem altura >= 48dp', (tester) async {
    await _pumpChecklist(tester);
    final inkWell = find.ancestor(
      of: _rowLabel(),
      matching: find.byType(InkWell),
    );
    expect(inkWell, findsOneWidget);
    expect(tester.getSize(inkWell).height, greaterThanOrEqualTo(48));
  });

  testWidgets('semantica expoe um unico toggle por item', (tester) async {
    final handle = tester.ensureSemantics();
    final bloc = await _pumpChecklist(tester);
    final label = SafetyChecklistKeys.label(_grabBar);

    // One merged node: toggle + tap, label announced exactly once (the
    // visible Text widgets do not merge in a second time).
    expect(
      tester.getSemantics(_rowLabel()),
      matchesSemantics(
        label: '$label. Ponto de atenção',
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );

    // Exactly one toggle node per row (no nested Switch node), and only one
    // node carries this item's label.
    final toggles = find.semantics.byFlag(SemanticsFlag.hasToggledState);
    expect(
      toggles.evaluate(),
      hasLength(find.byType(Switch, skipOffstage: false).evaluate().length),
    );
    expect(find.semantics.byLabel(RegExp(label)).evaluate(), hasLength(1));

    // The single semantic tap toggles the item once.
    tester.semantics.tap(find.semantics.byLabel(RegExp(label)));
    await tester.pump();
    expect(bloc.events, [const ToggleChecklistItemEvent(_grabBar, true)]);
    expect(
      tester.getSemantics(_rowLabel()),
      matchesSemantics(
        label: '$label. Tudo certo',
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );

    handle.dispose();
  });
}
