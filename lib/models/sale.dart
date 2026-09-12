enum PaymentMethod { cash, airtelMoney, mtnMomo, credit }

String paymentMethodToStr(PaymentMethod m) {
  switch (m) {
    case PaymentMethod.cash:
      return 'cash';
    case PaymentMethod.airtelMoney:
      return 'airtel_money';
    case PaymentMethod.mtnMomo:
      return 'mtn_momo';
    case PaymentMethod.credit:
      return 'credit';
  }
}

PaymentMethod paymentMethodFromStr(String s) {
  switch (s) {
    case 'cash':
      return PaymentMethod.cash;
    case 'airtel_money':
      return PaymentMethod.airtelMoney;
    case 'mtn_momo':
      return PaymentMethod.mtnMomo;
    case 'credit':
      return PaymentMethod.credit;
    default:
      return PaymentMethod.cash;
  }
}

String paymentMethodLabel(PaymentMethod m) {
  switch (m) {
    case PaymentMethod.cash:
      return 'Cash';
    case PaymentMethod.airtelMoney:
      return 'Airtel Money';
    case PaymentMethod.mtnMomo:
      return 'MTN MoMo';
    case PaymentMethod.credit:
      return 'Credit';
  }
}

class Sale {
  final int? id;
  final DateTime timestamp;
  final double totalAmount;
  final double amountReceived;
  final double changeGiven;
  final PaymentMethod paymentMethod;
  final int? creditorId;

  Sale({
    this.id,
    DateTime? timestamp,
    required this.totalAmount,
    this.amountReceived = 0,
    this.changeGiven = 0,
    required this.paymentMethod,
    this.creditorId,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isCredit => paymentMethod == PaymentMethod.credit;

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'total_amount': totalAmount,
        'amount_received': amountReceived,
        'change_given': changeGiven,
        'payment_method': paymentMethodToStr(paymentMethod),
        'creditor_id': creditorId,
      };

  factory Sale.fromMap(Map<String, dynamic> m) => Sale(
        id: m['id'] as int?,
        timestamp: DateTime.parse(m['timestamp'] as String),
        totalAmount: (m['total_amount'] as num).toDouble(),
        amountReceived: (m['amount_received'] as num).toDouble(),
        changeGiven: (m['change_given'] as num).toDouble(),
        paymentMethod: paymentMethodFromStr(m['payment_method'] as String),
        creditorId: m['creditor_id'] as int?,
      );
}
