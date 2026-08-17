import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';

/// StockPro's single app theme. Dark is the one true StockPro visual
/// identity -- there is no functioning light mode (see Phase 2.5 notes):
/// a `ThemeProvider` existed but was never wired into MaterialApp, and
/// every screen styles itself directly from AppColors rather than
/// Theme.of(context), so a "light theme" here would have had zero visible
/// effect anyway. Removed rather than left as unreachable dead code.
class AppTheme {
  static const primary = AppColors.primary;
  static const primaryDark = AppColors.primaryDark;
  static const success = AppColors.success;
  static const danger = AppColors.danger;

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primaryDark,
        surface: AppColors.cardBackground,
        onSurface: Colors.white,
        onPrimary: Colors.white,
        error: danger,
      ),
      cardColor: AppColors.cardBackground,
      dividerColor: AppColors.border,
      fontFamily: 'Roboto',
    );
  }
}
