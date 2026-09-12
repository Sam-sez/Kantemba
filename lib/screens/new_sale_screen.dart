import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/item.dart';
import '../models/sale.dart';
import '../models/sale_line_item.dart';
import '../db/database_helper.dart';
import '../widgets/common.dart';
import '../widgets/new_item_sheet.dart';
import '../widgets/barcode_scanner_sheet.dart';

class CartLine {
  final Item item;
  int qty;
  CartLine({required this.item, this.qty = 1});
  double get total => item.sellPrice * qty;
}

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final List<CartLine> _cart = [];
  bool _searching = false;
  String _query = '';
  List<Item> _searchResults = [];
  List<Item> _frequents = [];
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  final _amountReceivedCtrl = TextEditingController();

  double get _total => _cart.fold(0, (s, l) => s + l.total);
  double get _amountReceived => double.tryParse(_amountReceivedCtrl.text) ?? 0;
  double get _change => (_amountReceived - _total).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    _loadFrequents();
  }

  Future<void> _loadFrequents() async {
    final items = await DatabaseHelper.instance.getFrequentItems();
    if (mounted) setState(() => _frequents = items);
  }

  void _addToCart(Item item, {int qty = 1}) {
    final existing = _cart.indexWhere((l) => l.item.id == item.id);
    setState(() {
      if (existing >= 0) {
        _cart[existing].qty += qty;
      } else {
        _cart.add(CartLine(item: item, qty: qty));
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => setState(() {
            final i = _cart.indexWhere((l) => l.item.id == item.id);
            if (i >= 0) {
              if (_cart[i].qty <= qty) {
                _cart.removeAt(i);
              } else {
                _cart[i].qty -= qty;
              }
            }
          }),
        ),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final barcode = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
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

  Future<void> _runSearch(String q) async {
    setState(() => _query = q);
    final results = await DatabaseHelper.instance.getItems(query: q);
    if (mounted) setState(() => _searchResults = results);
  }

  Future<void> _confirm() async {
    if (_cart.isEmpty) return;
    if (_paymentMethod == PaymentMethod.cash && _amountReceived < _total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount received is less than the total')),
      );
      return;
    }
    final lines = _cart
        .map((l) => SaleLineItem(saleId: 0, itemId: l.item.id!, quantity: l.qty, unitPriceAtSale: l.item.sellPrice))
        .toList();

    await DatabaseHelper.instance.createSale(
      paymentMethod: _paymentMethod,
      lines: lines,
      amountReceived: _paymentMethod == PaymentMethod.cash ? _amountReceived : _total,
      changeGiven: _paymentMethod == PaymentMethod.cash ? _change : 0,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale confirmed')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _scanOrSearchBlock(),
                  const SizedBox(height: 16),
                  if (_cart.isNotEmpty) _cartBlock(),
                  const SizedBox(height: 16),
                  if (_cart.isNotEmpty) _paymentBlock(),
                  const SizedBox(height: 16),
                  if (_cart.isNotEmpty)
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: KColors.green),
                        onPressed: _confirm,
                        child: Text('Confirm · ${fmtZMW(_total)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black)),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _frequentsBlock(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanOrSearchBlock() {
    if (!_searching) {
      return Column(
        children: [
          InkWell(
            onTap: _scanBarcode,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 180,
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 140,
                      height: 90,
                      decoration: BoxDecoration(
                        border: Border.all(color: KColors.greenBright, width: 3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Tap to scan a barcode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() => _searching = true),
            child: const Text('Search instead', style: TextStyle(color: KColors.greenBright, fontWeight: FontWeight.w700)),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          autofocus: true,
          onChanged: _runSearch,
          style: const TextStyle(color: KColors.textPrimary),
          decoration: const InputDecoration(hintText: 'Search items…', prefixIcon: Icon(Icons.search, color: KColors.textSecondary)),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _searching = false),
          child: const Text('Use camera instead', style: TextStyle(color: KColors.greenBright, fontWeight: FontWeight.w700)),
        ),
        if (_query.isNotEmpty)
          ZebraCard(
            children: _searchResults
                .map((i) => ListTile(
                      title: Text(i.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(fmtZMW(i.sellPrice), style: const TextStyle(color: KColors.textSecondary)),
                      trailing: Text('${i.stockQty} in stock', style: const TextStyle(color: KColors.textSecondary, fontSize: 12)),
                      onTap: () => _addToCart(i),
                    ))
                .toList(),
          ),
      ],
    );
  }

  Widget _cartBlock() {
    return ZebraCard(
      children: _cart
          .map((line) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(line.item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(fmtZMW(line.item.sellPrice), style: const TextStyle(color: KColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    QuantityStepper(value: line.qty, onChanged: (v) => setState(() => line.qty = v)),
                    const SizedBox(width: 10),
                    Text(fmtZMW(line.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _paymentBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment method', style: TextStyle(fontWeight: FontWeight.w700, color: KColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [PaymentMethod.cash, PaymentMethod.airtelMoney, PaymentMethod.mtnMomo].map((m) {
            final selected = m == _paymentMethod;
            return ChoiceChip(
              label: Text(paymentMethodLabel(m)),
              selected: selected,
              selectedColor: KColors.green,
              backgroundColor: KColors.card,
              labelStyle: TextStyle(color: selected ? Colors.black : KColors.textPrimary, fontWeight: FontWeight.w700),
              onSelected: (_) => setState(() => _paymentMethod = m),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        if (_paymentMethod == PaymentMethod.cash) ...[
          TextField(
            controller: _amountReceivedCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: KColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Amount received (K)', labelStyle: TextStyle(color: KColors.textSecondary)),
          ),
          const SizedBox(height: 8),
          Text('Change: ${fmtZMW(_change)}', style: const TextStyle(fontWeight: FontWeight.w800, color: KColors.greenBright)),
        ] else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: KColors.card, borderRadius: BorderRadius.circular(10)),
            child: const Text('Paid in full — no change to calculate', style: TextStyle(color: KColors.textSecondary)),
          ),
      ],
    );
  }

  Widget _frequentsBlock() {
    if (_frequents.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                          Expanded(child: Text(i.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                          _FrequentLogButton(item: i, onLog: (qty) => _addToCart(i, qty: qty)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _FrequentLogButton extends StatefulWidget {
  final Item item;
  final ValueChanged<int> onLog;
  const _FrequentLogButton({required this.item, required this.onLog});

  @override
  State<_FrequentLogButton> createState() => _FrequentLogButtonState();
}

class _FrequentLogButtonState extends State<_FrequentLogButton> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        QuantityStepper(value: _qty, onChanged: (v) => setState(() => _qty = v)),
        const SizedBox(width: 8),
        SizedBox(
          height: 34,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: KColors.greenBright,
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            onPressed: () {
              widget.onLog(_qty);
              setState(() => _qty = 1);
            },
            child: const Text('Log', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
