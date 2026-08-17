import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';

/// StockPro's typography scale. Named for what the text *is*, not its
/// pixel size, so screens describe intent ("this is a price hero") rather
/// than picking a number that happens to look right. Every screen prior
/// to Phase 2.5 hand-picked font sizes ad hoc (e.g. the dashboard alone
/// used 34, 19, 17, 15, 14, 13, 11.5, 10.5 in different spots with no
/// shared logic) -- this scale is the fix.
///
/// Hierarchy used throughout the app:
///   priceHero      -> the one large number a screen is about (portfolio
///                     value, a stock's current price)
///   priceLarge     -> a secondary but still prominent number (a holding's
///                     current value, a stat card total)
///   changeText     -> the +/- value or percentage next to a price;
///                     callers set color (AppColors.success/danger), this
///                     only fixes size/weight so change text is
///                     consistent everywhere it appears
///   titleLarge     -> screen/section titles
///   titleMedium    -> card headers, sub-section titles
///   body           -> primary readable content (company names, labels)
///   bodySecondary  -> secondary info (symbol under a company name)
///   caption        -> smallest supporting metadata (timestamps, muted labels)
///   label          -> small all-caps-style tags, button text, chips
class AppTypography {
  static const _weightBold = FontWeight.w700;
  static const _weightSemibold = FontWeight.w600;
  static const _weightMedium = FontWeight.w500;
  static const _weightRegular = FontWeight.w400;

  static const priceHero = TextStyle(
    fontSize: 32,
    fontWeight: _weightBold,
    color: AppColors.textPrimary,
    height: 1.1,
    letterSpacing: -0.5,
  );

  static const priceLarge = TextStyle(
    fontSize: 22,
    fontWeight: _weightBold,
    color: AppColors.textPrimary,
    height: 1.15,
  );

  static const priceMedium = TextStyle(
    fontSize: 15,
    fontWeight: _weightSemibold,
    color: AppColors.textPrimary,
  );

  /// Color intentionally omitted -- callers pass AppColors.success/danger.
  static const changeText = TextStyle(
    fontSize: 13,
    fontWeight: _weightSemibold,
  );

  static const changeTextSmall = TextStyle(
    fontSize: 11,
    fontWeight: _weightSemibold,
  );

  static const titleLarge = TextStyle(
    fontSize: 20,
    fontWeight: _weightBold,
    color: AppColors.textPrimary,
  );

  static const titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: _weightBold,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 14,
    fontWeight: _weightMedium,
    color: AppColors.textPrimary,
  );

  static const bodySecondary = TextStyle(
    fontSize: 12,
    fontWeight: _weightRegular,
    color: AppColors.textMuted,
  );

  static const caption = TextStyle(
    fontSize: 11,
    fontWeight: _weightRegular,
    color: AppColors.textMuted,
  );

  static const label = TextStyle(
    fontSize: 12,
    fontWeight: _weightSemibold,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
  );
}
