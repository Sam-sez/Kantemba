/// Reduces amount_owed like a payment, but no cash moved — excluded from
/// the Cash Book. Recognized as a bad-debt expense in Charts' Profit calc:
/// Profit = Revenue − Cost of goods − Expenses − Write-offs.
class CreditorWriteOff {
  final int? id;
  final int creditorId;
  final double amount;
  final DateTime timestamp;
  final String? note;

  CreditorWriteOff({
    this.id,
    required this.creditorId,
    required this.amount,
    DateTime? timestamp,
    this.note,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'creditor_id': creditorId,
        'amount': amount,
        'timestamp': timestamp.toIso8601String(),
        'note': note,
      };

  factory CreditorWriteOff.fromMap(Map<String, dynamic> m) => CreditorWriteOff(
        id: m['id'] as int?,
        creditorId: m['creditor_id'] as int,
        amount: (m['amount'] as num).toDouble(),
        timestamp: DateTime.parse(m['timestamp'] as String),
        note: m['note'] as String?,
      );
}
