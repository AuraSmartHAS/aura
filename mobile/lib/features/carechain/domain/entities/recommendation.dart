import 'package:aura/shared/models/severity_level.dart';

/// Explainable recommendation (`POST /recommendations`).
///
/// Desde a correção C1 o preço, a condição da instalação, a norma e os fatores
/// em português viajam no próprio payload da recomendação: nenhuma tela precisa
/// de uma segunda chamada ao catálogo que pode falhar — e ninguém aprova sem
/// saber o total.
class Recommendation {
  const Recommendation({
    required this.recommendationId,
    required this.sku,
    required this.productName,
    required this.price,
    required this.reason,
    required this.normRef,
    required this.factors,
    required this.weights,
    required this.level,
    this.status = 'recommended',
    this.factorLabels = const [],
    this.installable,
    this.installationIncluded,
    this.installationPrice,
  });

  final String recommendationId;
  final String sku;
  final String productName;

  /// Preço do item. Nulo quando o SKU saiu do catálogo — e aí a aprovação fica
  /// bloqueada, porque a jornada de dinheiro não tem preço opcional (CR-5).
  final double? price;

  final String reason;
  final String normRef;

  /// Códigos dos fatores (`near_fall_reported`, …). Nunca vão para a tela crus:
  /// use [factorDisplayLabels].
  final List<String> factors;
  final List<double> weights;
  final SeverityLevel level;

  /// `recommended` enquanto nenhum pedido existe; `approved`/`rejected` depois.
  final String status;

  /// Os mesmos [factors] em português, na mesma ordem e com o mesmo tamanho.
  final List<String> factorLabels;

  /// O item é instalado por técnico da rede parceira.
  final bool? installable;

  /// Instalação já embutida no preço do item.
  final bool? installationIncluded;

  /// Quanto se paga a mais pela instalação; zero (ou nulo) quando inclusa.
  final double? installationPrice;

  /// Enquanto verdadeiro, nenhum pedido nasceu desta recomendação (RN-022).
  bool get isPending => status == 'recommended';

  /// Sem preço não há aprovação: o botão fica desabilitado com explicação.
  bool get hasPrice => price != null;

  bool get needsInstallation => installable == true;

  bool get isInstallationIncluded => installationIncluded == true;

  /// Custo da instalação a somar ao item.
  ///
  /// Instalação inclusa vale zero **mesmo que venha com valor**: o servidor já
  /// manda 0 nesse caso, mas somar um `installationPrice` residual cobraria a
  /// instalação duas vezes na tela.
  double get installationCost {
    if (!needsInstallation || isInstallationIncluded) return 0;
    return installationPrice ?? 0;
  }

  /// O que a cuidadora vai pagar. Nulo quando o preço não carregou.
  double? get total => price == null ? null : price! + installationCost;

  /// Fatores prontos para a tela: o rótulo em português quando o servidor
  /// mandou, e o código apenas como último recurso.
  List<String> get factorDisplayLabels => [
        for (var i = 0; i < factors.length; i++)
          i < factorLabels.length && factorLabels[i].trim().isNotEmpty
              ? factorLabels[i]
              : factors[i].replaceAll('_', ' '),
      ];
}
