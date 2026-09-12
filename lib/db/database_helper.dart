import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/item.dart';
import '../models/sale.dart';
import '../models/sale_line_item.dart';
import '../models/purchase.dart';
import '../models/purchase_line_item.dart';
import '../models/expense.dart';
import '../models/creditor.dart';
import '../models/creditor_payment.dart';
import '../models/creditor_write_off.dart';
import '../models/business.dart';

/// A single row for display in the Cash Book — computed, not persisted.
/// Convention: Dr = receipts (cash in: Sales, Creditor Payments).
///             Cr = payments (cash out: Purchases, Expenses).
class CashBookEntry {
  final DateTime timestamp;
  final String type; // sale | purchase | expense | creditor_payment
  final String details;
  final double dr;
  final double cr;
  double runningBalance = 0;

  CashBookEntry({
    required this.timestamp,
    required this.type,
    required this.details,
    this.dr = 0,
    this.cr = 0,
  });
}

/// A single row for the Dashboard / Profile "Recent Activity" feeds.
class ActivityEntry {
  final DateTime timestamp;
  final String type; // sale | purchase | expense | creditor_payment
  final String label;
  final String detail;
  final double amount;
  final bool isOutflow;

  ActivityEntry({
    required this.timestamp,
    required this.type,
    required this.label,
    required this.detail,
    required this.amount,
    this.isOutflow = false,
  });
}

/// One entry in a creditor's mini-statement.
class CreditorTimelineEntry {
  final DateTime timestamp;
  final String type; // credit_sale | payment | write_off
  final double amount;
  final String detail;

