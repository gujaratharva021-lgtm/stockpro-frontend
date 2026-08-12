import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF387ED1);
  static const primaryDark = Color(0xFF2A5F9E);
  static const success = Color(0xFF00A870);
  static const danger = Color(0xFFEB5B3C);

  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8F9FB),
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primaryDark,
        surface: Colors.white,
        onSurface: Color(0xFF191919),
        onPrimary: Colors.white,
      ),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE6E9ED),
      fontFamily: 'Roboto',
    );
  }

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B0E14),
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primaryDark,
        surface: Color(0xFF11151C),
        onSurface: Colors.white,
        onPrimary: Colors.white,
      ),
      cardColor: const Color(0xFF11151C),
      dividerColor: const Color(0xFF1F2937),
      fontFamily: 'Roboto',
    );
  }
}
