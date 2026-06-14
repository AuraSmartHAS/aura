part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginEvent extends AuthEvent {
  const LoginEvent(this.email, this.password);

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

class SignupEvent extends AuthEvent {
  const SignupEvent(this.email, this.password, this.role);

  final String email;
  final String password;
  final UserRole role;

  @override
  List<Object?> get props => [email, password, role];
}

class LogoutEvent extends AuthEvent {
  const LogoutEvent();
}
