import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../db/database_helper.dart';
import '../widgets/common.dart';

class ChartsBody extends StatefulWidget {
  const ChartsBody({super.key});

  @override
  State<ChartsBody> createState() => _ChartsBodyState();
}

enum _Period { today, week, month, year, all }

const _periodLabels = {
  _Period.today: 'Today',
  _Period.week: 'This Week',
  _Period.month: 'This Month',
  _Period.year: 'This Year',
  _Period.all: 'All time',
};

class _ChartsBodyState extends State<ChartsBody> {
  _Period _period = _Period.month;
  String _typeFilter = 'all'; // all | sales | purchases | expenses
  ChartAggregate? _agg;
  ChartAggregate? _prevAgg;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime, DateTime) _range(_Period p) {
    final now = DateTime.now();
    final end = now.add(const Duration(minutes: 1));
    switch (p) {
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
    final (start, end) = _range(_period);
    final agg = await DatabaseHelper.instance.getChartAggregate(start: start, end: end);

    // previous period of equal length, for the delta
    final len = end.difference(start);
    final prevEnd = start;
    final prevStart = start.subtract(len);
    final prevAgg = await DatabaseHelper.instance.getChartAggregate(start: prevStart, end: prevEnd);

    if (!mounted) return;
    setState(() {
      _agg = agg;
      _prevAgg = prevAgg;
      _loading = false;
    });
  }

  double _metricFor(ChartAggregate a) {
    switch (_typeFilter) {
      case 'sales':
        return a.revenue;
      case 'purchases':
        return a.purchasesTotal;
      case 'expenses':
        return a.expensesTotal;
      default:
        return a.revenue;
    }
  }

  Color get _lineColor {
    switch (_typeFilter) {
      case 'purchases':
        return KColors.blue;
      case 'expenses':
        return KColors.red;
      default:
        return KColors.green;
    }
  }

  Map<String, double> _dailyFor(ChartAggregate a) {
    switch (_typeFilter) {
      case 'purchases':
        return a.dailyPurchases;
      case 'expenses':
        return a.dailyExpenses;
      default:
        return a.dailyRevenue;
    }
  }

  String _dayKeyLocal(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<FlSpot> _downsample(List<FlSpot> data, int maxPoints) {
    if (data.length <= maxPoints) return data;
    final step = (data.length / maxPoints).ceil();
    final out = <FlSpot>[];
    for (int i = 0; i < data.length; i += step) {
      out.add(FlSpot((i / step).floorToDouble(), data[i].y));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final agg = _agg;
    final prev = _prevAgg;

    if (_loading || agg == null) {
      return const Center(child: CircularProgressIndicator(color: KColors.greenBright));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: KColors.greenBright,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32, top: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              children: [
                Icon(Icons.trending_up, color: KColors.greenBright, size: 20),
                SizedBox(width: 8),
                Text('Charts', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: KColors.textPrimary)),
              ],
            ),
          ),
          _headline(agg, prev),
          _periodTabs(),
          _chart(agg),
          const SizedBox(height: 16),
          _statCallouts(agg),
          _typeSegmented(),
          _productPerformance(agg),
          _productList(agg),
        ],
      ),
    );
  }

  Widget _headline(ChartAggregate agg, ChartAggregate? prev) {
    final value = _metricFor(agg);
    final label = _typeFilter == 'all' ? 'Revenue' : _typeFilter[0].toUpperCase() + _typeFilter.substring(1);
    double? deltaPct;
    if (_typeFilter == 'all' && prev != null && prev.revenue > 0) {
      deltaPct = ((agg.revenue - prev.revenue) / prev.revenue) * 100;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label · ${_periodLabels[_period]}', style: const TextStyle(color: KColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(fmtZMW(value), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              if (deltaPct != null) ...[
                const SizedBox(width: 10),
                Row(
                  children: [
                    Icon(deltaPct >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 15, color: deltaPct >= 0 ? KColors.greenBright : KColors.red),
                    Text('${deltaPct.abs().toStringAsFixed(1)}%',
                        style: TextStyle(color: deltaPct >= 0 ? KColors.greenBright : KColors.red, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodTabs() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _Period.values.map((p) {
          final selected = p == _period;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_periodLabels[p]!),
              selected: selected,
              selectedColor: KColors.rowAlt,
              backgroundColor: Colors.transparent,
              labelStyle: TextStyle(color: selected ? KColors.textPrimary : KColors.textSecondary, fontWeight: FontWeight.w700),
              onSelected: (_) {
                setState(() => _period = p);
                _load();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _chart(ChartAggregate agg) {
    final daily = _dailyFor(agg);
    final (start, end) = _range(_period);
    final rangeStart = _period == _Period.all && daily.isNotEmpty
        ? DateTime.parse((daily.keys.toList()..sort()).first)
        : DateTime(start.year, start.month, start.day);
    final rangeEnd = DateTime(end.year, end.month, end.day);
    final totalDays = rangeEnd.difference(rangeStart).inDays.clamp(0, 366);

    // Build a complete day-by-day series (missing days = 0) so the chart
    // always renders as a continuous line/area, even with sparse data —
    // a single non-zero day among all-zero days previously looked "blank".
    final keys = <String>[];
    final values = <double>[];
    for (int i = 0; i <= totalDays; i++) {
      final d = rangeStart.add(Duration(days: i));
      final key = _dayKeyLocal(d);
      keys.add(key);
      values.add(daily[key] ?? 0);
    }

    if (keys.isEmpty || keys.length == 1) {
      return const SizedBox(height: 220, child: Center(child: Text('No data for this period', style: TextStyle(color: KColors.textSecondary))));
    }

    final rawSpots = <FlSpot>[for (int i = 0; i < keys.length; i++) FlSpot(i.toDouble(), values[i])];
    // Downsample dense ranges (e.g. a full year of daily data) for legibility.
    final spots = _downsample(rawSpots, 60);
    final maxY = values.fold<double>(0, (m, v) => v > m ? v : m);

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 0),
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY == 0 ? 10 : maxY * 1.2,
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: KColors.rowAlt, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 38,
                      getTitlesWidget: (v, meta) => Text(v.round().toString(), style: const TextStyle(color: KColors.textSecondary, fontSize: 10)),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: _lineColor,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_lineColor.withOpacity(0.45), _lineColor.withOpacity(0.02)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(DateFormat('MMM d').format(DateTime.parse(keys.first)), style: const TextStyle(color: KColors.textSecondary, fontSize: 11)),
              if (keys.length > 2)
                Text(DateFormat('MMM d').format(DateTime.parse(keys[keys.length ~/ 2])), style: const TextStyle(color: KColors.textSecondary, fontSize: 11)),
              Text(DateFormat('MMM d').format(DateTime.parse(keys.last)), style: const TextStyle(color: KColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCallouts(ChartAggregate agg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _callout(fmtZMW(agg.bestDayValue), 'Best day')),
          Expanded(
            child: _callout(
              fmtZMW(agg.profit),
              'Profit',
              color: agg.profit < 0 ? KColors.red : KColors.textPrimary,
            ),
          ),
          Expanded(child: _callout(fmtZMW(agg.avgSaleValue), 'Avg sale value')),
        ],
      ),
    );
  }

  Widget _callout(String value, String label, {Color? color}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: color ?? KColors.textPrimary)),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: KColors.textSecondary, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _typeSegmented() {
    final options = [
      ('all', 'All', null),
      ('sales', 'Sales', KColors.green),
      ('purchases', 'Purchases', KColors.blue),
      ('expenses', 'Expenses', KColors.red),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: KColors.card, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: options.map((o) {
          final selected = o.$1 == _typeFilter;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _typeFilter = o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? KColors.rowAlt : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (o.$3 != null) ...[
                      CircleAvatar(radius: 4, backgroundColor: o.$3),
                      const SizedBox(width: 6),
                    ],
                    Text(o.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? KColors.textPrimary : KColors.textSecondary)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _productPerformance(ChartAggregate agg) {
    final margin = agg.revenue > 0 ? (agg.profit / agg.revenue) * 100 : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Product performance', style: TextStyle(fontWeight: FontWeight.w700, color: KColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.9,
            children: [
              StatCard(icon: Icons.inventory_2_outlined, iconColor: KColors.greenBright, value: '${agg.totalUnitsSold}', label: 'Items sold'),
              StatCard(icon: Icons.receipt_long, iconColor: KColors.blue, value: '${agg.salesCount}', label: 'Transactions'),
              StatCard(
                icon: Icons.emoji_events_outlined,
                iconColor: KColors.greenBright,
                value: agg.productList.isNotEmpty ? agg.productList.first.name : '—',
                label: 'Top product',
              ),
              StatCard(
                icon: Icons.percent,
                iconColor: margin >= 0 ? KColors.greenBright : KColors.red,
                value: '${margin.toStringAsFixed(1)}%',
                label: 'Profit margin',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _productList(ChartAggregate agg) {
    if (agg.productList.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('By revenue', style: TextStyle(fontWeight: FontWeight.w700, color: KColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          ZebraCard(
            children: agg.productList
                .map((p) => ListTile(
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${p.units} units', style: const TextStyle(color: KColors.textSecondary, fontSize: 12)),
                      trailing: Text(fmtZMW(p.revenue), style: const TextStyle(fontWeight: FontWeight.w800)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

/// Standalone full-page version — used when Charts is pushed on top of the
/// shell (e.g. Profile's Stats "View All") rather than reached via the
/// persistent bottom nav.
class ChartsScreen extends StatelessWidget {
  const ChartsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: ChartsBody()),
    );
  }
}
