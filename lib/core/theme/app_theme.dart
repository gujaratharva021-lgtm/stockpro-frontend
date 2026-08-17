import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';

/// PHASE 1 FIX: This class previously hardcoded its own primary/success/danger
/// colors that DIVERGED from AppColors (e.g. primary 0xFF387ED1 here vs
/// 0xFF4C8DFF in AppColors; success 0xFF00A870 here vs 0xFF00C875 in
/// AppColors). Since AppColors is used in ~75 files and this class only fed
/// the top-level ThemeData in main.dart, the result was the global Material
/// theme (used for default control colors, splash/ripple tints, etc.) being
/// a slightly different brand color than every hand-styled widget in the
/// app. AppColors is now the single source of truth; this class just maps
/// it into a ThemeData.
class AppTheme {
  static const primary = AppColors.primary;
  static const primaryDark = AppColors.primaryDark;
  static const success = AppColors.success;
  static const danger = AppColors.danger;

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
        error: danger,
      ),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE6E9ED),
      fontFamily: 'Roboto',
    );
  }

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
