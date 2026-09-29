import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_log.dart';
import 'theme.dart';
import 'screens/app_shell.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (d) {
      FlutterError.presentError(d);
      AppLog.add('FLUTTER', d.exceptionAsString(), d.exception, d.stack);
    };
    PlatformDispatcher.instance.onError = (e, st) {
      AppLog.add('PLATFORM', e.toString(), e, st);
      return true;
    };
    AppLog.add('BOOT', 'App starting. Android: ${Platform.operatingSystemVersion}');
    runApp(const KantembaApp());
  }, (e, st) => AppLog.add('ZONE', e.toString(), e, st));
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