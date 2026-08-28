import 'package:url_launcher/url_launcher.dart';

/// Abre o discador do aparelho com um número já digitado.
///
/// Correção C3, decisão D19: **quem liga é uma pessoa, não o app.** Discar
/// sozinho para o SAMU — sem localização verificada, sem integração de despacho
/// e sem plantão — seria irresponsável. Então o contrato desta classe é abrir o
/// discador e parar ali: o último toque é sempre humano.
///
/// É abstrata porque o teste do SOS precisa afirmar *qual* número a tela
/// ofereceu sem abrir aplicativo nenhum.
abstract class PhoneDialer {
  /// Abre o discador com [phoneNumber] preenchido. Devolve `false` quando não
  /// há número para discar ou o aparelho não tem discador.
  Future<bool> openDialer(String phoneNumber);
}

/// Implementação real, sobre `url_launcher` e o esquema `tel:`.
class UrlLauncherPhoneDialer implements PhoneDialer {
  const UrlLauncherPhoneDialer();

  @override
  Future<bool> openDialer(String phoneNumber) async {
    // O número pode vir do `.env` com máscara ("(11) 99999-0000"). O `tel:` só
    // aceita dígitos e o `+` do código do país.
    final digits = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return false;

    try {
      // `launchUrl` com `tel:` abre a tela do discador com o número posto —
      // nunca inicia a chamada.
      return await launchUrl(Uri(scheme: 'tel', path: digits));
    } catch (_) {
      // Aparelho sem discador (tablet Wi-Fi, emulador): a tela precisa saber
      // que a ligação não abriu para continuar oferecendo o outro caminho.
      return false;
    }
  }
}
