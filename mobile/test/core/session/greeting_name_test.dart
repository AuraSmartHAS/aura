import 'package:aura/core/session/greeting_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('greetingFirstName', () {
    test('nome composto do seed: "Ana (cuidadora)" vira "Ana"', () {
      expect(greetingFirstName('Ana (cuidadora)'), 'Ana');
    });

    test('nome e sobrenome: fica o primeiro', () {
      expect(greetingFirstName('  Beatriz   Teste '), 'Beatriz');
      expect(greetingFirstName('Antônio R. (paciente)'), 'Antônio');
    });

    test('vazio, nulo ou só espaços: sem nome', () {
      expect(greetingFirstName(null), isNull);
      expect(greetingFirstName(''), isNull);
      expect(greetingFirstName('   '), isNull);
      expect(greetingFirstName('(cuidadora)'), isNull);
    });

    test('rótulo genérico ou inutilizável: sem nome', () {
      expect(greetingFirstName('Equipe Aura'), isNull);
      expect(greetingFirstName('Usuário'), isNull);
      expect(greetingFirstName('cuidadora'), isNull);
      expect(greetingFirstName('beatriz@exemplo.com'), isNull);
      expect(greetingFirstName('123'), isNull);
    });
  });
}
