import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/item.dart';
import '../db/database_helper.dart';
import '../widgets/common.dart';

class InventoryScreen extends StatefulWidget {
  final bool embedded;
  const InventoryScreen({super.key, this.embedded = false});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Item> _items = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await DatabaseHelper.instance.getItems(query: _query);
    if (mounted) setState(() => _items = items);
  }

  Future<void> _openAddEdit({Item? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
    final costCtrl = TextEditingController(text: existing?.costPrice.toString() ?? '');
    final sellCtrl = TextEditingController(text: existing?.sellPrice.toString() ?? '');
    final stockCtrl = TextEditingController(text: existing?.stockQty.toString() ?? '');
    final thresholdCtrl = TextEditingController(text: (existing?.lowStockThreshold ?? 5).toString());

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: KColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 28 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'Add item' : 'Edit item',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 16),
              _f('Name', nameCtrl),
              const SizedBox(height: 10),
              _f('Barcode (optional)', barcodeCtrl),
              const SizedBox(height: 10),
              _f('Cost price (K)', costCtrl, numeric: true),
              const SizedBox(height: 10),
              _f('Sell price (K)', sellCtrl, numeric: true),
              const SizedBox(height: 10),
              _f('Stock quantity', stockCtrl, numeric: true),
              const SizedBox(height: 10),
              _f('Low-stock threshold', thresholdCtrl, numeric: true),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: KColors.green),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final item = Item(
                      id: existing?.id,
                      name: name,
                      barcode: barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
                      costPrice: double.tryParse(costCtrl.text) ?? 0,
                      sellPrice: double.tryParse(sellCtrl.text) ?? 0,
                      stockQty: int.tryParse(stockCtrl.text) ?? 0,
                      lowStockThreshold: int.tryParse(thresholdCtrl.text) ?? 5,
                      usageCount: existing?.usageCount ?? 0,
                      createdAt: existing?.createdAt,
                    );
                    if (existing == null) {
                      await DatabaseHelper.instance.insertItem(item);
                    } else {
                      await DatabaseHelper.instance.updateItem(item);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  },
                  child: Text(existing == null ? 'Add item' : 'Save changes',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _f(String label, TextEditingController ctrl, {bool numeric = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: KColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          style: const TextStyle(color: KColors.textPrimary),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        automaticallyImplyLeading: !widget.embedded,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddEdit(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) {
                _query = v;
                _load();
              },
              style: const TextStyle(color: KColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Search items or barcode…', prefixIcon: Icon(Icons.search, color: KColors.textSecondary)),
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('No items yet', style: TextStyle(color: KColors.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) {
                      final item = _items[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: KColors.card, borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          onTap: () => _openAddEdit(existing: item),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${fmtZMW(item.sellPrice)} · ${item.stockQty} in stock',
                              style: const TextStyle(color: KColors.textSecondary, fontSize: 12)),
                          trailing: item.isLowStock
                              ? const Icon(Icons.warning_amber_rounded, color: KColors.red)
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
