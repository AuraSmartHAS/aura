import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/session/auth_session.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/login_body.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Consumido uma única vez, ao abrir a tela: se o app voltou para cá por
  // logout forçado, a tela diz por quê; reconstruções não o reacendem.
  late final bool _sessionExpired =
      sl<AuthSession>().consumeSessionExpiredNotice();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthBloc>(),
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthSuccess) {
            // Route by role; the guard (refreshListenable: AuthSession) still
            // applies the LGPD consent gate before the role surface is shown.
            context.go(AppRouter.homeForRole());
          }
        },
        child: LoginBody(showSessionExpiredNotice: _sessionExpired),
      ),
    );
  }
}
