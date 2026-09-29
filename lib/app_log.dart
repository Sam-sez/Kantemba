import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// In-app log buffer. Every caught error and key event is added here so it can
/// be viewed and copied from the phone (LogScreen).
class AppLog {
  static final ValueNotifier<List<String>> entries = ValueNotifier<List<String>>([]);

  static void add(String level, String msg, [Object? err, StackTrace? st]) {
    final line = '${DateTime.now().toIso8601String()} [$level] $msg'
        '${err != null ? '\n  ERROR: $err' : ''}'
        '${st != null ? '\n  $st' : ''}';
    debugPrint(line);
    final list = [...entries.value, line];
    if (list.length > 500) list.removeAt(0);
    entries.value = list;
  }
}

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App logs'),
        actions: [
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              final text = AppLog.entries.value.join('\n');
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logs copied. Paste them into the chat.')),
                );
              }
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<List<String>>(
        valueListenable: AppLog.entries,
        builder: (context, list, _) {
          if (list.isEmpty) {
            return const Center(child: Text('No log entries yet'));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              SelectableText(
                list.join('\n\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ],
          );
        },
      ),
    );
  }
}