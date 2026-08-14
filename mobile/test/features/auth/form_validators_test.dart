import 'package:aura/features/auth/presentation/form_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateEmail', () {
    test('vazio ou nulo pede o e-mail', () {
      expect(validateEmail(null), 'Digite seu e-mail.');
      expect(validateEmail(''), 'Digite seu e-mail.');
      expect(validateEmail('   '), 'Digite seu e-mail.');
    });

    test('formato inválido é rejeitado com mensagem amigável', () {
      expect(validateEmail('ana'), isNotNull);
      expect(validateEmail('ana@'), isNotNull);
      expect(validateEmail('ana@aura'), isNotNull);
      expect(validateEmail('@aura.app'), isNotNull);
    });

    test('e-mail válido passa (com ou sem espaços nas pontas)', () {
      expect(validateEmail('ana.demo@aura.app'), isNull);
      expect(validateEmail('  ana.demo@aura.app  '), isNull);
    });
  });

  group('validateLoginPassword', () {
    test('vazio pede a senha; qualquer valor passa', () {
      expect(validateLoginPassword(null), 'Digite sua senha.');
      expect(validateLoginPassword(''), 'Digite sua senha.');
      expect(validateLoginPassword('abc'), isNull);
    });
  });

  group('validateSignupPassword', () {
    test('vazio pede a senha', () {
      expect(validateSignupPassword(null), 'Crie uma senha.');
      expect(validateSignupPassword(''), 'Crie uma senha.');
    });

    test('curta demais orienta o mínimo', () {
      expect(
        validateSignupPassword('12345'),
        'Use pelo menos $kMinPasswordLength caracteres.',
      );
    });

    test('senha com o mínimo passa', () {
      expect(validateSignupPassword('123456'), isNull);
    });
  });

  group('validatePasswordConfirmation', () {
    test('vazio pede a confirmação', () {
      expect(validatePasswordConfirmation(null, 'x'), 'Confirme sua senha.');
      expect(validatePasswordConfirmation('', 'x'), 'Confirme sua senha.');
    });

    test('diferente da senha avisa em linguagem simples', () {
      expect(
        validatePasswordConfirmation('abc123', 'abc124'),
        'As senhas não são iguais.',
      );
    });

    test('igual à senha passa', () {
      expect(validatePasswordConfirmation('abc123', 'abc123'), isNull);
    });
  });
}
