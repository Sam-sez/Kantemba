import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/item.dart';
import '../models/creditor.dart';
import '../models/sale.dart';
import '../models/sale_line_item.dart';
import '../db/database_helper.dart';
import '../widgets/common.dart';
import '../widgets/new_item_sheet.dart';
import '../widgets/barcode_scanner_sheet.dart';
import 'creditor_detail_screen.dart';

class CreditorsScreen extends StatefulWidget {
  const CreditorsScreen({super.key});

  @override
  State<CreditorsScreen> createState() => _CreditorsScreenState();
}

class _CreditorsScreenState extends State<CreditorsScreen> {
  String _filter = 'all'; // all | owing | paid | written_off
  List<Creditor> _creditors = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await DatabaseHelper.instance.getCreditors(filter: _filter);
    if (mounted) setState(() => _creditors = list);
  }

  Future<void> _openNewCreditSale() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const _NewCreditSaleScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Creditors'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              setState(() => _filter = v);
              _load();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'all', child: Text('All')),
              PopupMenuItem(value: 'owing', child: Text('Owing')),
              PopupMenuItem(value: 'paid', child: Text('Paid')),
              PopupMenuItem(value: 'written_off', child: Text('Written off')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewCreditSale,
        icon: const Icon(Icons.add),
        label: const Text('Credit sale', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _creditors.isEmpty
          ? const Center(child: Text('No creditors yet', style: TextStyle(color: KColors.textSecondary)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _creditors.length,
              itemBuilder: (ctx, i) {
                final c = _creditors[i];
                final owing = c.status == CreditorStatus.open || c.status == CreditorStatus.partial;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: i.isOdd ? KColors.rowAlt : KColors.card, borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => CreditorDetailScreen(creditorId: c.id!)));
                      _load();
                    },
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(c.phone ?? 'No phone', style: const TextStyle(color: KColors.textSecondary, fontSize: 12)),
                    trailing: Text(
                      fmtZMW(c.amountOwed),
                      style: TextStyle(fontWeight: FontWeight.w800, color: owing ? KColors.red : KColors.greenBright),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Search-or-create customer, then scan/search items → confirm logs a
/// credit Sale against that creditor's running tab.
class _NewCreditSaleScreen extends StatefulWidget {
  const _NewCreditSaleScreen();

  @override
  State<_NewCreditSaleScreen> createState() => _NewCreditSaleScreenState();
}

class _NewCreditSaleScreenState extends State<_NewCreditSaleScreen> {
  Creditor? _selectedCreditor;
  final _customerQueryCtrl = TextEditingController();
  List<Creditor> _customerResults = [];

  final List<CartLineLocal> _cart = [];
  bool _searching = false;
  String _itemQuery = '';
  List<Item> _searchResults = [];

  double get _total => _cart.fold(0, (s, l) => s + l.qty * l.item.sellPrice);

  Future<void> _searchCustomers(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _customerResults = []);
      return;
    }
    final results = await DatabaseHelper.instance.searchCreditors(q);
    if (mounted) setState(() => _customerResults = results);
  }

  Future<void> _createCustomer(String name) async {
    final id = await DatabaseHelper.instance.createCreditor(name: name);
    setState(() {
      _selectedCreditor = Creditor(id: id, name: name);
      _customerResults = [];
    });
  }

  void _addToCart(Item item, {int qty = 1}) {
    final existing = _cart.indexWhere((l) => l.item.id == item.id);
    setState(() {
      if (existing >= 0) {
        _cart[existing].qty += qty;
      } else {
        _cart.add(CartLineLocal(item: item, qty: qty));
      }
    });
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String?>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
    if (barcode == null) {
      setState(() => _searching = true);
      return;
    }
    final item = await DatabaseHelper.instance.getItemByBarcode(barcode);
    if (item != null) {
      _addToCart(item);
    } else {
      final result = await showNewItemSheet(context, barcode: barcode);
      if (result != null) _addToCart(result.item, qty: result.qty);
    }
  }

  Future<void> _runItemSearch(String q) async {
    setState(() => _itemQuery = q);
    final results = await DatabaseHelper.instance.getItems(query: q);
    if (mounted) setState(() => _searchResults = results);
  }

  Future<void> _confirm() async {
    if (_selectedCreditor == null || _cart.isEmpty) return;
    final lines = _cart
        .map((l) => SaleLineItem(saleId: 0, itemId: l.item.id!, quantity: l.qty, unitPriceAtSale: l.item.sellPrice))
        .toList();
    await DatabaseHelper.instance.createSale(
      paymentMethod: PaymentMethod.credit,
      lines: lines,
      creditorId: _selectedCreditor!.id,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Credit sale logged for ${_selectedCreditor!.name}')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Credit Sale')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_selectedCreditor == null) ...[
              const Text('Customer', style: TextStyle(fontWeight: FontWeight.w700, color: KColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _customerQueryCtrl,
                onChanged: _searchCustomers,
                style: const TextStyle(color: KColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Search name or phone…', prefixIcon: Icon(Icons.person_search, color: KColors.textSecondary)),
              ),
              const SizedBox(height: 8),
              if (_customerResults.isNotEmpty)
                ZebraCard(
                  children: _customerResults
                      .map((c) => ListTile(
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(fmtZMW(c.amountOwed), style: const TextStyle(color: KColors.textSecondary)),
                            onTap: () => setState(() => _selectedCreditor = c),
                          ))
                      .toList(),
                ),
              if (_customerQueryCtrl.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: () => _createCustomer(_customerQueryCtrl.text.trim()),
                    icon: const Icon(Icons.person_add_alt),
                    label: Text('Add "${_customerQueryCtrl.text.trim()}" as new customer'),
                  ),
                ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: KColors.card, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedCreditor!.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          Text('Current balance: ${fmtZMW(_selectedCreditor!.amountOwed)}', style: const TextStyle(color: KColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () => setState(() => _selectedCreditor = null), child: const Text('Change')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!_searching)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(onPressed: _scanBarcode, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan item')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _searching = true),
                        icon: const Icon(Icons.search),
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
                      onChanged: _runItemSearch,
                      style: const TextStyle(color: KColors.textPrimary),
                      decoration: const InputDecoration(hintText: 'Search items…'),
                    ),
                    TextButton(onPressed: () => setState(() => _searching = false), child: const Text('Use camera instead')),
                    if (_itemQuery.isNotEmpty)
                      ZebraCard(
                        children: _searchResults
                            .map((i) => ListTile(
                                  title: Text(i.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(fmtZMW(i.sellPrice), style: const TextStyle(color: KColors.textSecondary)),
                                  onTap: () => _addToCart(i),
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
                                Expanded(child: Text(l.item.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                                QuantityStepper(value: l.qty, onChanged: (v) => setState(() => l.qty = v)),
                                const SizedBox(width: 10),
                                Text(fmtZMW(l.qty * l.item.sellPrice), style: const TextStyle(fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: KColors.green),
                    onPressed: _confirm,
                    child: Text('Confirm credit sale · ${fmtZMW(_total)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black)),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class CartLineLocal {
  final Item item;
  int qty;
  CartLineLocal({required this.item, this.qty = 1});
}
