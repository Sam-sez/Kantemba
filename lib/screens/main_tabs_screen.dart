import 'package:flutter/material.dart';
import 'charts_screen.dart';
import 'cash_book_screen.dart';
import 'inventory_screen.dart';
import 'outgoings_screen.dart';

/// Persistent bottom-nav container (blueprint section 5): Charts, Cash Book,
/// Inventory, Outgoings. Reached from Dashboard; the back chevron on each
/// child screen returns to Dashboard via Navigator.pop.
class MainTabsScreen extends StatefulWidget {
  final int initialIndex;
  const MainTabsScreen({super.key, this.initialIndex = 0});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          ChartsScreen(embedded: true),
          CashBookScreen(embedded: true),
          InventoryScreen(embedded: true),
          OutgoingsScreen(embedded: true),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Charts'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Cash Book'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Inventory'),
          BottomNavigationBarItem(icon: Icon(Icons.call_made), label: 'Outgoings'),
        ],
      ),
    );
  }
}
