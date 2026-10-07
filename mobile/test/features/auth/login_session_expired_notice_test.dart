import 'package:aura/core/di/service_locator.dart';
import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';
import 'package:aura/features/auth/domain/entities/user_entity.dart';
import 'package:aura/features/auth/domain/repositories/auth_repository.dart';
import 'package:aura/features/auth/domain/usecases/login_usecase.dart';
import 'package:aura/features/auth/domain/usecases/logout_usecase.dart';
import 'package:aura/features/auth/domain/usecases/signup_usecase.dart';
import 'package:aura/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:aura/features/auth/presentation/pages/login_page.dart';
import 'package:aura/features/auth/presentation/widgets/login_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Login que sempre recusa a senha.
class _WrongPasswordRepository implements AuthRepository {
  @override
  Future<Result<UserEntity>> login(String email, String password) async =>
      const Failure(AppFailure.unauthorized(message: 'senha errada'));

  @override
  Future<Result<UserEntity>> signup(
    String email,
    String password,
    String role,
  ) async =>
      const Failure(AppFailure.unauthorized(message: 'senha errada'));

  @override
  Future<Result<void>> logout() async => const Success(null);
}

AuthBloc _bloc() {
  final repo = _WrongPasswordRepository();
  return AuthBloc(
    loginUseCase: LoginUseCase(repo),
    signupUseCase: SignupUseCase(repo),
    logoutUseCase: LogoutUseCase(repo),
  );
}

Widget _body({required bool notice}) => MaterialApp(
      home: BlocProvider(
        create: (_) => _bloc(),
        child: LoginBody(showSessionExpiredNotice: notice),
      ),
    );

/// #14 — a tela de login diz por que o app voltou para ela, uma vez só.
void main() {
  testWidgets('primeiro uso / logout voluntário: sem aviso', (tester) async {
    await tester.pumpWidget(_body(notice: false));

    expect(find.text(sessionExpiredMessage), findsNothing);
  });

  testWidgets('aviso aparece e some ao digitar', (tester) async {
    await tester.pumpWidget(_body(notice: true));
    expect(find.text(sessionExpiredMessage), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'a');
    await tester.pump();

    expect(find.text(sessionExpiredMessage), findsNothing);
  });

  testWidgets('aviso some ao tentar entrar', (tester) async {
    await tester.pumpWidget(_body(notice: true));
    expect(find.text(sessionExpiredMessage), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();
    // Formulário vazio: a validação local barra o envio, e o aviso já foi.
    expect(find.text(sessionExpiredMessage), findsNothing);
  });

  group('LoginPage consome o marcador da sessão', () {
    late AuthSession session;

    setUp(() async {
      await sl.reset();
      FlutterSecureStorage.setMockInitialValues({'access_token': 'jwt'});
      session = AuthSession(TokenStore(const FlutterSecureStorage()));
      await session.bootstrap();
      sl.registerSingleton<AuthSession>(session);
      sl.registerFactory<AuthBloc>(_bloc);
    });

    tearDown(sl.reset);

    testWidgets('logout forçado: aviso uma vez; a próxima tela não o repete',
        (tester) async {
      await session.onLoggedOut(forced: true);

      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      expect(find.text(sessionExpiredMessage), findsOneWidget);
      expect(session.hasSessionExpiredNotice, isFalse);

      // Reconstruir a mesma tela não reacende nem apaga por conta própria.
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      expect(find.text(sessionExpiredMessage), findsOneWidget);

      // Uma tela de login nova (outra visita) já não vê o aviso.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));
      expect(find.text(sessionExpiredMessage), findsNothing);
    });

    testWidgets('logout voluntário: nenhum aviso', (tester) async {
      await session.onLoggedOut();

      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      expect(find.text(sessionExpiredMessage), findsNothing);
    });

    testWidgets('senha errada depois do aviso mostra o erro do login',
        (tester) async {
      await session.onLoggedOut(forced: true);
      await tester.pumpWidget(const MaterialApp(home: LoginPage()));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'maria@aura.com');
      await tester.enterText(fields.at(1), 'senhaerrada1');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();
      await tester.pump();

      expect(find.text(sessionExpiredMessage), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
