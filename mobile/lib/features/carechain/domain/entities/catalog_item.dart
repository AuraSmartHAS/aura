/// Accessibility product from the catalog (aura-server `CatalogItem`).
class CatalogItem {
  const CatalogItem({
    required this.sku,
    required this.name,
    required this.category,
    required this.price,
    required this.installable,
    required this.normRef,
    required this.riskTag,
    required this.stockNearby,
  });

  final String sku;
  final String name;
  final String category;
  final double price;
  final bool installable;
  final String normRef;
  final String riskTag;
  final int stockNearby;

  factory CatalogItem.fromJson(Map<String, dynamic> json) {
    return CatalogItem(
      sku: json['sku'] as String,
      name: (json['name'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      installable: (json['installable'] as bool?) ?? false,
      normRef: (json['normRef'] as String?) ?? 'NBR 9050',
      riskTag: (json['riskTag'] as String?) ?? '',
      stockNearby: (json['stockNearby'] as num?)?.toInt() ?? 0,
    );
  }
}
