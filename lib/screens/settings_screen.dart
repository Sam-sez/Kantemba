import 'package:flutter/material.dart';
import '../theme.dart';
import '../models/business.dart';
import '../db/database_helper.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Business? _business;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await DatabaseHelper.instance.getBusiness();
    if (mounted) setState(() => _business = b);
  }

  Future<void> _setThreshold(int v) async {
    final b = _business!;
    final updated = b.copyWith(lowStockThresholdDefault: v.clamp(1, 999));
    await DatabaseHelper.instance.updateBusiness(updated);
    _load();
  }

  Future<void> _toggleNotify(bool v) async {
    final b = _business!;
    await DatabaseHelper.instance.updateBusiness(b.copyWith(notifyLowStock: v));
    _load();
  }

  Future<void> _exportBackup() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export coming soon — format (CSV/PDF) still open per blueprint section 11')),
    );
  }

  Future<void> _resetData() async {
    final confirmed = await showDestructiveConfirmSheet(
      context,
      title: 'Reset all data?',
      message:
          'This permanently deletes every sale, purchase, expense, creditor, and inventory item on this device. Export a backup first if you want to keep a copy.',
      confirmLabel: 'Reset data',
    );
    if (confirmed) {
      await DatabaseHelper.instance.resetAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All data has been reset')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_business == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: KColors.greenBright)));
    }
    final b = _business!;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SectionLabel('Business'),
          _card([
            _infoRow(Icons.storefront, 'Business name', b.businessName),
            _divider(),
            _infoRow(Icons.person_outline, 'Owner', b.ownerName),
          ]),
          SectionLabel('Inventory'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: KColors.card, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Low-stock threshold', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const Text('Default for new items', style: TextStyle(color: KColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.remove, color: KColors.greenBright), onPressed: () => _setThreshold(b.lowStockThresholdDefault - 1)),
                      Text('${b.lowStockThresholdDefault}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      IconButton(icon: const Icon(Icons.add, color: KColors.greenBright), onPressed: () => _setThreshold(b.lowStockThresholdDefault + 1)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SectionLabel('Notifications'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: KColors.card, borderRadius: BorderRadius.circular(12)),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Low-stock alerts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                value: b.notifyLowStock,
                activeColor: KColors.green,
                onChanged: _toggleNotify,
              ),
            ),
          ),
          SectionLabel('Data'),
          _card([
            _actionRow(Icons.download_outlined, 'Export / backup data', KColors.blue, _exportBackup),
            _divider(),
            _actionRow(Icons.delete_outline, 'Reset all data', KColors.red, _resetData, labelColor: KColors.red),
          ]),
          SectionLabel('About'),
          _card([
            _infoRow(Icons.language, 'Currency', 'ZMW (fixed)'),
            _divider(),
            _infoRow(Icons.language, 'Language', 'English (fixed)'),
            _divider(),
            _infoRow(Icons.info_outline, 'Version', '1.0.0'),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(color: KColors.card, child: Column(children: children)),
        ),
      );

  Widget _divider() => const Divider(height: 1, color: KColors.rowAlt);

  Widget _infoRow(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, size: 18, color: KColors.textSecondary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      trailing: Text(value, style: const TextStyle(color: KColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _actionRow(IconData icon, String label, Color iconColor, VoidCallback onTap, {Color? labelColor}) {
    return ListTile(
      leading: Icon(icon, size: 18, color: iconColor),
      title: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: labelColor)),
      trailing: const Icon(Icons.chevron_right, color: KColors.textSecondary, size: 18),
      onTap: onTap,
    );
  }
}
