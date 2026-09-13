import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme.dart';
import '../models/item.dart';
import '../db/database_helper.dart';

/// Opt-in, non-blocking product name lookup for an unrecognized barcode
/// (blueprint section 3's one deliberate offline-first exception). Tries a
/// free, keyless barcode database with a short timeout. If there's no
/// connection, or nothing is found, this returns null quickly and the sheet
/// stays blank as normal — price and quantity are always entered manually
/// regardless, since those are shop-specific.
Future<String?> _lookupProductName(String barcode) async {
  try {
    final res = await http
        .get(Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json?fields=product_name'))
        .timeout(const Duration(seconds: 3));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final name = data['product']?['product_name'] as String?;
      if (name != null && name.trim().isNotEmpty) return name.trim();
    }
  } catch (_) {
    // No connection, timeout, or bad response — fail silently. Never blocks.
  }
  return null;
}

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
  return showModalBottomSheet<({Item item, int qty})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: KColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _NewItemSheetContent(barcode: barcode, includeCost: includeCost),
  );
}

class _NewItemSheetContent extends StatefulWidget {
  final String? barcode;
  final bool includeCost;
  const _NewItemSheetContent({this.barcode, required this.includeCost});

  @override
  State<_NewItemSheetContent> createState() => _NewItemSheetContentState();
}

class _NewItemSheetContentState extends State<_NewItemSheetContent> {
  final nameCtrl = TextEditingController();
  final costCtrl = TextEditingController();
  final sellCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  bool _looking = false;

  @override
  void initState() {
    super.initState();
    if (widget.barcode != null) {
      _looking = true;
      _lookupProductName(widget.barcode!).then((name) {
        if (!mounted) return;
        setState(() {
          if (name != null) nameCtrl.text = name;
          _looking = false;
        });
      });
    }
  }

  Future<void> _save() async {
    final name = nameCtrl.text.trim();
    final sell = double.tryParse(sellCtrl.text) ?? 0;
    final cost = double.tryParse(costCtrl.text) ?? 0;
    final qty = int.tryParse(qtyCtrl.text) ?? 1;
    if (name.isEmpty || sell <= 0 || qty <= 0) return;

    final newItem = Item(
      name: name,
      barcode: widget.barcode,
      costPrice: cost,
      sellPrice: sell,
      stockQty: qty,
    );
    final id = await DatabaseHelper.instance.insertItem(newItem);
    if (mounted) {
      Navigator.pop(context, (item: newItem.copyWith(id: id), qty: qty));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 28 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New item', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: KColors.textPrimary)),
          if (widget.barcode != null) ...[
            const SizedBox(height: 4),
            Text('Barcode: ${widget.barcode}', style: const TextStyle(color: KColors.textSecondary, fontSize: 12)),
          ],
          if (_looking) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: KColors.greenBright)),
                SizedBox(width: 8),
                Text('Looking up product name…', style: TextStyle(color: KColors.textSecondary, fontSize: 12)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _field('Name', nameCtrl),
          const SizedBox(height: 10),
          if (widget.includeCost) ...[
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
              onPressed: _save,
              child: const Text('Save & add', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
            ),
          ),
        ],
      ),
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
}
