import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/signup_usecase.dart';
import 'package:aura/core/errors/result.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase _loginUseCase;
  final SignupUseCase _signupUseCase;
  final LogoutUseCase _logoutUseCase;

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

  Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result = await _loginUseCase(event.email, event.password);
    if (result is Success<UserEntity>) {
      emit(AuthSuccess((result as Success<UserEntity>).data));
    } else if (result is Failure<UserEntity>) {
      emit(AuthFailure((result as Failure<UserEntity>).failure.toString()));
    }
  }

  Future<void> _onSignup(SignupEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result = await _signupUseCase(event.email, event.password);
    if (result is Success<UserEntity>) {
      emit(AuthSuccess((result as Success<UserEntity>).data));
    } else if (result is Failure<UserEntity>) {
      emit(AuthFailure((result as Failure<UserEntity>).failure.toString()));
    }
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AuthState> emit) async {
    emit(const AuthLoading());
    final result = await _logoutUseCase();
    if (result is Success<void>) {
      emit(const AuthInitial());
    } else if (result is Failure<void>) {
      emit(AuthFailure((result as Failure<void>).failure.toString()));
    }
  }
}
