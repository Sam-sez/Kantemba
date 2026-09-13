import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/business.dart';
import '../db/database_helper.dart';
import '../widgets/common.dart';
import 'settings_screen.dart';
import 'charts_screen.dart';
import 'cash_book_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Business? _business;
  double _totalSales = 0;
  int _itemsTracked = 0;
  double _outstandingCredit = 0;
  List<ActivityEntry> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final business = await db.getBusiness();
    final totalSales = await db.getAllTimeSalesTotal();
    final itemsTracked = await db.getItemsTrackedCount();
    final credit = await db.getTotalOutstandingCredit();
    final recent = await db.getRecentActivity(limit: 5);
    if (!mounted) return;
    setState(() {
      _business = business;
      _totalSales = totalSales;
      _itemsTracked = itemsTracked;
      _outstandingCredit = credit;
      _recent = recent;
      _loading = false;
    });
  }

  Future<void> _openEditSheet() async {
    final b = _business!;
    final nameCtrl = TextEditingController(text: b.businessName);
    final ownerCtrl = TextEditingController(text: b.ownerName);
    final phoneCtrl = TextEditingController(text: b.phone ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: KColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 28 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit business info', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 16),
            _field('Business name', nameCtrl),
            const SizedBox(height: 10),
            _field('Owner name', ownerCtrl),
            const SizedBox(height: 10),
            _field('Phone', phoneCtrl),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: KColors.green),
                    onPressed: () async {
                      final updated = b.copyWith(
                        businessName: nameCtrl.text.trim(),
                        ownerName: ownerCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                      );
                      await DatabaseHelper.instance.updateBusiness(updated);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
                    child: const Text('Save changes', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: KColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(controller: ctrl, style: const TextStyle(color: KColors.textPrimary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _business == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: KColors.greenBright)));
    }
    final b = _business!;
    final dateFmt = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              _load();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: KColors.card, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.storefront, size: 28, color: KColors.greenBright),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.businessName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                      const SizedBox(height: 2),
                      Text(b.ownerName, style: const TextStyle(color: KColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('Business since ${dateFmt.format(b.createdAt)}', style: const TextStyle(color: KColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: OutlinedButton.icon(
              onPressed: _openEditSheet,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit business info'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 46)),
            ),
          ),
          SectionLabel(
            'Stats',
            trailing: GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChartsScreen()));
              },
              child: const Text('View All', style: TextStyle(color: KColors.greenBright, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                StatCard(icon: Icons.trending_up, iconColor: KColors.greenBright, value: fmtZMW(_totalSales), label: 'Total Sales'),
                const SizedBox(width: 10),
                StatCard(icon: Icons.inventory_2_outlined, iconColor: KColors.blue, value: '$_itemsTracked', label: 'Items Tracked'),
                const SizedBox(width: 10),
                StatCard(
                  icon: Icons.people_outline,
                  iconColor: KColors.red,
                  value: fmtZMW(_outstandingCredit),
                  label: 'Outstanding Credit',
                  valueColor: _outstandingCredit > 0 ? KColors.red : null,
                ),
              ],
            ),
          ),
          SectionLabel(
            'Recent Activity',
            trailing: GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const CashBookScreen()));
              },
              child: const Text('View All', style: TextStyle(color: KColors.greenBright, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _recent.isEmpty
                ? const Text('No activity yet', style: TextStyle(color: KColors.textSecondary))
                : ZebraCard(
                    children: _recent
                        .map((a) => ListTile(
                              leading: CircleAvatar(backgroundColor: KColors.bg, child: Icon(typeIcon(a.type), size: 16, color: typeColor(a.type))),
                              title: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              subtitle: Text(a.detail, style: const TextStyle(color: KColors.textSecondary, fontSize: 12)),
                              trailing: Text(
                                '${a.isOutflow ? '-' : ''}${fmtZMW(a.amount)}',
                                style: TextStyle(fontWeight: FontWeight.w800, color: a.isOutflow ? KColors.red : KColors.textPrimary),
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
