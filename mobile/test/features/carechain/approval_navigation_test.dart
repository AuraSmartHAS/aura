import 'package:aura/core/di/service_locator.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/router/app_routes.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';
import 'package:aura/features/carechain/domain/entities/recommendation.dart';
import 'package:aura/features/carechain/domain/repositories/carechain_repository.dart';
import 'package:aura/features/carechain/domain/usecases/approve_recommendation_usecase.dart';
import 'package:aura/features/carechain/domain/usecases/create_recommendation_usecase.dart';
import 'package:aura/features/carechain/presentation/approval_copy.dart';
import 'package:aura/features/carechain/presentation/bloc/carechain_bloc.dart';
import 'package:aura/features/carechain/presentation/pages/carechain_page.dart';
import 'package:aura/features/home_setup/domain/entities/home.dart';
import 'package:aura/features/home_setup/domain/repositories/home_repository.dart';
import 'package:aura/features/home_setup/domain/usecases/get_home_usecase.dart';
import 'package:aura/features/wellbeing360/domain/entities/score.dart';
import 'package:aura/features/wellbeing360/domain/repositories/scores_repository.dart';
import 'package:aura/features/wellbeing360/domain/usecases/recompute_score_usecase.dart';
import 'package:aura/shared/models/severity_level.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Correção #6 — beco sem saída depois de aprovar a compra.
///
/// Aprovar fazia `context.go('/orders/:id')`, que troca a pilha inteira: a tela
/// do pedido ficava sem seta de voltar e o voltar do sistema fechava o app. O
/// destino escolhido para o voltar é o próprio Care-Chain, recarregado, que
/// agora mostra o item "já pedido" travado em vez de um "Aprovar" velho.
void main() {
  late _FakeCareChainRepository repository;
  late List<String> systemCalls;

  setUp(() {
    // A página lê o telefone de suporte do .env (AppConfig).
    dotenv.testLoad(fileInput: 'SUPPORT_PHONE=');
    repository = _FakeCareChainRepository();
    sl.registerFactory<CareChainBloc>(() => _buildBloc(repository));

    systemCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      systemCalls.add(call.method);
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await sl.reset();
  });

  testWidgets(
      'aprovar empilha o pedido com seta de voltar; o voltar do sistema '
      'retorna ao Care-Chain recarregado, sem fechar o app', (tester) async {
    final router = await _pumpApp(tester);
    await _approve(tester);

    // Tela do pedido, empilhada sobre o Care-Chain.
    expect(router.state.matchedLocation, AppRoutes.orderDetail('order-1'));
    expect(find.text('Acompanhar pedido'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(router.canPop(), isTrue);

    // Voltar do sistema (o botão do Android).
    await tester.binding.handlePopRoute();
    await _settle(tester);

    expect(systemCalls, isNot(contains('SystemNavigator.pop')));
    expect(router.state.matchedLocation, AppRoutes.careChain);

    // Recarregado: o item aparece já pedido e o "Aprovar" não vale mais.
    expect(repository.approved, ['rec-1']);
    expect(repository.createCalls, 2);
    expect(find.text(ApprovalCopy.itemAlreadyOrdered), findsOneWidget);
    final approve = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Aprovar e pedir'),
    );
    expect(approve.onPressed, isNull);

    // E o Care-Chain ainda tem para onde voltar: o painel.
    expect(router.canPop(), isTrue);
  });

  testWidgets('a seta da AppBar do pedido também volta ao Care-Chain',
      (tester) async {
    final router = await _pumpApp(tester);
    await _approve(tester);

    await tester.tap(find.byType(BackButton));
    await _settle(tester);

    expect(router.state.matchedLocation, AppRoutes.careChain);
    expect(find.text(ApprovalCopy.itemAlreadyOrdered), findsOneWidget);
  });
}

// ── Helpers ────────────────────────────────────────────────────────────

/// Painel → Care-Chain por `push`, como o app real faz a partir do dashboard.
Future<GoRouter> _pumpApp(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: AppRoutes.dashboard,
    routes: [
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Painel')),
          body: TextButton(
            onPressed: () => context.push(AppRoutes.careChain),
            child: const Text('Abrir Care-Chain'),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.careChain,
        builder: (context, state) => const CareChainPage(),
      ),
      // Casca da tela do pedido: o que importa aqui é a pilha, não o tracker.
      GoRoute(
        path: '${AppRoutes.orders}/:id',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Acompanhar pedido')),
          body: Text('Pedido ${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await _settle(tester);
  await tester.tap(find.text('Abrir Care-Chain'));
  await _settle(tester);
  return router;
}

Future<void> _approve(WidgetTester tester) async {
  final approve = find.widgetWithText(FilledButton, 'Aprovar e pedir');
  await tester.ensureVisible(approve);
  await tester.pump();
  await tester.tap(approve);
  await _settle(tester);

  final confirm = find.widgetWithText(FilledButton, 'Confirmar e pedir');
  await tester.ensureVisible(confirm);
  await tester.pump();
  await tester.tap(confirm);
  await _settle(tester);
}

/// `pumpAndSettle` nunca assenta (o carregamento anima para sempre); bombeia
/// tempo suficiente para as transições de rota e da folha terminarem.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Recommendation _reco({String? orderInProgressId}) {
  return Recommendation(
    recommendationId: 'rec-1',
    sku: 'SKU-BARRA-01',
    productName: 'Barra de apoio para banheiro',
    price: 129.90,
    reason: 'Recomendamos Barra de apoio para banheiro (NBR 9050).',
    normRef: 'NBR 9050',
    factors: const ['near_fall_reported'],
    weights: const [0.4],
    level: SeverityLevel.high,
    status: orderInProgressId == null ? 'recommended' : 'approved',
    factorLabels: const ['quase-queda relatada'],
    installable: true,
    installationIncluded: false,
    installationPrice: 149.90,
    orderInProgressId: orderInProgressId,
    orderInProgressStage: orderInProgressId == null ? null : 'created',
  );
}

CareChainBloc _buildBloc(_FakeCareChainRepository repository) {
  return CareChainBloc(
    recomputeScoreUseCase: RecomputeScoreUseCase(_FakeScoresRepository()),
    createRecommendationUseCase: CreateRecommendationUseCase(repository),
    approveRecommendationUseCase: ApproveRecommendationUseCase(repository),
    getHomeUseCase: GetHomeUseCase(_FakeHomeRepository()),
    session: AuthSession(TokenStore(const FlutterSecureStorage()))
      ..setHomeId('home-1'),
  );
}

// ── Fakes ──────────────────────────────────────────────────────────────

/// Espelha o servidor: idempotente por item; depois de aprovada, a
/// recomendação volta com o pedido em andamento.
class _FakeCareChainRepository implements CareChainRepository {
  final List<String> approved = [];
  int createCalls = 0;

  @override
  Future<Result<Recommendation>> createRecommendation({
    required String homeId,
    String? scoreId,
    required SeverityLevel level,
  }) async {
    createCalls++;
    return Success(
      _reco(orderInProgressId: approved.isEmpty ? null : 'order-1'),
    );
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
          factors: ['near_fall_reported'],
          weights: [0.4],
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
