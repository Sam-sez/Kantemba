enum ExpenseCategory { rent, transport, airtime, other }

String expenseCategoryToStr(ExpenseCategory c) => c.name;

ExpenseCategory expenseCategoryFromStr(String s) =>
    ExpenseCategory.values.firstWhere((c) => c.name == s, orElse: () => ExpenseCategory.other);

String expenseCategoryLabel(ExpenseCategory c) {
  switch (c) {
    case ExpenseCategory.rent:
      return 'Rent';
    case ExpenseCategory.transport:
      return 'Transport';
    case ExpenseCategory.airtime:
      return 'Airtime';
    case ExpenseCategory.other:
      return 'Other';
  }
}

class Expense {
  final int? id;
  final DateTime timestamp;
  final ExpenseCategory category;
  final double amount;
  final String? note;

  Expense({
    this.id,
    DateTime? timestamp,
    required this.category,
    required this.amount,
    this.note,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'category': expenseCategoryToStr(category),
        'amount': amount,
        'note': note,
      };

  factory Expense.fromMap(Map<String, dynamic> m) => Expense(
        id: m['id'] as int?,
        timestamp: DateTime.parse(m['timestamp'] as String),
        category: expenseCategoryFromStr(m['category'] as String),
        amount: (m['amount'] as num).toDouble(),
        note: m['note'] as String?,
      );
}
