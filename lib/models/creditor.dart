enum CreditorStatus { open, partial, paid, writtenOff }

String creditorStatusToStr(CreditorStatus s) {
  switch (s) {
    case CreditorStatus.open:
      return 'open';
    case CreditorStatus.partial:
      return 'partial';
    case CreditorStatus.paid:
      return 'paid';
    case CreditorStatus.writtenOff:
      return 'written_off';
  }
}

CreditorStatus creditorStatusFromStr(String s) {
  switch (s) {
    case 'open':
      return CreditorStatus.open;
    case 'partial':
      return CreditorStatus.partial;
    case 'paid':
      return CreditorStatus.paid;
    case 'written_off':
      return CreditorStatus.writtenOff;
    default:
      return CreditorStatus.open;
  }
}

/// A running-tab customer credit account (blueprint section 6).
/// `status` flips to writtenOff ONLY when amount_owed reaches zero
/// specifically because a write-off closed it out — a partial write-off
/// that still leaves a balance keeps the creditor open/partial.
class Creditor {
  final int? id;
  final String name;
  final String? phone;
  final double amountOwed;
  final CreditorStatus status;
  final DateTime createdAt;

  Creditor({
    this.id,
    required this.name,
    this.phone,
    this.amountOwed = 0,
    this.status = CreditorStatus.open,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Creditor copyWith({
    double? amountOwed,
    CreditorStatus? status,
  }) {
    return Creditor(
      id: id,
      name: name,
      phone: phone,
      amountOwed: amountOwed ?? this.amountOwed,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'amount_owed': amountOwed,
        'status': creditorStatusToStr(status),
        'created_at': createdAt.toIso8601String(),
      };

  factory Creditor.fromMap(Map<String, dynamic> m) => Creditor(
        id: m['id'] as int?,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        amountOwed: (m['amount_owed'] as num).toDouble(),
        status: creditorStatusFromStr(m['status'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
