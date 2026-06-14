import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:aura/core/errors/failure_messages.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/session/user_role.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/signup_usecase.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required LoginUseCase loginUseCase,
    required SignupUseCase signupUseCase,
    required LogoutUseCase logoutUseCase,
  })  : _loginUseCase = loginUseCase,
        _signupUseCase = signupUseCase,
        _logoutUseCase = logoutUseCase,
        super(const AuthInitial()) {
    on<LoginEvent>(_onLogin);
    on<SignupEvent>(_onSignup);
    on<LogoutEvent>(_onLogout);
  }

  final LoginUseCase _loginUseCase;
  final SignupUseCase _signupUseCase;
  final LogoutUseCase _logoutUseCase;

  Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result = await _loginUseCase(event.email, event.password);
    _emitResult(result, emit);
  }

  Future<void> _onSignup(SignupEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result =
        await _signupUseCase(event.email, event.password, event.role.name);
    _emitResult(result, emit);
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    await _logoutUseCase();
    emit(const AuthInitial());
  }

  void _emitResult(Result<UserEntity> result, Emitter<AuthState> emit) {
    switch (result) {
      case Success(:final data):
        emit(AuthSuccess(data));
      case Failure(:final failure):
        emit(AuthFailure(AppFailureMessage.resolve(failure)));
    }
  }
}
