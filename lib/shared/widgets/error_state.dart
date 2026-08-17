import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/theme/app_dimens.dart';
import 'package:stock_app/shared/widgets/app_button.dart';

/// Standard error state: friendly message + Retry button. Callers should
/// pass a user-friendly `message`, never a raw exception's `toString()` —
/// keep the raw error in a log/Crashlytics call, not on screen.
class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.message = "Something went wrong. Please try again.",
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 140,
                child: AppButton(label: 'Retry', onPressed: onRetry, variant: AppButtonVariant.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Simple offline banner to show above content when connectivity is lost,
/// distinct from ErrorState so it doesn't replace already-loaded content.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.lg),
      color: AppColors.danger.withValues(alpha: 0.15),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 16, color: AppColors.danger),
          SizedBox(width: AppSpacing.sm),
          Text("You're offline", style: TextStyle(color: AppColors.danger, fontSize: 12)),
        ],
      ),
    );
  }
}
