import 'package:flutter/material.dart';
import '../theme.dart';
import '../db/database_helper.dart';
import '../widgets/common.dart';
import 'cash_book_screen.dart';

/// Dashboard content only — the persistent top bar, bottom nav, and New
/// Sale FAB now live in AppShell, since blueprint section 5 treats those as
/// persistent everywhere, not Dashboard-specific chrome.
class DashboardBody extends StatefulWidget {
  final VoidCallback? onOpenNotifications;
  const DashboardBody({super.key, this.onOpenNotifications});

  @override
  State<DashboardBody> createState() => DashboardBodyState();
}

class DashboardBodyState extends State<DashboardBody> {
  double _todaysSales = 0;
  double _outstandingCredit = 0;
  int _lowStockCount = 0;
  List<ActivityEntry> _recent = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final db = DatabaseHelper.instance;
    final sales = await db.getTodaysSalesTotal();
    final credit = await db.getTotalOutstandingCredit();
    final lowStock = await db.getLowStockItems();
    final recent = await db.getRecentActivity(limit: 8);
    if (!mounted) return;
    setState(() {
      _todaysSales = sales;
      _outstandingCredit = credit;
      _lowStockCount = lowStock.length;
      _recent = recent;
      _loading = false;
    });
  }

  void showNotifications() async {
    final lowStock = await DatabaseHelper.instance.getLowStockItems();
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: KColors.greenBright));
    }
    return RefreshIndicator(
      onRefresh: reload,
      color: KColors.greenBright,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100, top: 8),
        children: [
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
          SectionLabel(
            'Recent Transactions',
            trailing: GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const CashBookScreen()));
                reload();
              },
              child: const Text('See more', style: TextStyle(color: KColors.greenBright, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _recent.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('No transactions yet — tap New Sale to get started.', style: TextStyle(color: KColors.textSecondary)),
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
