import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/creditor.dart';
import '../db/database_helper.dart';
import '../widgets/common.dart';

class CreditorDetailScreen extends StatefulWidget {
  final int creditorId;
  const CreditorDetailScreen({super.key, required this.creditorId});

  @override
  State<CreditorDetailScreen> createState() => _CreditorDetailScreenState();
}

class _CreditorDetailScreenState extends State<CreditorDetailScreen> {
  Creditor? _creditor;
  List<CreditorTimelineEntry> _timeline = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final creditor = await DatabaseHelper.instance.getCreditorById(widget.creditorId);
    final timeline = await DatabaseHelper.instance.getCreditorTimeline(widget.creditorId);
    if (!mounted) return;
    setState(() {
      _creditor = creditor;
      _timeline = timeline;
      _loading = false;
    });
  }

  Future<void> _logPayment() async {
    final c = _creditor!;
    final amount = await showAmountChoiceSheet(
      context,
      title: 'Log payment',
      remainingBalance: c.amountOwed,
      confirmLabel: 'Confirm payment',
      confirmColor: KColors.green,
    );
    if (amount != null && amount > 0) {
      await DatabaseHelper.instance.logCreditorPayment(c.id!, amount);
      _load();
    }
  }

  Future<void> _writeOff() async {
    final c = _creditor!;
    final amount = await showAmountChoiceSheet(
      context,
      title: 'Write off',
      remainingBalance: c.amountOwed,
      confirmLabel: 'Confirm write-off',
      confirmColor: KColors.red,
    );
    if (amount != null && amount > 0) {
      await DatabaseHelper.instance.logCreditorWriteOff(c.id!, amount, note: 'Written off');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _creditor == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: KColors.greenBright)));
    }
    final c = _creditor!;
    final owing = c.status == CreditorStatus.open || c.status == CreditorStatus.partial;
    final dateFmt = DateFormat('MMM d, h:mm a');

    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: KColors.card, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.phone ?? 'No phone on file', style: const TextStyle(color: KColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 12),
                Text('Balance', style: const TextStyle(color: KColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                Text(
                  fmtZMW(c.amountOwed),
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: owing ? KColors.red : KColors.greenBright),
                ),
                const SizedBox(height: 4),
                Text(_statusLabel(c.status), style: const TextStyle(color: KColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          if (owing) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: KColors.green),
                    onPressed: _logPayment,
                    icon: const Icon(Icons.payments, color: Colors.black, size: 18),
                    label: const Text('Log Payment', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: KColors.red, side: const BorderSide(color: KColors.red)),
                    onPressed: _writeOff,
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: const Text('Write Off'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const Text('History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          if (_timeline.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No activity yet', style: TextStyle(color: KColors.textSecondary)),
            )
          else
            ZebraCard(
              children: _timeline
                  .map((t) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: KColors.bg,
                          child: Icon(typeIcon(t.type), size: 18, color: typeColor(t.type)),
                        ),
                        title: Text(_timelineLabel(t.type), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Text('${t.detail} · ${dateFmt.format(t.timestamp)}', style: const TextStyle(color: KColors.textSecondary, fontSize: 11)),
                        trailing: Text(
                          t.type == 'write_off' ? '−${fmtZMW(t.amount)}' : fmtZMW(t.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: typeColor(t.type),
                            decoration: t.type == 'write_off' ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  String _statusLabel(CreditorStatus s) {
    switch (s) {
      case CreditorStatus.open:
        return 'Open — nothing paid yet';
      case CreditorStatus.partial:
        return 'Partially paid';
      case CreditorStatus.paid:
        return 'Settled in full';
      case CreditorStatus.writtenOff:
        return 'Written off';
    }
  }

  String _timelineLabel(String type) {
    switch (type) {
      case 'credit_sale':
        return 'Credit sale';
      case 'payment':
        return 'Payment received';
      case 'write_off':
        return 'Written off';
      default:
        return type;
    }
  }
}
