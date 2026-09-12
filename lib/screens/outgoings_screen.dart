import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/item.dart';
import '../models/expense.dart';
import '../models/purchase_line_item.dart';
import '../db/database_helper.dart';
import '../widgets/common.dart';
import '../widgets/new_item_sheet.dart';
import '../widgets/barcode_scanner_sheet.dart';

class OutgoingsScreen extends StatefulWidget {
  final bool embedded;
  const OutgoingsScreen({super.key, this.embedded = false});

  @override
  State<OutgoingsScreen> createState() => _OutgoingsScreenState();
}

class _OutgoingsScreenState extends State<OutgoingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Outgoings'),
          automaticallyImplyLeading: !widget.embedded,
          bottom: TabBar(
            controller: _tabController,
            labelColor: KColors.greenBright,
            unselectedLabelColor: KColors.textSecondary,
            indicatorColor: KColors.greenBright,
            tabs: const [Tab(text: 'Purchases'), Tab(text: 'Expenses')],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [_PurchasesTab(), _ExpensesTab()],
        ),
      ),
    );
  }
}

class _PurchaseCartLine {
  final Item item;
  int qty;
  double unitCost;
  _PurchaseCartLine({required this.item, required this.qty, required this.unitCost});
  double get total => qty * unitCost;
}

class _PurchasesTab extends StatefulWidget {
  const _PurchasesTab();

  @override
  State<_PurchasesTab> createState() => _PurchasesTabState();
}

class _PurchasesTabState extends State<_PurchasesTab> {
  final List<_PurchaseCartLine> _cart = [];
  bool _searching = false;
  String _query = '';
  List<Item> _searchResults = [];
  List<Item> _frequents = [];
  final _supplierCtrl = TextEditingController();

  double get _total => _cart.fold(0, (s, l) => s + l.total);

  @override
  void initState() {
    super.initState();
    _loadFrequents();
  }

  Future<void> _loadFrequents() async {
    final items = await DatabaseHelper.instance.getFrequentItems();
    if (mounted) setState(() => _frequents = items);
  }

