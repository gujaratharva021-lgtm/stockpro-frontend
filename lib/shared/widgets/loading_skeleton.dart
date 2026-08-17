import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/theme/app_dimens.dart';

/// Shimmering placeholder block for loading states.
///
/// No `shimmer` package dependency was added on purpose — pubspec.yaml
/// doesn't have one, and this effect is simple enough to do with a plain
/// AnimationController, so Phase 1 avoids introducing a new dependency for
/// a foundational widget.
class LoadingSkeleton extends StatefulWidget {
  final double height;
  final double width;
  final double borderRadius;

  const LoadingSkeleton({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.borderRadius = AppRadius.sm,
  });

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, 0),
              end: Alignment(1 + 2 * t, 0),
              colors: const [
                AppColors.border,
                AppColors.primaryLight,
                AppColors.border,
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// A stack of skeleton rows, useful for list-style loading states
/// (watchlist, holdings, orders, search results).
class LoadingSkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const LoadingSkeletonList({
    super.key,
    this.itemCount = 6,
    this.itemHeight = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: LoadingSkeleton(height: itemHeight, borderRadius: AppRadius.md),
        ),
      ),
    );
  }
}
