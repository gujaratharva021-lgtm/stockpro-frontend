import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class PriceChart extends StatefulWidget {
  final List<dynamic> history;
  const PriceChart({super.key, required this.history});

  @override
  State<PriceChart> createState() => _PriceChartState();
}

class _PriceChartState extends State<PriceChart> {
  String _selected = '1M';
  final List<String> _ranges = ['1W', '1M', '3M', 'ALL'];

  List<dynamic> _getSliced(String range) {
    final data = widget.history;
    int limit;
    switch (range) {
      case '1W': limit = 7; break;
      case '1M': limit = 30; break;
      case '3M': limit = 90; break;
      default: limit = data.length;
    }
    return data.length > limit ? data.sublist(data.length - limit) : data;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.history.isEmpty) return const SizedBox.shrink();

    final sliced = _getSliced(_selected);
    final spots = <FlSpot>[];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < sliced.length; i++) {
      final close = (sliced[i]['close'] as num?)?.toDouble() ?? 0;
      if (close <= 0) continue;
      spots.add(FlSpot(i.toDouble(), close));
      if (close < minY) minY = close;
      if (close > maxY) maxY = close;
    }

    if (spots.isEmpty) return const SizedBox.shrink();

    final padding = (maxY - minY) * 0.15;
    final isUp = spots.last.y >= spots.first.y;
    final lineColor = isUp ? AppColors.success : AppColors.danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Range selector
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: _ranges.map((r) {
            final isActive = r == _selected;
            return GestureDetector(
              onTap: () => setState(() => _selected = r),
              child: Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
                ),
                child: Text(
                  r,
                  style: TextStyle(
                    color: isActive ? Colors.white : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: minY - padding,
              maxY: maxY + padding,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.border,
                  strokeWidth: 0.8,
                  dashArray: [4, 4],
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 56,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          '₹${value.toStringAsFixed(0)}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.textPrimary.withValues(alpha: 0.9),
                  getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                    '₹${s.y.toStringAsFixed(2)}',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  )).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: lineColor,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [lineColor.withValues(alpha: 0.2), lineColor.withValues(alpha: 0.0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}