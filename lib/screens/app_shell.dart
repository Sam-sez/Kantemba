import 'package:flutter/material.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import 'charts_screen.dart';
import 'cash_book_screen.dart';
import 'inventory_screen.dart';
import 'outgoings_screen.dart';
import 'new_sale_screen.dart';
import 'creditors_screen.dart';
import 'profile_screen.dart';

/// The single persistent shell for the whole app (blueprint section 5):
/// a top bar (Creditors / Notifications / Profile) and bottom nav (Charts /
/// Cash Book / Inventory / Outgoings) that stay put everywhere, a global
/// New Sale FAB always one tap away, and Dashboard reached via the Home
/// icon rather than occupying one of the 4 bottom-nav slots.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // 0 = Dashboard (home), 1-4 = the four bottom-nav tabs.
  int _index = 0;
  final GlobalKey<DashboardBodyState> _dashboardKey = GlobalKey<DashboardBodyState>();

  static const _titles = ['Kantemba', 'Charts', 'Cash Book', 'Inventory', 'Outgoings'];

  void _goHome() => setState(() => _index = 0);

  Future<void> _openNewSale() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewSaleScreen()));
    _dashboardKey.currentState?.reload();
    setState(() {}); // tabs re-read fresh from DB on next build via their own loaders
  }

  Future<void> _openCreditors() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreditorsScreen()));
    _dashboardKey.currentState?.reload();
  }

  Future<void> _openProfile() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
    _dashboardKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _index == 0
            ? null
            : IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: 'Home',
                onPressed: _goHome,
              ),
        title: Text(_titles[_index]),
        actions: [
          IconButton(icon: const Icon(Icons.people_alt_outlined), tooltip: 'Creditors', onPressed: _openCreditors),
          IconButton(icon: const Icon(Icons.notifications_none), tooltip: 'Notifications', onPressed: () {}),
          IconButton(icon: const Icon(Icons.person_outline), tooltip: 'Profile', onPressed: _openProfile),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewSale,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('New Sale', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          DashboardBody(key: _dashboardKey, onOpenNotifications: () => _showNotifications(context)),
          const ChartsBody(),
          const CashBookBody(),
          const InventoryBody(),
          const OutgoingsBody(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        // Index 0 (Dashboard) isn't one of these 4 slots — show none
        // selected while on Dashboard rather than mis-highlighting Charts.
        currentIndex: _index == 0 ? 0 : _index - 1,
        selectedItemColor: _index == 0 ? KColors.textSecondary : KColors.greenBright,
        onTap: (i) => setState(() => _index = i + 1),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Charts'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Cash Book'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.call_made), label: 'Outgoings'),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    _dashboardKey.currentState?.showNotifications();
  }
}
