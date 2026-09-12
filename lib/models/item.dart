class Item {
  final int? id;
  final String name;
  final String? barcode;
  final double costPrice;
  final double sellPrice;
  final int stockQty;
  final int lowStockThreshold;
  final int usageCount;
  final DateTime createdAt;

  Item({
    this.id,
    required this.name,
    this.barcode,
    required this.costPrice,
    required this.sellPrice,
    required this.stockQty,
    this.lowStockThreshold = 5,
    this.usageCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isLowStock => stockQty <= lowStockThreshold;

  Item copyWith({
    int? id,
    String? name,
    String? barcode,
    double? costPrice,
    double? sellPrice,
    int? stockQty,
    int? lowStockThreshold,
    int? usageCount,
    DateTime? createdAt,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      barcode: barcode ?? this.barcode,
      costPrice: costPrice ?? this.costPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      stockQty: stockQty ?? this.stockQty,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'barcode': barcode,
        'cost_price': costPrice,
        'sell_price': sellPrice,
        'stock_qty': stockQty,
        'low_stock_threshold': lowStockThreshold,
        'usage_count': usageCount,
        'created_at': createdAt.toIso8601String(),
      };

  factory Item.fromMap(Map<String, dynamic> m) => Item(
        id: m['id'] as int?,
        name: m['name'] as String,
        barcode: m['barcode'] as String?,
        costPrice: (m['cost_price'] as num).toDouble(),
        sellPrice: (m['sell_price'] as num).toDouble(),
        stockQty: m['stock_qty'] as int,
        lowStockThreshold: m['low_stock_threshold'] as int,
        usageCount: m['usage_count'] as int,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