  CreditorTimelineEntry({
    required this.timestamp,
    required this.type,
    required this.amount,
    required this.detail,
  });
}

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'kantemba.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        barcode TEXT,
        cost_price REAL NOT NULL,
        sell_price REAL NOT NULL,
        stock_qty INTEGER NOT NULL,
        low_stock_threshold INTEGER NOT NULL,
        usage_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        total_amount REAL NOT NULL,
        amount_received REAL NOT NULL,
        change_given REAL NOT NULL,
        payment_method TEXT NOT NULL,
        creditor_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_line_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price_at_sale REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        total_amount REAL NOT NULL,
        supplier TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_line_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_cost_at_purchase REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE creditors (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        amount_owed REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'open',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE creditor_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        creditor_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE creditor_write_offs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        creditor_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        timestamp TEXT NOT NULL,
        note TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE business (
        id INTEGER PRIMARY KEY,
        business_name TEXT NOT NULL,
        owner_name TEXT NOT NULL,
        phone TEXT,
        created_at TEXT NOT NULL,
        low_stock_threshold_default INTEGER NOT NULL DEFAULT 5,
        notify_low_stock INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.insert('business', {
      'id': 1,
      'business_name': 'My Shop',
      'owner_name': 'Owner',
      'phone': null,
      'created_at': DateTime.now().toIso8601String(),
      'low_stock_threshold_default': 5,
      'notify_low_stock': 1,
    });
  }

  // ==================== ITEMS ====================

  Future<int> insertItem(Item item) async {
    final db = await database;
    return db.insert('items', item.toMap()..remove('id'));
  }

  Future<void> updateItem(Item item) async {
    final db = await database;
    await db.update('items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<List<Item>> getItems({String? query}) async {
    final db = await database;
    List<Map<String, dynamic>> rows;
    if (query != null && query.trim().isNotEmpty) {
      rows = await db.query(
        'items',
        where: 'name LIKE ? OR barcode LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'name COLLATE NOCASE ASC',
      );
    } else {
      rows = await db.query('items', orderBy: 'name COLLATE NOCASE ASC');
    }
    return rows.map((m) => Item.fromMap(m)).toList();
  }

  Future<Item?> getItemById(int id) async {
    final db = await database;
    final rows = await db.query('items', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Item.fromMap(rows.first);
  }

  Future<Item?> getItemByBarcode(String barcode) async {
    final db = await database;
    final rows = await db.query('items', where: 'barcode = ?', whereArgs: [barcode]);
    if (rows.isEmpty) return null;
    return Item.fromMap(rows.first);
  }

  Future<List<Item>> getFrequentItems({int limit = 10}) async {
    final db = await database;
    final rows = await db.query(
      'items',
      where: 'usage_count > 0',
      orderBy: 'usage_count DESC',
      limit: limit,
    );
    return rows.map((m) => Item.fromMap(m)).toList();
  }

  Future<List<Item>> getLowStockItems() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT * FROM items WHERE stock_qty <= low_stock_threshold ORDER BY stock_qty ASC',
    );
    return rows.map((m) => Item.fromMap(m)).toList();
  }

  Future<void> _incrementUsage(Database db, int itemId, {int by = 1}) async {
    await db.rawUpdate(
      'UPDATE items SET usage_count = usage_count + ? WHERE id = ?',
      [by, itemId],
    );
  }

  Future<void> _adjustStock(Database db, int itemId, int delta) async {
    await db.rawUpdate(
      'UPDATE items SET stock_qty = stock_qty + ? WHERE id = ?',
      [delta, itemId],
    );
  }

  // ==================== SALES ====================

  /// Creates a sale (cash / mobile money / credit) with its line items.
  /// Stock reduces and usage_count increments for every line item.
  /// If [creditorId] is set (payment_method = credit), the creditor's
  /// running tab balance increases by the sale total.
  Future<int> createSale({
    required PaymentMethod paymentMethod,
    required List<SaleLineItem> lines,
    double amountReceived = 0,
    double changeGiven = 0,
    int? creditorId,
  }) async {
    final db = await database;
    final total = lines.fold<double>(0, (s, l) => s + l.quantity * l.unitPriceAtSale);

    late int saleId;
    await db.transaction((txn) async {
      saleId = await txn.insert('sales', {
        'timestamp': DateTime.now().toIso8601String(),
        'total_amount': total,
        'amount_received': amountReceived,
        'change_given': changeGiven,
        'payment_method': paymentMethodToStr(paymentMethod),
        'creditor_id': creditorId,
      });

      for (final line in lines) {
        await txn.insert('sale_line_items', {
          'sale_id': saleId,
          'item_id': line.itemId,
          'quantity': line.quantity,
          'unit_price_at_sale': line.unitPriceAtSale,
        });
        await txn.rawUpdate(
          'UPDATE items SET stock_qty = stock_qty - ?, usage_count = usage_count + 1 WHERE id = ?',
          [line.quantity, line.itemId],
        );
      }

      if (paymentMethod == PaymentMethod.credit && creditorId != null) {
        final rows = await txn.query('creditors', where: 'id = ?', whereArgs: [creditorId]);
        final creditor = Creditor.fromMap(rows.first);
        await txn.update(
          'creditors',
          {'amount_owed': creditor.amountOwed + total},
          where: 'id = ?',
          whereArgs: [creditorId],
        );
      }
    });
    return saleId;
  }

  // ==================== PURCHASES ====================

  /// Logs a restock: stock increases, usage_count increments, and each
  /// item's cost_price updates to the price paid this time (last-price
  /// tracking used by the Purchases Frequents pre-fill).
  Future<int> createPurchase({
    required List<PurchaseLineItem> lines,
    String? supplier,
  }) async {
    final db = await database;
    final total = lines.fold<double>(0, (s, l) => s + l.quantity * l.unitCostAtPurchase);

    late int purchaseId;
    await db.transaction((txn) async {
      purchaseId = await txn.insert('purchases', {
        'timestamp': DateTime.now().toIso8601String(),
        'total_amount': total,
        'supplier': supplier,
      });

      for (final line in lines) {
        await txn.insert('purchase_line_items', {
          'purchase_id': purchaseId,
          'item_id': line.itemId,
          'quantity': line.quantity,
          'unit_cost_at_purchase': line.unitCostAtPurchase,
        });
        await txn.rawUpdate(
          'UPDATE items SET stock_qty = stock_qty + ?, usage_count = usage_count + 1, cost_price = ? WHERE id = ?',
          [line.quantity, line.unitCostAtPurchase, line.itemId],
        );
      }
    });
    return purchaseId;
  }

  // ==================== EXPENSES ====================

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return db.insert('expenses', expense.toMap()..remove('id'));
  }

  // ==================== CREDITORS ====================

  Future<List<Creditor>> searchCreditors(String query) async {
    final db = await database;
    final rows = await db.query(
      'creditors',
      where: 'name LIKE ? OR phone LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name COLLATE NOCASE ASC',
      limit: 20,
    );
    return rows.map((m) => Creditor.fromMap(m)).toList();
  }

  Future<int> createCreditor({required String name, String? phone}) async {
    final db = await database;
    return db.insert('creditors', {
      'name': name,
      'phone': phone,
      'amount_owed': 0,
      'status': 'open',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// filter: all | owing | paid | written_off
  Future<List<Creditor>> getCreditors({String filter = 'all'}) async {
    final db = await database;
    List<Map<String, dynamic>> rows;
    if (filter == 'owing') {
      rows = await db.query('creditors', where: "status IN ('open','partial')");
    } else if (filter == 'paid') {
      rows = await db.query('creditors', where: "status = 'paid'");
    } else if (filter == 'written_off') {
      rows = await db.query('creditors', where: "status = 'written_off'");
    } else {
      rows = await db.query('creditors');
    }
    rows.sort((a, b) {
      final ao = (a['amount_owed'] as num).toDouble();
      final bo = (b['amount_owed'] as num).toDouble();
      return bo.compareTo(ao);
    });
    return rows.map((m) => Creditor.fromMap(m)).toList();
  }

  Future<Creditor?> getCreditorById(int id) async {
    final db = await database;
    final rows = await db.query('creditors', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Creditor.fromMap(rows.first);
  }

  Future<double> getTotalOutstandingCredit() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount_owed), 0) as total FROM creditors WHERE status IN ('open','partial')",
    );
    return (result.first['total'] as num).toDouble();
  }

  /// Reduces the balance. Sets status to 'paid'/'written_off' only when
  /// the balance is fully cleared by this action; otherwise the status
  /// (open/partial) is left as-is so the card stays active.
  Future<void> _settleBalance(int creditorId, double amount, {required bool isWriteOff, String? note}) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('creditors', where: 'id = ?', whereArgs: [creditorId]);
      final creditor = Creditor.fromMap(rows.first);
      final newBalance = (creditor.amountOwed - amount).clamp(0, double.infinity).toDouble();

      CreditorStatus newStatus;
      if (newBalance <= 0.005) {
        newStatus = isWriteOff ? CreditorStatus.writtenOff : CreditorStatus.paid;
      } else {
        newStatus = creditor.status == CreditorStatus.open || creditor.status == CreditorStatus.partial
            ? creditor.status
            : CreditorStatus.partial;
      }

      await txn.update(
        'creditors',
        {
          'amount_owed': newBalance,
          'status': creditorStatusToStr(newStatus),
        },
        where: 'id = ?',
        whereArgs: [creditorId],
      );

      if (isWriteOff) {
        await txn.insert('creditor_write_offs', {
          'creditor_id': creditorId,
          'amount': amount,
          'timestamp': DateTime.now().toIso8601String(),
          'note': note,
        });
      } else {
        await txn.insert('creditor_payments', {
          'creditor_id': creditorId,
          'amount': amount,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<void> logCreditorPayment(int creditorId, double amount) =>
      _settleBalance(creditorId, amount, isWriteOff: false);

  Future<void> logCreditorWriteOff(int creditorId, double amount, {String? note}) =>
      _settleBalance(creditorId, amount, isWriteOff: true, note: note);

  /// Full mini-statement for a creditor: credit sales, payments, write-offs,
  /// merged and sorted chronologically (most recent first).
  Future<List<CreditorTimelineEntry>> getCreditorTimeline(int creditorId) async {
    final db = await database;
    final entries = <CreditorTimelineEntry>[];

    final saleRows = await db.query('sales', where: 'creditor_id = ?', whereArgs: [creditorId]);
    for (final s in saleRows) {
      final sale = Sale.fromMap(s);
      final lineRows = await db.query('sale_line_items', where: 'sale_id = ?', whereArgs: [sale.id]);
      final itemNames = <String>[];
      for (final l in lineRows) {
        final item = await getItemById(l['item_id'] as int);
        itemNames.add('${l['quantity']}x ${item?.name ?? 'item'}');
      }
      entries.add(CreditorTimelineEntry(
        timestamp: sale.timestamp,
        type: 'credit_sale',
        amount: sale.totalAmount,
        detail: itemNames.join(', '),
      ));
    }

    final paymentRows = await db.query('creditor_payments', where: 'creditor_id = ?', whereArgs: [creditorId]);
    for (final p in paymentRows) {
      final pay = CreditorPayment.fromMap(p);
      entries.add(CreditorTimelineEntry(
        timestamp: pay.timestamp,
        type: 'payment',
        amount: pay.amount,
        detail: 'Payment received',
      ));
    }

    final writeOffRows = await db.query('creditor_write_offs', where: 'creditor_id = ?', whereArgs: [creditorId]);
    for (final w in writeOffRows) {
      final wo = CreditorWriteOff.fromMap(w);
      entries.add(CreditorTimelineEntry(
        timestamp: wo.timestamp,
        type: 'write_off',
        amount: wo.amount,
        detail: wo.note?.isNotEmpty == true ? wo.note! : 'Written off',
      ));
    }

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  // ==================== CASH BOOK ====================

  /// type filter: all | sales | purchases | expenses | creditor_payments
  Future<List<CashBookEntry>> getCashBookEntries({
    required DateTime start,
    required DateTime end,
    String typeFilter = 'all',
  }) async {
    final db = await database;
    final entries = <CashBookEntry>[];
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();

    if (typeFilter == 'all' || typeFilter == 'sales') {
      final rows = await db.query(
        'sales',
        where: "timestamp >= ? AND timestamp <= ? AND payment_method != 'credit'",
        whereArgs: [startStr, endStr],
      );
      for (final r in rows) {
        final sale = Sale.fromMap(r);
        entries.add(CashBookEntry(
          timestamp: sale.timestamp,
          type: 'sale',
          details: '${paymentMethodLabel(sale.paymentMethod)} sale',
          dr: sale.totalAmount,
        ));
      }
    }

    if (typeFilter == 'all' || typeFilter == 'purchases') {
      final rows = await db.query(
        'purchases',
        where: 'timestamp >= ? AND timestamp <= ?',
        whereArgs: [startStr, endStr],
      );
      for (final r in rows) {
        final p = Purchase.fromMap(r);
        entries.add(CashBookEntry(
          timestamp: p.timestamp,
          type: 'purchase',
          details: p.supplier?.isNotEmpty == true ? 'Purchase — ${p.supplier}' : 'Stock purchase',
          cr: p.totalAmount,
        ));
      }
    }

    if (typeFilter == 'all' || typeFilter == 'expenses') {
      final rows = await db.query(
        'expenses',
        where: 'timestamp >= ? AND timestamp <= ?',
        whereArgs: [startStr, endStr],
      );
      for (final r in rows) {
        final e = Expense.fromMap(r);
        entries.add(CashBookEntry(
          timestamp: e.timestamp,
          type: 'expense',
          details: '${expenseCategoryLabel(e.category)}${e.note?.isNotEmpty == true ? ' — ${e.note}' : ''}',
          cr: e.amount,
        ));
      }
    }

    if (typeFilter == 'all' || typeFilter == 'creditor_payments') {
      final rows = await db.query(
        'creditor_payments',
        where: 'timestamp >= ? AND timestamp <= ?',
        whereArgs: [startStr, endStr],
      );
      for (final r in rows) {
        final p = CreditorPayment.fromMap(r);
        final creditor = await getCreditorById(p.creditorId);
        entries.add(CashBookEntry(
          timestamp: p.timestamp,
          type: 'creditor_payment',
          details: 'Payment received — ${creditor?.name ?? 'Creditor'}',
          dr: p.amount,
        ));
      }
    }

    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    double running = 0;
    for (final e in entries) {
      running += e.dr - e.cr;
      e.runningBalance = running;
    }
    return entries;
  }

  // ==================== DASHBOARD / ACTIVITY ====================

  Future<double> getTodaysSalesTotal() async {
    final db = await database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(total_amount), 0) as total FROM sales WHERE timestamp >= ?',
      [start.toIso8601String()],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getAllTimeSalesTotal() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COALESCE(SUM(total_amount), 0) as total FROM sales');
    return (result.first['total'] as num).toDouble();
  }

  Future<int> getItemsTrackedCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as c FROM items');
    return result.first['c'] as int;
  }

  Future<List<ActivityEntry>> getRecentActivity({int limit = 5}) async {
    final db = await database;
    final entries = <ActivityEntry>[];

    final saleRows = await db.query('sales', orderBy: 'timestamp DESC', limit: limit);
    for (final r in saleRows) {
      final sale = Sale.fromMap(r);
      final lineCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM sale_line_items WHERE sale_id = ?',
        [sale.id],
      ));
      entries.add(ActivityEntry(
        timestamp: sale.timestamp,
        type: sale.isCredit ? 'credit_sale' : 'sale',
        label: sale.isCredit ? 'Credit sale' : '${paymentMethodLabel(sale.paymentMethod)} sale',
        detail: '${lineCount ?? 0} item${(lineCount ?? 0) == 1 ? '' : 's'}',
        amount: sale.totalAmount,
      ));
    }

    final purchaseRows = await db.query('purchases', orderBy: 'timestamp DESC', limit: limit);
    for (final r in purchaseRows) {
      final p = Purchase.fromMap(r);
      entries.add(ActivityEntry(
        timestamp: p.timestamp,
        type: 'purchase',
        label: 'Restock',
        detail: p.supplier ?? 'Purchase',
        amount: p.totalAmount,
        isOutflow: true,
      ));
    }

    final expenseRows = await db.query('expenses', orderBy: 'timestamp DESC', limit: limit);
    for (final r in expenseRows) {
      final e = Expense.fromMap(r);
      entries.add(ActivityEntry(
        timestamp: e.timestamp,
        type: 'expense',
        label: expenseCategoryLabel(e.category),
        detail: 'Expense',
        amount: e.amount,
        isOutflow: true,
      ));
    }

    final paymentRows = await db.query('creditor_payments', orderBy: 'timestamp DESC', limit: limit);
    for (final r in paymentRows) {
      final p = CreditorPayment.fromMap(r);
      final creditor = await getCreditorById(p.creditorId);
      entries.add(ActivityEntry(
        timestamp: p.timestamp,
        type: 'creditor_payment',
        label: 'Payment received',
        detail: creditor?.name ?? 'Creditor',
        amount: p.amount,
      ));
    }

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries.take(limit).toList();
  }

  // ==================== CHARTS ====================

  /// Aggregated figures for the Charts screen over [start, end).
  /// type: all | sales | purchases | expenses (mirrors the segmented control;
  /// "all" uses revenue as the headline metric, per blueprint).
  Future<ChartAggregate> getChartAggregate({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await database;
    final startStr = start.toIso8601String();
    final endStr = end.toIso8601String();

    final salesRows = await db.query('sales', where: 'timestamp >= ? AND timestamp <= ?', whereArgs: [startStr, endStr]);
    final purchaseRows = await db.query('purchases', where: 'timestamp >= ? AND timestamp <= ?', whereArgs: [startStr, endStr]);
    final expenseRows = await db.query('expenses', where: 'timestamp >= ? AND timestamp <= ?', whereArgs: [startStr, endStr]);
    final writeOffRows = await db.query('creditor_write_offs', where: 'timestamp >= ? AND timestamp <= ?', whereArgs: [startStr, endStr]);

    double revenue = 0;
    double cogs = 0;
    final Map<int, _ProductAgg> productAgg = {};
    final Map<String, double> dailyRevenue = {};

    for (final r in salesRows) {
      final sale = Sale.fromMap(r);
      revenue += sale.totalAmount;
      final dayKey = _dayKey(sale.timestamp);
      dailyRevenue[dayKey] = (dailyRevenue[dayKey] ?? 0) + sale.totalAmount;

      final lineRows = await db.query('sale_line_items', where: 'sale_id = ?', whereArgs: [sale.id]);
      for (final l in lineRows) {
        final itemId = l['item_id'] as int;
        final qty = l['quantity'] as int;
        final unitPrice = (l['unit_price_at_sale'] as num).toDouble();
        final item = await getItemById(itemId);
        final cost = (item?.costPrice ?? 0) * qty;
        cogs += cost;
        final agg = productAgg.putIfAbsent(itemId, () => _ProductAgg(name: item?.name ?? 'Item'));
        agg.units += qty;
        agg.revenue += unitPrice * qty;
      }
    }

    double purchasesTotal = 0;
    final Map<String, double> dailyPurchases = {};
    for (final r in purchaseRows) {
      final p = Purchase.fromMap(r);
      purchasesTotal += p.totalAmount;
      final dayKey = _dayKey(p.timestamp);
      dailyPurchases[dayKey] = (dailyPurchases[dayKey] ?? 0) + p.totalAmount;
    }

    double expensesTotal = 0;
    final Map<String, double> dailyExpenses = {};
    for (final r in expenseRows) {
      final e = Expense.fromMap(r);
      expensesTotal += e.amount;
      final dayKey = _dayKey(e.timestamp);
      dailyExpenses[dayKey] = (dailyExpenses[dayKey] ?? 0) + e.amount;
    }

    double writeOffsTotal = 0;
    for (final r in writeOffRows) {
      writeOffsTotal += (r['amount'] as num).toDouble();
    }

    final profit = revenue - cogs - expensesTotal - writeOffsTotal;
    final salesCount = salesRows.length;
    final avgSaleValue = salesCount > 0 ? revenue / salesCount : 0.0;

    String? bestDayKey;
    double bestDayValue = -1;
    dailyRevenue.forEach((k, v) {
      if (v > bestDayValue) {
        bestDayValue = v;
        bestDayKey = k;
      }
    });

    final products = productAgg.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));

    return ChartAggregate(
      revenue: revenue,
      purchasesTotal: purchasesTotal,
      expensesTotal: expensesTotal,
      writeOffsTotal: writeOffsTotal,
      profit: profit,
      salesCount: salesCount,
      avgSaleValue: avgSaleValue,
      bestDayValue: bestDayValue < 0 ? 0 : bestDayValue,
      dailyRevenue: dailyRevenue,
      dailyPurchases: dailyPurchases,
      dailyExpenses: dailyExpenses,
      products: products,
      totalUnitsSold: products.fold<int>(0, (s, p) => s + p.units),
    );
  }

  String _dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ==================== BUSINESS ====================

  Future<Business> getBusiness() async {
    final db = await database;
    final rows = await db.query('business', where: 'id = 1');
    return Business.fromMap(rows.first);
  }

  Future<void> updateBusiness(Business business) async {
    final db = await database;
    await db.update('business', business.toMap(), where: 'id = 1');
  }

  // ==================== RESET ====================

  Future<void> resetAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      for (final t in [
        'sale_line_items',
        'sales',
        'purchase_line_items',
        'purchases',
        'expenses',
        'creditor_payments',
        'creditor_write_offs',
        'creditors',
        'items',
      ]) {
        await txn.delete(t);
      }
    });
  }
}

