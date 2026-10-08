/// Primeiro nome para cumprimentar o usuário, a partir do `name` de
/// `GET /auth/me`, ou `null` quando não há um nome de pessoa utilizável.
///
/// O cadastro do app não pede nome, então o campo pode vir vazio, igual ao
/// e-mail ou com um rótulo genérico ("Equipe Aura", "Usuário"). Nesses casos a
/// tela cumprimenta sem nome: inventar um ("Ana") faz a pessoa achar que entrou
/// na conta de outra.
///
/// O seed anota o papel entre parênteses ("Ana (cuidadora)"): o parêntese sai e
/// fica só a primeira palavra.
String? greetingFirstName(String? fullName) {
  if (fullName == null) return null;
  final withoutNote = fullName.replaceAll(RegExp(r'\([^)]*\)'), ' ').trim();
  if (withoutNote.isEmpty || withoutNote.contains('@')) return null;

  final first = withoutNote.split(RegExp(r'\s+')).first;
  // Precisa ter letra: "123" ou "-" não é nome.
  if (!RegExp(r'\p{L}', unicode: true).hasMatch(first)) return null;
  if (_genericWords.contains(first.toLowerCase())) return null;
  return first;
}

/// Primeiras palavras que descrevem um papel ou uma conta, não uma pessoa.
const Set<String> _genericWords = {
  'admin',
  'administrador',
  'administradora',
  'aura',
  'conta',
  'cuidador',
  'cuidadora',
  'equipe',
  'null',
  'paciente',
  'teste',
  'test',
  'user',
  'usuario',
  'usuário',
  'usuária',
  'usuaria',
};
