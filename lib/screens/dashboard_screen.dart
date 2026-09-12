import 'package:flutter/material.dart';
import '../theme.dart';
import '../db/database_helper.dart';
import '../widgets/common.dart';
import 'main_tabs_screen.dart';
import 'new_sale_screen.dart';
import 'inventory_screen.dart';
import 'creditors_screen.dart';
import 'profile_screen.dart';
import 'cash_book_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _todaysSales = 0;
  double _outstandingCredit = 0;
  int _lowStockCount = 0;
  List<ActivityEntry> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = DatabaseHelper.instance;
    final sales = await db.getTodaysSalesTotal();
    final credit = await db.getTotalOutstandingCredit();
    final lowStock = await db.getLowStockItems();
    final recent = await db.getRecentActivity(limit: 6);
    if (!mounted) return;
    setState(() {
      _todaysSales = sales;
      _outstandingCredit = credit;
      _lowStockCount = lowStock.length;
      _recent = recent;
      _loading = false;
    });
  }

  Future<void> _openNewSale() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewSaleScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Kantemba'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'Creditors',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreditorsScreen()));
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
            onPressed: () => _showNotifications(context),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              _load();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewSale,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('New Sale', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KColors.greenBright))
          : RefreshIndicator(
              onRefresh: _load,
              color: KColors.greenBright,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  SizedBox(
                    height: 110,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      children: [
                        StatCard(icon: Icons.trending_up, iconColor: KColors.greenBright, value: fmtZMW(_todaysSales), label: "Today's Sales"),
                        const SizedBox(width: 10),
                        StatCard(
                          icon: Icons.people_outline,
                          iconColor: KColors.red,
                          value: fmtZMW(_outstandingCredit),
                          label: 'Outstanding Credit',
                          valueColor: _outstandingCredit > 0 ? KColors.red : null,
                        ),
                        const SizedBox(width: 10),
                        StatCard(
                          icon: Icons.inventory_2_outlined,
                          iconColor: _lowStockCount > 0 ? KColors.red : KColors.textSecondary,
                          value: '$_lowStockCount',
                          label: 'Low Stock',
                          valueColor: _lowStockCount > 0 ? KColors.red : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _navGrid(context),
                  SectionLabel(
                    'Recent Transactions',
                    trailing: GestureDetector(
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const CashBookScreen()));
                        _load();
                      },
                      child: const Text('See more', style: TextStyle(color: KColors.greenBright, fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _recent.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text('No transactions yet — tap New Sale to get started.',
                                style: TextStyle(color: KColors.textSecondary)),
                          )
                        : ZebraCard(
                            children: _recent
                                .map((a) => ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: KColors.bg,
                                        child: Icon(typeIcon(a.type), size: 18, color: typeColor(a.type)),
                                      ),
                                      title: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                      subtitle: Text(a.detail, style: const TextStyle(color: KColors.textSecondary, fontSize: 12)),
                                      trailing: Text(
                                        '${a.isOutflow ? '-' : ''}${fmtZMW(a.amount)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: a.isOutflow ? KColors.red : KColors.textPrimary,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _navGrid(BuildContext context) {
    Widget tile(IconData icon, String label, int tabIndex) {
      return Expanded(
        child: InkWell(
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => MainTabsScreen(initialIndex: tabIndex)));
            _load();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: KColors.card, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Icon(icon, color: KColors.greenBright, size: 20),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: KColors.textPrimary)),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          tile(Icons.show_chart, 'Charts', 0),
          tile(Icons.menu_book, 'Cash Book', 1),
          tile(Icons.inventory_2, 'Inventory', 2),
          tile(Icons.call_made, 'Outgoings', 3),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) async {
    final lowStock = await DatabaseHelper.instance.getLowStockItems();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: KColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Low stock alerts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 14),
            if (lowStock.isEmpty)
              const Text('Nothing low on stock right now.', style: TextStyle(color: KColors.textSecondary))
            else
              ...lowStock.map((i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: KColors.red, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(i.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                        Text('${i.stockQty} left', style: const TextStyle(color: KColors.red, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
