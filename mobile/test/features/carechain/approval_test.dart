import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';
import 'package:aura/features/carechain/domain/entities/recommendation.dart';
import 'package:aura/features/carechain/domain/repositories/carechain_repository.dart';
import 'package:aura/features/carechain/domain/usecases/approve_recommendation_usecase.dart';
import 'package:aura/features/carechain/domain/usecases/create_recommendation_usecase.dart';
import 'package:aura/features/carechain/domain/usecases/find_pending_recommendation_usecase.dart';
import 'package:aura/features/carechain/presentation/approval_copy.dart';
import 'package:aura/features/carechain/presentation/bloc/carechain_bloc.dart';
import 'package:aura/features/carechain/presentation/widgets/carechain_body.dart';
import 'package:aura/features/home_setup/domain/entities/home.dart';
import 'package:aura/features/home_setup/domain/repositories/home_repository.dart';
import 'package:aura/features/home_setup/domain/usecases/get_home_usecase.dart';
import 'package:aura/features/wellbeing360/domain/entities/score.dart';
import 'package:aura/features/wellbeing360/domain/repositories/scores_repository.dart';
import 'package:aura/features/wellbeing360/domain/usecases/recompute_score_usecase.dart';
import 'package:aura/shared/models/severity_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Correção C5 — aprovação digna de dinheiro.
///
/// A Ana aprovava a compra de um item de segurança para a casa da Maria sem ver
/// o preço (CR-5) e só descobria que um técnico entraria na casa depois de
/// aprovar (AL-11). Estes testes prendem os dois consertos e a regressão do
/// POST duplicado.
void main() {
  group('preço obrigatório (CR-5)', () {
    testWidgets(
        'sem preço, o botão de aprovar fica desabilitado e a tela diz por quê',
        (tester) async {
      final repository = _FakeCareChainRepository(
        recommendation: (id) => _reco(id: id, price: null),
      );
      final bloc = await _pumpCareChain(tester, repository);
      addTearDown(bloc.close);

      // O bug: o card escondia o preço e mantinha "Aprovar" ativo.
      expect(find.text(ApprovalCopy.priceUnavailableTitle), findsOneWidget);
      expect(find.text(ApprovalCopy.priceUnavailableMessage), findsOneWidget);
      expect(find.textContaining('Total R\$'), findsNothing);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Aprovar e pedir'),
      );
      expect(button.onPressed, isNull);
      expect(
          find.text(ApprovalCopy.approveBlockedWithoutPrice), findsOneWidget);
    });

    testWidgets('com preço, o botão volta a valer e mostra o total',
        (tester) async {
      final repository =
          _FakeCareChainRepository(recommendation: (id) => _reco(id: id));
      final bloc = await _pumpCareChain(tester, repository);
      addTearDown(bloc.close);

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Aprovar e pedir'),
      );
      expect(button.onPressed, isNotNull);
      expect(find.text(ApprovalCopy.approveBlockedWithoutPrice), findsNothing);
      expect(find.text(ApprovalCopy.priceUnavailableTitle), findsNothing);

      // WCAG 2.5.5: alvo de toque confortável.
      final size = tester.getSize(
        find.widgetWithText(FilledButton, 'Aprovar e pedir'),
      );
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });

  group('total explícito', () {
    test('soma item mais instalação', () {
      final reco = _reco(price: 129.90, installationPrice: 149.90);

      expect(reco.total, closeTo(279.80, 0.001));
      expect(
        ApprovalCopy.totalLine(reco),
        'Total R\$ 279,80 — item R\$ 129,90 + instalação R\$ 149,90',
      );
    });

    test('instalação incluída não é somada duas vezes', () {
      // O servidor manda 0 quando a instalação está inclusa, mas um valor
      // residual não pode virar cobrança dupla na tela.
      final reco = _reco(
        price: 129.90,
        installationIncluded: true,
        installationPrice: 149.90,
      );

      expect(reco.installationCost, 0);
      expect(reco.total, closeTo(129.90, 0.001));
      expect(
        ApprovalCopy.totalLine(reco),
        'Total R\$ 129,90 — instalação incluída no valor',
      );
    });

    test('item sem instalação mostra só o total', () {
      final reco = _reco(
        price: 1279.90,
        installable: false,
        installationPrice: null,
      );

      expect(reco.total, closeTo(1279.90, 0.001));
      expect(ApprovalCopy.totalLine(reco), 'Total R\$ 1.279,90');
    });

    testWidgets('a composição do total aparece na tela', (tester) async {
      final repository =
          _FakeCareChainRepository(recommendation: (id) => _reco(id: id));
      final bloc = await _pumpCareChain(tester, repository);
      addTearDown(bloc.close);

      expect(
        find.text('Total R\$ 279,80 — item R\$ 129,90 + instalação R\$ 149,90'),
        findsOneWidget,
      );
    });
  });

  group('fatores em português', () {
    testWidgets('a tela usa factorLabels, não o código do fator',
        (tester) async {
      final repository =
          _FakeCareChainRepository(recommendation: (id) => _reco(id: id));
      final bloc = await _pumpCareChain(tester, repository);
      addTearDown(bloc.close);

      expect(find.text('quase-queda relatada'), findsOneWidget);
      expect(find.text('ausência de barra de apoio'), findsOneWidget);
      expect(find.textContaining('near_fall_reported'), findsNothing);
      expect(find.textContaining('no_grab_bar'), findsNothing);
    });

    test('sem rótulo do servidor, o código degrada sem underscore', () {
      final reco = _reco(factorLabels: const []);
      expect(reco.factorDisplayLabels,
          const ['near fall reported', 'no grab bar']);
    });
  });

  group('instalação e confirmação', () {
    testWidgets('o card diz quem entra na casa antes de a Ana decidir',
        (tester) async {
      final repository =
          _FakeCareChainRepository(recommendation: (id) => _reco(id: id));
      final bloc = await _pumpCareChain(tester, repository);
      addTearDown(bloc.close);

      expect(
        find.text(
          'Um técnico da rede parceira vai à casa da Maria instalar. Você '
          'escolhe o dia e pode estar presente. Antes da visita você recebe o '
          'nome e a foto dele, e ele se identifica na porta.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'um toque abre a folha de confirmação — só ela cria o pedido, '
        'e ela não promete cancelamento que não existe', (tester) async {
      final repository =
          _FakeCareChainRepository(recommendation: (id) => _reco(id: id));
      final bloc = await _pumpCareChain(tester, repository);
      addTearDown(bloc.close);

      await _tap(tester, find.widgetWithText(FilledButton, 'Aprovar e pedir'));
      await tester.pump(const Duration(milliseconds: 400));

      // Item, preço total, endereço, instalação e quem paga.
      expect(find.text('Barra de apoio para banheiro'), findsWidgets);
      expect(
        find.text('Total R\$ 279,80 — item R\$ 129,90 + instalação R\$ 149,90'),
        findsWidgets,
      );
      expect(find.textContaining('Rua das Acácias, 120'), findsOneWidget);
      expect(find.text('Quem paga'), findsOneWidget);
      expect(find.text(ApprovalCopy.payer), findsOneWidget);

      // A rota de cancelamento não existe: em vez de um botão que mentiria,
      // a folha entrega o caminho humano com o telefone visível.
      expect(find.text(ApprovalCopy.changedMind), findsOneWidget);
      expect(find.textContaining('(11) 0000-0000'), findsOneWidget);
      expect(find.textContaining('Cancelar'), findsNothing);

      // Nada foi comprado ainda.
      expect(repository.approved, isEmpty);

      await _tap(tester, find.widgetWithText(FilledButton, 'Confirmar e pedir'));
      await _settle(tester);

      expect(repository.approved, ['rec-1']);
    });

    testWidgets('voltar sem pedir não cria pedido', (tester) async {
      final repository =
          _FakeCareChainRepository(recommendation: (id) => _reco(id: id));
      final bloc = await _pumpCareChain(tester, repository);
      addTearDown(bloc.close);

      await _tap(tester, find.widgetWithText(FilledButton, 'Aprovar e pedir'));
      await tester.pump(const Duration(milliseconds: 400));

      await _tap(tester, find.text('Voltar sem pedir'));
      await _settle(tester);

      expect(repository.approved, isEmpty);
    });
  });

  test('regressão: abrir a tela cinco vezes gera UMA recomendação, não cinco',
      () async {
    final repository =
        _FakeCareChainRepository(recommendation: (id) => _reco(id: id));

    for (var i = 0; i < 5; i++) {
      final bloc = _buildBloc(repository);
      final ready =
          bloc.stream.firstWhere((s) => s.status == CareChainStatus.ready);
      bloc.add(const LoadRecommendationEvent());
      await ready;
      await bloc.close();
    }

    // O app disparava POST /recommendations a cada abertura e duplicava a
    // recomendação no painel da cuidadora.
    expect(repository.createCalls, 1);
    expect(repository.listCalls, 5);
  });
}

// ── Fixtures ───────────────────────────────────────────────────────────

Recommendation _reco({
  String id = 'rec-1',
  double? price = 129.90,
  bool installable = true,
  bool installationIncluded = false,
  double? installationPrice = 149.90,
  String status = 'recommended',
  List<String> factors = const ['near_fall_reported', 'no_grab_bar'],
  List<String> factorLabels = const [
    'quase-queda relatada',
    'ausência de barra de apoio',
  ],
}) {
  return Recommendation(
    recommendationId: id,
    sku: 'SKU-BARRA-01',
    productName: 'Barra de apoio para banheiro',
    price: price,
    reason: 'Recomendamos Barra de apoio para banheiro porque houve '
        'quase-queda relatada e ausência de barra de apoio (NBR 9050).',
    normRef: 'NBR 9050',
    factors: factors,
    weights: const [0.4, 0.3],
    level: SeverityLevel.high,
    status: status,
    factorLabels: factorLabels,
    installable: installable,
    installationIncluded: installationIncluded,
    installationPrice: installationPrice,
  );
}

CareChainBloc _buildBloc(
  _FakeCareChainRepository repository, {
  HomeRepository? homeRepository,
}) {
  return CareChainBloc(
    recomputeScoreUseCase: RecomputeScoreUseCase(_FakeScoresRepository()),
    createRecommendationUseCase: CreateRecommendationUseCase(repository),
    findPendingRecommendationUseCase:
        FindPendingRecommendationUseCase(repository),
    approveRecommendationUseCase: ApproveRecommendationUseCase(repository),
    getHomeUseCase: GetHomeUseCase(homeRepository ?? _FakeHomeRepository()),
    session: AuthSession(TokenStore(const FlutterSecureStorage()))
      ..setHomeId('home-1'),
  );
}

Future<CareChainBloc> _pumpCareChain(
  WidgetTester tester,
  _FakeCareChainRepository repository, {
  HomeRepository? homeRepository,
}) async {
  final bloc = _buildBloc(repository, homeRepository: homeRepository);
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<CareChainBloc>.value(
        value: bloc..add(const LoadRecommendationEvent()),
        child: const CareChainBody(),
      ),
    ),
  );
  await _settle(tester);
  return bloc;
}

/// `pumpAndSettle` nunca assenta: o estado de carregamento tem um
/// CircularProgressIndicator, que anima para sempre.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

/// A tela é mais alta que a janela de 800x600 do teste — o card inteiro cabe na
/// árvore, mas o botão fica abaixo da dobra. Rola até ele antes de tocar.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

// ── Fakes ──────────────────────────────────────────────────────────────

class _FakeCareChainRepository implements CareChainRepository {
  _FakeCareChainRepository({required this.recommendation});

  final Recommendation Function(String id) recommendation;

  final List<Recommendation> stored = [];
  final List<String> approved = [];
  int createCalls = 0;
  int listCalls = 0;

  @override
  Future<Result<Recommendation>> createRecommendation({
    required String homeId,
    String? scoreId,
    required SeverityLevel level,
  }) async {
    createCalls++;
    final reco = recommendation('rec-$createCalls');
    stored.add(reco);
    return Success(reco);
  }

  @override
  Future<Result<Recommendation?>> findPendingRecommendation({
    required String homeId,
    required SeverityLevel level,
  }) async {
    listCalls++;
    // Espelha o servidor: da mais recente para a mais antiga.
    for (final reco in stored.reversed) {
      if (reco.isPending) return Success(reco);
    }
    return const Success(null);
  }

  @override
  Future<Result<String>> approve(String recommendationId) async {
    approved.add(recommendationId);
    return const Success('order-1');
  }
}

class _FakeScoresRepository implements ScoresRepository {
  @override
  Future<Result<List<Score>>> getScores(String homeId) async =>
      const Success([]);

  @override
  Future<Result<Score>> recompute(String homeId, {String? dimension}) async =>
      const Success(
        Score(
          scoreId: 'score-1',
          dimension: WellbeingDimensionType.mobility,
          level: SeverityLevel.high,
          score: 0.9,
          factors: ['near_fall_reported', 'no_grab_bar'],
          weights: [0.4, 0.3],
          explanation: 'Norma NBR 9050 → risco ALTO.',
        ),
      );
}

class _FakeHomeRepository implements HomeRepository {
  @override
  Future<Result<Home>> createHome({
    required String patientName,
    String? birthDate,
    required String cep,
    String? label,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Result<HomeDetail>> getHome(String homeId) async => Success(
        HomeDetail(
          home: Home(
            id: homeId,
            label: 'Casa da Maria',
            address: 'Rua das Acácias, 120 — São Paulo',
            lat: null,
            lng: null,
          ),
          patientName: 'Maria Silva',
          checklist: const {},
        ),
      );

  @override
  Future<Result<Map<String, bool>>> updateChecklist(
    String homeId,
    Map<String, bool> items,
  ) async =>
      Success(items);
}