class _ProductAgg {
  final String name;
  int units = 0;
  double revenue = 0;
  _ProductAgg({required this.name});
}

class ProductPerformance {
  final String name;
  final int units;
  final double revenue;
  ProductPerformance({required this.name, required this.units, required this.revenue});
}

class ChartAggregate {
  final double revenue;
  final double purchasesTotal;
  final double expensesTotal;
  final double writeOffsTotal;
  final double profit;
  final int salesCount;
  final double avgSaleValue;
  final double bestDayValue;
  final Map<String, double> dailyRevenue;
  final Map<String, double> dailyPurchases;
  final Map<String, double> dailyExpenses;
  final List<_ProductAgg> products;
  final int totalUnitsSold;

  ChartAggregate({
    required this.revenue,
    required this.purchasesTotal,
    required this.expensesTotal,
    required this.writeOffsTotal,
    required this.profit,
    required this.salesCount,
    required this.avgSaleValue,
    required this.bestDayValue,
    required this.dailyRevenue,
    required this.dailyPurchases,
    required this.dailyExpenses,
    required this.products,
    required this.totalUnitsSold,
  });

  List<ProductPerformance> get productList => products
      .map((p) => ProductPerformance(name: p.name, units: p.units, revenue: p.revenue))
      .toList();
}
