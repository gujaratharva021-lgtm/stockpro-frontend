import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFFF5A623);
  static const primaryDark = Color(0xFFE8920A);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);

  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF7F7F9),
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primaryDark,
        surface: Colors.white,
        onSurface: Color(0xFF1A1A1A),
        onPrimary: Colors.white,
      ),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE5E7EB),
      fontFamily: 'Roboto',
    );
  }

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0A0E1A),
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primaryDark,
        surface: Color(0xFF0D1117),
        onSurface: Colors.white,
        onPrimary: Colors.white,
      ),
      cardColor: const Color(0xFF0D1117),
      dividerColor: const Color(0xFF1F2937),
      fontFamily: 'Roboto',
    );
  }
}