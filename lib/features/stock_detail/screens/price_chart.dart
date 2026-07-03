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
  String _timeframe = '1M';
  bool _isCandlestick = false;
  int? _touchedIndex;

  static const _timeframes = ['1W', '1M', '3M', '1Y', 'ALL'];

  List<dynamic> get _filtered {
    final data = widget.history;
    if (data.isEmpty) return data;
    switch (_timeframe) {
      case '1W': return data.length > 7 ? data.sublist(data.length - 7) : data;
      case '1M': return data.length > 30 ? data.sublist(data.length - 30) : data;
      case '3M': return data.length > 90 ? data.sublist(data.length - 90) : data;
      case '1Y': return data.length > 252 ? data.sublist(data.length - 252) : data;
      default: return data;
    }
  }

  List<FlSpot> get _spots {
    final filtered = _filtered;
    return filtered.asMap().entries.map((e) {
      final close = (e.value['close'] as num?)?.toDouble() ?? 0;
      return FlSpot(e.key.toDouble(), close);
    }).toList();
  }

  double get _minY {
    final spots = _spots;
    if (spots.isEmpty) return 0;
    return spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.998;
  }

  double get _maxY {
    final spots = _spots;
    if (spots.isEmpty) return 0;
    return spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.002;
  }

  bool get _isUp {
    final spots = _spots;
    if (spots.length < 2) return true;
    return spots.last.y >= spots.first.y;
  }

  Color get _chartColor => _isUp ? AppColors.success : AppColors.danger;

  @override
  Widget build(BuildContext context) {
    final spots = _spots;
    if (spots.isEmpty) return const SizedBox(height: 200, child: Center(child: Text('No data', style: TextStyle(color: AppColors.textMuted))));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chart type toggle + timeframes
        Row(
          children: [
            // Candlestick toggle
            GestureDetector(
              onTap: () => setState(() => _isCandlestick = !_isCandlestick),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isCandlestick ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _isCandlestick ? AppColors.primary : AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(_isCandlestick ? Icons.candlestick_chart : Icons.show_chart, color: _isCandlestick ? AppColors.primary : AppColors.textMuted, size: 14),
                    const SizedBox(width: 4),
                    Text(_isCandlestick ? 'Candle' : 'Line', style: TextStyle(color: _isCandlestick ? AppColors.primary : AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // Timeframe buttons
            ..._timeframes.map((tf) => GestureDetector(
              onTap: () => setState(() => _timeframe = tf),
              child: Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _timeframe == tf ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(tf, style: TextStyle(color: _timeframe == tf ? Colors.white : AppColors.textMuted, fontSize: 12, fontWeight: _timeframe == tf ? FontWeight.bold : FontWeight.normal)),
              ),
            )),
          ],
        ),
        const SizedBox(height: 12),

        // Chart
        SizedBox(
          height: 200,
          child: _isCandlestick ? _buildCandlestickChart() : _buildLineChart(spots),
        ),

        // Price info on touch
        if (_touchedIndex != null && _touchedIndex! < _filtered.length) ...[
          const SizedBox(height: 8),
          _buildTouchInfo(_touchedIndex!),
        ],
      ],
    );
  }

  Widget _buildLineChart(List<FlSpot> spots) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (_maxY - _minY) / 4,
          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border.withOpacity(0.5), strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              interval: (_maxY - _minY) / 4,
              getTitlesWidget: (val, _) => Text('₹${_formatPrice(val)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minY: _minY,
        maxY: _maxY,
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            setState(() {
              if (response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
                _touchedIndex = response.lineBarSpots!.first.spotIndex;
              } else if (event is FlPointerExitEvent || event is FlTapUpEvent) {
                _touchedIndex = null;
              }
            });
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('₹${s.y.toStringAsFixed(2)}', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: _chartColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_chartColor.withOpacity(0.2), _chartColor.withOpacity(0.0)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandlestickChart() {
    final filtered = _filtered;
    if (filtered.isEmpty) return const SizedBox();

    // Calculate min/max from OHLC
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    for (final d in filtered) {
      final low = (d['low'] as num?)?.toDouble() ?? 0;
      final high = (d['high'] as num?)?.toDouble() ?? 0;
      if (low < minVal) minVal = low;
      if (high > maxVal) maxVal = high;
    }
    final padding = (maxVal - minVal) * 0.05;
    minVal -= padding;
    maxVal += padding;

    return CustomPaint(
      size: const Size(double.infinity, 200),
      painter: _CandlestickPainter(data: filtered, minVal: minVal, maxVal: maxVal),
    );
  }

  Widget _buildTouchInfo(int index) {
    final d = _filtered[index];
    final open = (d['open'] as num?)?.toDouble() ?? 0;
    final high = (d['high'] as num?)?.toDouble() ?? 0;
    final low = (d['low'] as num?)?.toDouble() ?? 0;
    final close = (d['close'] as num?)?.toDouble() ?? 0;
    final isUp = close >= open;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ohlcItem('O', open, AppColors.textSecondary),
          _ohlcItem('H', high, AppColors.success),
          _ohlcItem('L', low, AppColors.danger),
          _ohlcItem('C', close, isUp ? AppColors.success : AppColors.danger),
        ],
      ),
    );
  }

  Widget _ohlcItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        Text('₹${value.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _formatPrice(double val) {
    if (val >= 10000) return '${(val / 1000).toStringAsFixed(0)}K';
    return val.toStringAsFixed(0);
  }
}

class _CandlestickPainter extends CustomPainter {
  final List<dynamic> data;
  final double minVal;
  final double maxVal;

  _CandlestickPainter({required this.data, required this.minVal, required this.maxVal});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final range = maxVal - minVal;
    if (range == 0) return;

    final candleWidth = (size.width / data.length) * 0.7;
    final spacing = size.width / data.length;

    for (int i = 0; i < data.length; i++) {
      final d = data[i];
      final open = (d['open'] as num?)?.toDouble() ?? 0;
      final high = (d['high'] as num?)?.toDouble() ?? 0;
      final low = (d['low'] as num?)?.toDouble() ?? 0;
      final close = (d['close'] as num?)?.toDouble() ?? 0;

      final isUp = close >= open;
      final color = isUp ? const Color(0xFF16A34A) : const Color(0xFFEF4444);
      final paint = Paint()..color = color..style = PaintingStyle.fill;
      final wickPaint = Paint()..color = color..strokeWidth = 1.0;

      final x = spacing * i + spacing / 2;
      final openY = size.height - ((open - minVal) / range) * size.height;
      final closeY = size.height - ((close - minVal) / range) * size.height;
      final highY = size.height - ((high - minVal) / range) * size.height;
      final lowY = size.height - ((low - minVal) / range) * size.height;

      // Wick
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), wickPaint);

      // Body
      final bodyTop = isUp ? closeY : openY;
      final bodyBottom = isUp ? openY : closeY;
      final bodyHeight = (bodyBottom - bodyTop).abs().clamp(1.0, double.infinity);

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x - candleWidth / 2, bodyTop, candleWidth, bodyHeight), const Radius.circular(1)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}