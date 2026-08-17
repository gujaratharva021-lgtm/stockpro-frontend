import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';

/// Standardized "+1.24%  (+12.30)"-style price change label.
///
/// Every screen that shows an LTP change (dashboard indices, watchlist rows,
/// search results, stock detail header, portfolio holdings) previously wrote
/// its own `value >= 0 ? AppColors.success : AppColors.danger` logic inline.
/// Centralizing it here means the up/down color rule only has to be correct
/// in one place.
class PriceChange extends StatelessWidget {
  final double change;
  final double changePercent;
  final double fontSize;
  final bool showParens;

  const PriceChange({
    super.key,
    required this.change,
    required this.changePercent,
    this.fontSize = 13,
    this.showParens = true,
  });

  bool get _isUp => change >= 0;

  @override
  Widget build(BuildContext context) {
    final color = _isUp ? AppColors.success : AppColors.danger;
    final sign = _isUp ? '+' : '';
    final pct = '$sign${changePercent.toStringAsFixed(2)}%';
    final abs = '$sign${change.toStringAsFixed(2)}';
    final label = showParens ? '$pct ($abs)' : pct;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          color: color,
          size: fontSize + 6,
        ),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
