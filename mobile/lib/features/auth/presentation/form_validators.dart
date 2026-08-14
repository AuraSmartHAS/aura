/// Validadores dos formulários de autenticação.
///
/// Funções puras para uso no `validator` de um `TextFormField`: retornam `null`
/// quando o valor é válido, ou a mensagem (em linguagem simples, WCAG)
/// a exibir junto ao campo. A validação acontece antes de qualquer
/// chamada à API — erro técnico do servidor nunca é a primeira resposta
/// que a pessoa vê.
library;

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Tamanho mínimo de senha exigido no cadastro.
const int kMinPasswordLength = 6;

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Digite seu e-mail.';
  if (!_emailPattern.hasMatch(email)) {
    return 'E-mail inválido. Confira e tente de novo.';
  }
  return null;
}

/// Senha no login: apenas obrigatória (contas antigas podem ter regras antigas).
String? validateLoginPassword(String? value) {
  if (value == null || value.isEmpty) return 'Digite sua senha.';
  return null;
}

/// Senha no cadastro: obrigatória e com tamanho mínimo.
String? validateSignupPassword(String? value) {
  if (value == null || value.isEmpty) return 'Crie uma senha.';
  if (value.length < kMinPasswordLength) {
    return 'Use pelo menos $kMinPasswordLength caracteres.';
  }
  return null;
}

/// Confirmação: obrigatória e igual à senha escolhida.
String? validatePasswordConfirmation(String? value, String original) {
  if (value == null || value.isEmpty) return 'Confirme sua senha.';
  if (value != original) return 'As senhas não são iguais.';
  return null;
}
