class Business {
  final int id;
  final String businessName;
  final String ownerName;
  final String? phone;
  final DateTime createdAt;
  final int lowStockThresholdDefault;
  final bool notifyLowStock;

  Business({
    this.id = 1,
    required this.businessName,
    required this.ownerName,
    this.phone,
    DateTime? createdAt,
    this.lowStockThresholdDefault = 5,
    this.notifyLowStock = true,
  }) : createdAt = createdAt ?? DateTime.now();

  Business copyWith({
    String? businessName,
    String? ownerName,
    String? phone,
    int? lowStockThresholdDefault,
    bool? notifyLowStock,
  }) {
    return Business(
      id: id,
      businessName: businessName ?? this.businessName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      createdAt: createdAt,
      lowStockThresholdDefault: lowStockThresholdDefault ?? this.lowStockThresholdDefault,
      notifyLowStock: notifyLowStock ?? this.notifyLowStock,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'business_name': businessName,
        'owner_name': ownerName,
        'phone': phone,
        'created_at': createdAt.toIso8601String(),
        'low_stock_threshold_default': lowStockThresholdDefault,
        'notify_low_stock': notifyLowStock ? 1 : 0,
      };

  factory Business.fromMap(Map<String, dynamic> m) => Business(
        id: m['id'] as int,
        businessName: m['business_name'] as String,
        ownerName: m['owner_name'] as String,
        phone: m['phone'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        lowStockThresholdDefault: m['low_stock_threshold_default'] as int,
        notifyLowStock: (m['notify_low_stock'] as int) == 1,
      );
}
