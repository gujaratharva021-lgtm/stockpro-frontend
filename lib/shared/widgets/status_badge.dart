import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/theme/app_dimens.dart';

enum AppStatusTone { positive, negative, warning, error, neutral }

/// Small pill badge for status labels — order status (OPEN/EXECUTED/
/// CANCELLED/REJECTED), KYC status (Approved/Under Review/Rejected), etc.
/// Centralizes the status→color mapping so it's consistent between the
/// Orders screens and the Account/KYC screens.
class StatusBadge extends StatelessWidget {
  final String label;
  final AppStatusTone tone;

  const StatusBadge({super.key, required this.label, required this.tone});

  Color get _color => switch (tone) {
        AppStatusTone.positive => AppColors.success,
        AppStatusTone.negative => AppColors.danger,
        AppStatusTone.warning => AppColors.warning,
        AppStatusTone.error => AppColors.error,
        AppStatusTone.neutral => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
