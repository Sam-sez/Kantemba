import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../db/database_helper.dart';
import '../widgets/common.dart';

class CashBookBody extends StatefulWidget {
  const CashBookBody({super.key});

  @override
  State<CashBookBody> createState() => _CashBookBodyState();
}

enum _Period { today, week, month, year, all }

const _periodLabels = {
  _Period.today: 'Today',
  _Period.week: 'This week',
  _Period.month: 'This month',
  _Period.year: 'This year',
  _Period.all: 'All time',
};

const _typeLabels = {
  'all': 'All transactions',
  'sales': 'Sales',
  'purchases': 'Purchases',
  'expenses': 'Expenses',
  'creditor_payments': 'Creditor Payments',
};

class _CashBookBodyState extends State<CashBookBody> {
  _Period _period = _Period.month;
  String _typeFilter = 'all';
  List<CashBookEntry> _entries = [];
  bool _loading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    final end = now.add(const Duration(minutes: 1));
    switch (_period) {
      case _Period.today:
        return (DateTime(now.year, now.month, now.day), end);
      case _Period.week:
        return (now.subtract(const Duration(days: 7)), end);
      case _Period.month:
        return (now.subtract(const Duration(days: 30)), end);
      case _Period.year:
        return (now.subtract(const Duration(days: 365)), end);
      case _Period.all:
        return (DateTime(2000), end);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (start, end) = _range();
    final entries = await DatabaseHelper.instance.getCashBookEntries(start: start, end: end, typeFilter: _typeFilter);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _openFilter() async {
    _Period tempPeriod = _period;
    String tempType = _typeFilter;
    await showModalBottomSheet(
      context: context,
      backgroundColor: KColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Filter', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 14),
              const Text('Time period', style: TextStyle(color: KColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _Period.values.map((p) {
                  final selected = p == tempPeriod;
                  return ChoiceChip(
                    label: Text(_periodLabels[p]!),
                    selected: selected,
                    selectedColor: KColors.greenBright,
                    backgroundColor: KColors.rowAlt,
                    labelStyle: TextStyle(color: selected ? Colors.black : KColors.textPrimary, fontWeight: FontWeight.w700),
                    onSelected: (_) => setSheet(() => tempPeriod = p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              const Text('Show', style: TextStyle(color: KColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _typeLabels.entries.map((e) {
                  final selected = e.key == tempType;
                  final dotColor = e.key == 'sales'
                      ? KColors.green
                      : e.key == 'purchases'
                          ? KColors.blue
                          : e.key == 'expenses'
                              ? KColors.red
                              : e.key == 'creditor_payments'
                                  ? KColors.greenBright
                                  : null;
                  return ChoiceChip(
                    avatar: dotColor != null
                        ? CircleAvatar(backgroundColor: dotColor, radius: 5)
                        : null,
                    label: Text(e.value),
                    selected: selected,
                    selectedColor: KColors.greenBright,
                    backgroundColor: KColors.rowAlt,
                    labelStyle: TextStyle(color: selected ? Colors.black : KColors.textPrimary, fontWeight: FontWeight.w700),
                    onSelected: (_) => setSheet(() => tempType = e.key),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: KColors.green),
                  onPressed: () {
                    setState(() {
                      _period = tempPeriod;
                      _typeFilter = tempType;
                    });
                    Navigator.pop(ctx);
                    _load();
                  },
                  child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final balanceLabel = _typeFilter == 'all' ? 'Balance' : _typeLabels[_typeFilter]!;
    final dateFmt = DateFormat('MMM d · h:mm a');

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: KColors.greenBright));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Cash Book', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: KColors.textPrimary)),
              TextButton.icon(
                onPressed: _openFilter,
                icon: const Icon(Icons.filter_list, color: KColors.textSecondary, size: 18),
                label: Text('${_periodLabels[_period]} · ${_typeLabels[_typeFilter]}',
                    style: const TextStyle(color: KColors.textSecondary, fontSize: 12)),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: KColors.card, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Opening balance', style: TextStyle(color: KColors.textSecondary, fontWeight: FontWeight.w700)),
                      const Text('K0', style: TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: const [
                      Expanded(flex: 3, child: Text('Date', style: TextStyle(color: KColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700))),
                      Expanded(flex: 4, child: Text('Details', style: TextStyle(color: KColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700))),
                      Expanded(flex: 2, child: Text('Dr', textAlign: TextAlign.right, style: TextStyle(color: KColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700))),
                      Expanded(flex: 2, child: Text('Cr', textAlign: TextAlign.right, style: TextStyle(color: KColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700))),
                      Expanded(flex: 3, child: Text('Balance', textAlign: TextAlign.right, style: TextStyle(color: KColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700))),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _entries.isEmpty
                      ? const Center(child: Text('No transactions in this range', style: TextStyle(color: KColors.textSecondary)))
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _entries.length,
                          itemBuilder: (ctx, i) {
                            final e = _entries[i]; // oldest first, most recent at the bottom
                            return Container(
                              color: i.isOdd ? KColors.rowAlt : Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              child: Row(
                                children: [
                                  Expanded(flex: 3, child: Text(dateFmt.format(e.timestamp), style: const TextStyle(fontSize: 11, color: KColors.textSecondary))),
                                  Expanded(flex: 4, child: Text(e.details, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                  Expanded(
                                    flex: 2,
                                    child: Text(e.dr > 0 ? fmtZMW(e.dr) : '—',
                                        textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: KColors.green, fontWeight: FontWeight.w700)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(e.cr > 0 ? fmtZMW(e.cr) : '—',
                                        textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: KColors.red, fontWeight: FontWeight.w700)),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(fmtZMW(e.runningBalance),
                                        textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('$balanceLabel updates live as entries are logged', style: const TextStyle(fontSize: 11, color: KColors.textSecondary)),
                ),
              ],
    );
  }
}

/// Standalone full-page version — used when Cash Book is pushed on top of
/// the shell (e.g. Dashboard's "See more", Profile's "View All") rather
/// than reached via the persistent bottom nav.
class CashBookScreen extends StatelessWidget {
  const CashBookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: CashBookBody()),
    );
  }
}
