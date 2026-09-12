import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/item.dart';
import '../db/database_helper.dart';

/// The "New item" bottom sheet: name, sell price, qty — and cost price too
/// when [includeCost] is true (Purchases, where a purchase establishes the
/// item's cost for the first time). Saves to Inventory and returns the
/// created Item plus the quantity received, so the caller can add it to
/// the current cart in the same motion.
Future<({Item item, int qty})?> showNewItemSheet(
  BuildContext context, {
  String? barcode,
  bool includeCost = false,
}) {
  final nameCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final sellCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');

  return showModalBottomSheet<({Item item, int qty})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 28 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New item', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: KColors.textPrimary)),
            if (barcode != null) ...[
              const SizedBox(height: 4),
              Text('Barcode: $barcode', style: const TextStyle(color: KColors.textSecondary, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            _field('Name', nameCtrl),
            const SizedBox(height: 10),
            if (includeCost) ...[
              _field('Cost price (K)', costCtrl, numeric: true),
              const SizedBox(height: 10),
            ],
            _field('Sell price (K)', sellCtrl, numeric: true),
            const SizedBox(height: 10),
            _field('Quantity received', qtyCtrl, numeric: true),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: KColors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final sell = double.tryParse(sellCtrl.text) ?? 0;
                  final cost = double.tryParse(costCtrl.text) ?? 0;
                  final qty = int.tryParse(qtyCtrl.text) ?? 1;
                  if (name.isEmpty || sell <= 0 || qty <= 0) return;

                  final newItem = Item(
                    name: name,
                    barcode: barcode,
                    costPrice: cost,
                    sellPrice: sell,
                    stockQty: qty,
                  );
                  final id = await DatabaseHelper.instance.insertItem(newItem);
                  if (ctx.mounted) {
                    Navigator.pop(ctx, (item: newItem.copyWith(id: id), qty: qty));
                  }
                },
                child: const Text('Save & add', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _field(String label, TextEditingController ctrl, {bool numeric = false}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: KColors.textSecondary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: const TextStyle(color: KColors.textPrimary, fontWeight: FontWeight.w600),
      ),
    ],
  );
}
