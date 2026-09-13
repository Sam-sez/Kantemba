import 'package:flutter/material.dart';

/// Design tokens — mirrors the approved sandbox design system (blueprint section 7).
class KColors {
  static const bg = Color(0xFF0C100D);
  static const card = Color(0xFF171D19);
  static const rowAlt = Color(0xFF1C2320);
  static const green = Color(0xFF3EA35C); // Sales
  static const greenBright = Color(0xFF4CBE6C); // Creditor Payments / primary accents
  static const red = Color(0xFFE2542D); // Expenses / low stock / overdue credit
  static const blue = Color(0xFF3E8ED8); // Purchases
  static const textPrimary = Color(0xFFF4F6F4);
  static const textSecondary = Color(0xFF8FA095);
}

ThemeData buildKantembaTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: KColors.bg,
    primaryColor: KColors.greenBright,
    colorScheme: base.colorScheme.copyWith(
      primary: KColors.greenBright,
      secondary: KColors.blue,
      surface: KColors.card,
      error: KColors.red,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'Inter',
      bodyColor: KColors.textPrimary,
      displayColor: KColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: KColors.bg,
      elevation: 0,
      iconTheme: IconThemeData(color: KColors.textSecondary),
      titleTextStyle: TextStyle(
        color: KColors.textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 17,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: KColors.card,
      selectedItemColor: KColors.greenBright,
      unselectedItemColor: KColors.textSecondary,
      type: BottomNavigationBarType.fixed,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: KColors.greenBright,
      foregroundColor: Colors.black,
    ),
    cardTheme: const CardThemeData(
      color: KColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    dividerColor: KColors.rowAlt,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KColors.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}

/// K + tabular-figure money formatting used everywhere in the app.
String fmtZMW(num n) {
  final rounded = n.round();
  final s = rounded.abs().toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${rounded < 0 ? '-' : ''}K${buf.toString()}';
}
