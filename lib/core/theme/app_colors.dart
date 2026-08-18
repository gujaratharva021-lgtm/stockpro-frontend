import 'package:flutter/material.dart';

/// StockPro's single source of truth for color. Original palette — not
/// copied from any third-party product's brand colors.
class AppColors {
  // Surfaces
  static const background = Color(0xFF0B0E14);
  static const cardBackground = Color(0xFF151A23);
  static const navBackground = Color(0xFF10141C);
  static const border = Color(0xFF232935);

  // Brand
  static const primary = Color(0xFF4C8DFF);
  static const primaryDark = Color(0xFF2A5F9E);
  static const primaryLight = Color(0xFF1B2A3D);

  // Text
  static const textPrimary = Color(0xFFF5F6F8);
  static const textSecondary = Color(0xFFAEB4C0);
  static const textMuted = Color(0xFF7A8091);

  // Semantic — financial meaning must always pair color with a +/- value or
  // percentage (never color alone), per Phase 2 design rules.
  /// Gains, buy-side success, positive P&L.
  static const success = Color(0xFF00C875);
  /// Losses, sell-side warnings, negative P&L.
  static const danger = Color(0xFFFF5C4D);
  /// Pending / needs-attention states (e.g. KYC in review, order pending).
  static const warning = Color(0xFFF5A623);
  /// Failed / rejected states (e.g. order rejected, KYC rejected) — kept
  /// distinct from `danger` so a rejected order and a losing position don't
  /// share the exact same red and get visually conflated.
  static const error = Color(0xFFE0363F);
}
