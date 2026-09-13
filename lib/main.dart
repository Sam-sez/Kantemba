import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/app_shell.dart';

void main() {
  runApp(const KantembaApp());
}

class KantembaApp extends StatelessWidget {
  const KantembaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kantemba',
      debugShowCheckedModeBanner: false,
      theme: buildKantembaTheme(),
      home: const AppShell(),
    );
  }
}
