import '../domain/entities/recommendation.dart';

/// Textos e valores da aprovação, num lugar só.
///
/// Correção C5: a cuidadora precisa saber **quanto** paga, **quem** entra na
/// casa e **como** volta atrás antes de apertar o botão. Centralizar a cópia
/// mantém a mesma frase no card, na folha de confirmação e nos testes.
class ApprovalCopy {
  const ApprovalCopy._();

  /// Placeholder visível: o número real do atendimento entra quando existir.
  /// Prometer um canal que não existe seria pior do que declarar o placeholder.
  static const String supportPhone = '(11) 0000-0000';

  /// Não há rota de cancelamento no servidor (decisão registrada no plano):
  /// em vez de desenhar um botão que mentiria, a folha mostra o caminho humano.
  static const String changedMind =
      'Mudou de ideia? Fale com a gente pelo $supportPhone até o pedido sair '
      'para entrega.';

  static const String priceUnavailableTitle = 'O preço não carregou';

  static const String priceUnavailableMessage =
      'Não conseguimos trazer o valor deste item agora. A gente não deixa você '
      'aprovar uma compra sem ver quanto custa.';

  static const String approveBlockedWithoutPrice =
      'Aprovação bloqueada até o preço carregar.';

  static const String payer =
      'Você paga. A compra fica no seu nome — a pessoa que você cuida não '
      'recebe cobrança.';

  static const String noInstallation =
      'Sem instalação: o item chega pronto para usar.';

  static const String installationTitle = 'Quem entra na casa';

  static const String priceTitle = 'Quanto custa';

  /// Responde o que uma pessoa real pergunta antes de deixar um estranho entrar
  /// na casa de uma idosa que mora sozinha. No Brasil o golpe do falso técnico
  /// contra idoso é comum o bastante para isto ser requisito, não gentileza.
  static String installationNotice(String? patientName) {
    final name = patientName?.trim();
    final where = (name == null || name.isEmpty)
        ? 'até a casa'
        : 'à casa da ${_firstName(name)}';
    return 'Um técnico da rede parceira vai $where instalar. Você escolhe o '
        'dia e pode estar presente. Antes da visita você recebe o nome e a '
        'foto dele, e ele se identifica na porta.';
  }

  /// "Total R$ 279,80 — item R$ 129,90 + instalação R$ 149,90", ou a versão
  /// com instalação inclusa. Nulo quando não há preço: aí a tela mostra o
  /// bloco de preço indisponível, nunca um total inventado.
  static String? totalLine(Recommendation reco) {
    final total = reco.total;
    if (total == null) return null;
    final totalText = 'Total ${formatBrl(total)}';
    if (!reco.needsInstallation) return totalText;
    if (reco.isInstallationIncluded) {
      return '$totalText — instalação incluída no valor';
    }
    return '$totalText — item ${formatBrl(reco.price!)} + instalação '
        '${formatBrl(reco.installationCost)}';
  }

  /// Rótulo curto do total para o cabeçalho do card.
  static String? priceLabel(Recommendation reco) {
    final total = reco.total;
    return total == null ? null : formatBrl(total);
  }

  static String orderSummaryAddress(String? patientName, String? address) {
    final name = patientName?.trim();
    final who = (name == null || name.isEmpty)
        ? 'na casa cadastrada'
        : 'na casa da ${_firstName(name)}';
    final where = address?.trim();
    if (where == null || where.isEmpty) {
      return 'Entrega $who. O endereço não carregou agora — confira antes de '
          'confirmar.';
    }
    return 'Entrega $who — $where.';
  }

  static String _firstName(String name) => name.split(' ').first;

  /// Reais em português: "R$ 1.279,90". Escrito à mão de propósito — o valor
  /// aparece em texto que os testes comparam, e o separador do `intl` para
  /// pt-BR é um espaço não separável que ninguém digita.
  static String formatBrl(double value) {
    final negative = value < 0;
    final fixed = value.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final digits = parts[0];
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
      grouped.write(digits[i]);
    }
    return '${negative ? '-' : ''}R\$ $grouped,${parts[1]}';
  }
}