  Future<void> _promptQtyAndCost(Item item) async {
    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController(text: item.costPrice.toString());
    final result = await showModalBottomSheet<(int, double)>(
      context: context,
      backgroundColor: KColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 28 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 14),
            const Text('Quantity', style: TextStyle(color: KColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(controller: qtyCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: KColors.textPrimary)),
            const SizedBox(height: 10),
            const Text('Cost per unit (K)', style: TextStyle(color: KColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(controller: costCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: KColors.textPrimary)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: KColors.blue),
                onPressed: () {
                  final qty = int.tryParse(qtyCtrl.text) ?? 1;
                  final cost = double.tryParse(costCtrl.text) ?? item.costPrice;
                  Navigator.pop(ctx, (qty, cost));
                },
                child: const Text('Add to cart', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() {
        final existing = _cart.indexWhere((l) => l.item.id == item.id);
        if (existing >= 0) {
          _cart[existing].qty += result.$1;
          _cart[existing].unitCost = result.$2;
        } else {
          _cart.add(_PurchaseCartLine(item: item, qty: result.$1, unitCost: result.$2));
        }
      });
    }
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String?>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
    if (barcode == null) {
      setState(() => _searching = true);
      return;
    }
    final item = await DatabaseHelper.instance.getItemByBarcode(barcode);
    if (item != null) {
      _promptQtyAndCost(item);
    } else {
      final result = await showNewItemSheet(context, barcode: barcode, includeCost: true);
      if (result != null) {
        setState(() => _cart.add(_PurchaseCartLine(item: result.item, qty: result.qty, unitCost: result.item.costPrice)));
      }
    }
  }

  Future<void> _runSearch(String q) async {
    setState(() => _query = q);
    final results = await DatabaseHelper.instance.getItems(query: q);
    if (mounted) setState(() => _searchResults = results);
  }

  Future<void> _confirm() async {
    if (_cart.isEmpty) return;
    final lines = _cart
        .map((l) => PurchaseLineItem(purchaseId: 0, itemId: l.item.id!, quantity: l.qty, unitCostAtPurchase: l.unitCost))
        .toList();
    await DatabaseHelper.instance.createPurchase(
      lines: lines,
      supplier: _supplierCtrl.text.trim().isEmpty ? null : _supplierCtrl.text.trim(),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase logged — stock updated')));
      setState(() {
        _cart.clear();
        _supplierCtrl.clear();
      });
      _loadFrequents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_searching)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner, color: KColors.blue),
                    label: const Text('Scan item'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _searching = true),
                    icon: const Icon(Icons.search, color: KColors.blue),
                    label: const Text('Search'),
                  ),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  autofocus: true,
                  onChanged: _runSearch,
                  style: const TextStyle(color: KColors.textPrimary),
                  decoration: const InputDecoration(hintText: 'Search items…', prefixIcon: Icon(Icons.search, color: KColors.textSecondary)),
                ),
                TextButton(onPressed: () => setState(() => _searching = false), child: const Text('Use camera instead', style: TextStyle(color: KColors.blue))),
                if (_query.isNotEmpty)
                  ZebraCard(
                    children: _searchResults
                        .map((i) => ListTile(
                              title: Text(i.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text('Last cost: ${fmtZMW(i.costPrice)}', style: const TextStyle(color: KColors.textSecondary)),
                              onTap: () => _promptQtyAndCost(i),
                            ))
                        .toList(),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          if (_cart.isNotEmpty) ...[
            ZebraCard(
              children: _cart
                  .map((l) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text('${fmtZMW(l.unitCost)} each', style: const TextStyle(color: KColors.textSecondary, fontSize: 12)),
                                ],
                              ),
                            ),
                            QuantityStepper(value: l.qty, onChanged: (v) => setState(() => l.qty = v)),
                            const SizedBox(width: 10),
                            Text(fmtZMW(l.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _supplierCtrl,
              style: const TextStyle(color: KColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Supplier (optional)'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: KColors.blue),
                onPressed: _confirm,
                child: Text('Confirm · ${fmtZMW(_total)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (_frequents.isNotEmpty) ...[
            const Text('Frequents', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ZebraCard(
                children: _frequents
                    .map((i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(i.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    Text('Last cost: ${fmtZMW(i.costPrice)}', style: const TextStyle(color: KColors.textSecondary, fontSize: 11)),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 34,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: KColors.blue, padding: const EdgeInsets.symmetric(horizontal: 14)),
                                  onPressed: () => _promptQtyAndCost(i),
                                  child: const Text('Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExpensesTab extends StatefulWidget {
  const _ExpensesTab();

  @override
  State<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<_ExpensesTab> {
  ExpenseCategory _category = ExpenseCategory.rent;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  Future<void> _confirm() async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) return;
    await DatabaseHelper.instance.insertExpense(Expense(
      category: _category,
      amount: amount,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense logged')));
      setState(() {
        _amountCtrl.clear();
        _noteCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Category', style: TextStyle(fontWeight: FontWeight.w700, color: KColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ExpenseCategory.values.map((c) {
              final selected = c == _category;
              return ChoiceChip(
                label: Text(expenseCategoryLabel(c)),
                selected: selected,
                selectedColor: KColors.red,
                backgroundColor: KColors.card,
                labelStyle: TextStyle(color: selected ? Colors.white : KColors.textPrimary, fontWeight: FontWeight.w700),
                onSelected: (_) => setState(() => _category = c),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: KColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Amount (K)', labelStyle: TextStyle(color: KColors.textSecondary)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            style: const TextStyle(color: KColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Note (optional)', labelStyle: TextStyle(color: KColors.textSecondary)),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: KColors.red),
              onPressed: _confirm,
              child: const Text('Log expense', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
