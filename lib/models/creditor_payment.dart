/// Reduces amount_owed. Recorded as a Cash Book receipt — its own bucket,
/// separate from Sales, so debt collection never counts as new revenue.
class CreditorPayment {
  final int? id;
  final int creditorId;
  final double amount;
  final DateTime timestamp;

  CreditorPayment({
    this.id,
    required this.creditorId,
    required this.amount,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'creditor_id': creditorId,
        'amount': amount,
        'timestamp': timestamp.toIso8601String(),
      };

  factory CreditorPayment.fromMap(Map<String, dynamic> m) => CreditorPayment(
        id: m['id'] as int?,
        creditorId: m['creditor_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        timestamp: DateTime.parse(m['timestamp'] as String),
      );
}
