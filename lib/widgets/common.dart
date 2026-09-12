import 'package:flutter/material.dart';
import '../theme.dart';

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: KColors.textPrimary)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color? valueColor;
  const StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: KColors.card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: valueColor ?? KColors.textPrimary),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 12, color: KColors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// A card containing zebra-striped rows — used by Cash Book, Creditors,
/// Outgoings' Frequents, Charts' product list.
class ZebraCard extends StatelessWidget {
  final List<Widget> children;
  const ZebraCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: KColors.card,
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++)
              Container(
                color: i.isOdd ? KColors.rowAlt : Colors.transparent,
                child: children[i],
              ),
          ],
        ),
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  const QuantityStepper({super.key, required this.value, required this.onChanged, this.min = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: KColors.bg, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18, color: KColors.greenBright),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          GestureDetector(
            onTap: () async {
              final controller = TextEditingController(text: value.toString());
              final result = await showDialog<int>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: KColors.card,
                  title: const Text('Quantity', style: TextStyle(color: KColors.textPrimary)),
                  content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: const TextStyle(color: KColors.textPrimary),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text) ?? value),
                      child: const Text('Set'),
                    ),
                  ],
                ),
              );
              if (result != null && result >= min) onChanged(result);
            },
            child: Container(
              constraints: const BoxConstraints(minWidth: 24),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: const UnderlineTabIndicator(
                borderSide: BorderSide(color: KColors.textSecondary, width: 1),
              ),
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: KColors.textPrimary),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18, color: KColors.greenBright),
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class KToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const KToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: KColors.green,
      activeTrackColor: KColors.green.withOpacity(0.4),
      inactiveThumbColor: KColors.textSecondary,
      inactiveTrackColor: KColors.rowAlt,
    );
  }
}

Color typeColor(String type) {
  switch (type) {
    case 'sale':
      return KColors.green;
    case 'credit_sale':
      return KColors.green;
    case 'purchase':
      return KColors.blue;
    case 'expense':
      return KColors.red;
    case 'creditor_payment':
      return KColors.greenBright;
    case 'write_off':
      return KColors.red;
    default:
      return KColors.textSecondary;
  }
}

IconData typeIcon(String type) {
  switch (type) {
    case 'sale':
      return Icons.shopping_cart;
    case 'credit_sale':
      return Icons.shopping_cart_checkout;
    case 'purchase':
      return Icons.move_to_inbox;
    case 'expense':
      return Icons.receipt_long;
    case 'creditor_payment':
      return Icons.volunteer_activism;
    case 'write_off':
      return Icons.remove_circle_outline;
    default:
      return Icons.circle;
  }
}

/// Bottom sheet offering "Full remaining balance" or a custom amount —
/// used for both creditor payments and write-offs.
Future<double?> showAmountChoiceSheet(
  BuildContext context, {
  required String title,
  required double remainingBalance,
  required String confirmLabel,
  Color confirmColor = KColors.green,
}) {
  return showModalBottomSheet<double>(
    context: context,
    backgroundColor: KColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      final customController = TextEditingController();
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: KColors.textPrimary)),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              tileColor: KColors.rowAlt,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              title: const Text('Full remaining balance', style: TextStyle(color: KColors.textPrimary, fontWeight: FontWeight.w700)),
              trailing: Text(
                'K${remainingBalance.round()}',
                style: const TextStyle(color: KColors.textPrimary, fontWeight: FontWeight.w800),
              ),
              onTap: () => Navigator.pop(ctx, remainingBalance),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: customController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: KColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Custom amount (K)'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final v = double.tryParse(customController.text);
                  if (v != null && v > 0) Navigator.pop(ctx, v.clamp(0, remainingBalance));
                },
                child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Destructive confirm sheet — used for Reset all data.
Future<bool> showDestructiveConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: KColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: KColors.textPrimary)),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 13, color: KColors.textSecondary, height: 1.5)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: KColors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
