import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/theme/app_dimens.dart';

enum AppButtonVariant { primary, buy, sell, outline }

/// Standard button used for primary CTAs and BUY/SELL actions.
/// Keeps trading-color rules (buy=success green, sell=danger red)
/// consistent between order screens, stock detail, and watchlist actions.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.fullWidth = true,
  });

  Color get _bg => switch (variant) {
        AppButtonVariant.primary => AppColors.primary,
        AppButtonVariant.buy => AppColors.success,
        AppButtonVariant.sell => AppColors.danger,
        AppButtonVariant.outline => Colors.transparent,
      };

  Color get _fg =>
      variant == AppButtonVariant.outline ? AppColors.primary : Colors.white;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _fg),
          )
        : Text(label,
            style: TextStyle(fontWeight: FontWeight.w700, color: _fg));

    final button = ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _bg,
        foregroundColor: _fg,
        elevation: 0,
        side: variant == AppButtonVariant.outline
            ? const BorderSide(color: AppColors.primary)
            : BorderSide.none,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: child,
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
