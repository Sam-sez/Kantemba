import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/item.dart';
import '../db/database_helper.dart';
import '../widgets/common.dart';
import '../widgets/new_item_sheet.dart';
import '../widgets/barcode_scanner_sheet.dart';

/// Inventory tab content. Adding an item is scan-first: point the camera at
/// the barcode, and if there's signal, the name pre-fills automatically
/// (see new_item_sheet.dart) — you only ever type a name by hand once per
/// item, the first time it's scanned. After that, every future sale or
/// restock just recognizes the barcode against this local list, no lookup
/// needed. Manual entry (no barcode) stays available for items that don't
/// have one, or for genuinely offline use.
class InventoryBody extends StatefulWidget {
  const InventoryBody({super.key});

  @override
  State<InventoryBody> createState() => _InventoryBodyState();
}

class _InventoryBodyState extends State<InventoryBody> {
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

  Future<void> _startAddItem() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: KColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add item', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: KColors.textPrimary)),
              const SizedBox(height: 4),
              const Text(
                'Scanning is the fastest way to build up your inventory — the barcode is captured automatically and the name is looked up if you have signal.',
                style: TextStyle(color: KColors.textSecondary, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              ListTile(
                tileColor: KColors.rowAlt,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.qr_code_scanner, color: KColors.greenBright),
                title: const Text('Scan barcode', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(ctx, 'scan'),
              ),
              const SizedBox(height: 8),
              ListTile(
                tileColor: KColors.rowAlt,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.edit_outlined, color: KColors.textSecondary),
                title: const Text('Enter manually', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('No barcode, or scanning isn\'t working right now', style: TextStyle(fontSize: 11, color: KColors.textSecondary)),
                onTap: () => Navigator.pop(ctx, 'manual'),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == 'scan') {
      final barcode = await Navigator.push<String?>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
      if (barcode == null) {
        // "Search instead" from inside the scanner falls back to manual.
        _openManualForm();
        return;
      }
      final existing = await DatabaseHelper.instance.getItemByBarcode(barcode);
      if (existing != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${existing.name} is already in Inventory — opening it to edit')));
          _openManualForm(existing: existing);
        }
        return;
      }
      final result = await showNewItemSheet(context, barcode: barcode, includeCost: true);
      if (result != null) _load();
    } else if (choice == 'manual') {
      _openManualForm();
    }
  }

  Future<void> _openManualForm({Item? existing}) async {
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
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Inventory', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: KColors.textPrimary)),
                  TextButton.icon(
                    onPressed: _startAddItem,
                    icon: const Icon(Icons.add, size: 18, color: KColors.greenBright),
                    label: const Text('Add item', style: TextStyle(color: KColors.greenBright, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) {
                  _query = v;
                  _load();
                },
                style: const TextStyle(color: KColors.textPrimary),
                decoration: const InputDecoration(hintText: 'Search items or barcode…', prefixIcon: Icon(Icons.search, color: KColors.textSecondary)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('No items yet — tap "Add item" to scan your first one', style: TextStyle(color: KColors.textSecondary)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) {
                        final item = _items[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: KColors.card, borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            onTap: () => _openManualForm(existing: item),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${fmtZMW(item.sellPrice)} · ${item.stockQty} in stock',
                                style: const TextStyle(color: KColors.textSecondary, fontSize: 12)),
                            trailing: item.isLowStock ? const Icon(Icons.warning_amber_rounded, color: KColors.red) : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ],
    );
  }
}
