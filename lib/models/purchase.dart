class Purchase {
  final int? id;
  final DateTime timestamp;
  final double totalAmount;
  final String? supplier;

  Purchase({
    this.id,
    DateTime? timestamp,
    required this.totalAmount,
    this.supplier,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'total_amount': totalAmount,
        'supplier': supplier,
      };

  factory Purchase.fromMap(Map<String, dynamic> m) => Purchase(
        id: m['id'] as int?,
        timestamp: DateTime.parse(m['timestamp'] as String),
        totalAmount: (m['total_amount'] as num).toDouble(),
        supplier: m['supplier'] as String?,
      );
}
