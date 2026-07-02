import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/stock_detail/screens/price_chart.dart';

class _Candle {
  final DateTime? date;
  final double open, high, low, close, volume;
  _Candle({this.date, required this.open, required this.high, required this.low, required this.close, required this.volume});

  factory _Candle.fromMap(Map m) {
    double num_(String k) => (m[k] as num?)?.toDouble() ?? 0;
    DateTime? d;
    for (final key in ['date', 'timestamp', 'time', 'datetime']) {
      final v = m[key];
      if (v == null) continue;
      if (v is String) { d = DateTime.tryParse(v); if (d != null) break; }
      if (v is int) { d = DateTime.fromMillisecondsSinceEpoch(v > 9999999999 ? v : v * 1000); break; }
    }
    return _Candle(
      date: d,
      open: num_('open'),
      high: num_('high'),
      low: num_('low'),
      close: num_('close'),
      volume: num_('volume'),
    );
  }
}

class AdvancedChartScreen extends StatefulWidget {
  final String symbol;
  final String companyName;
  final List<dynamic> history;
  final double? currentPrice;
  final double? changePercent;

  const AdvancedChartScreen({
    super.key,
    required this.symbol,
    required this.companyName,
    required this.history,
    this.currentPrice,
    this.changePercent,
  });

  @override
  State<AdvancedChartScreen> createState() => _AdvancedChartScreenState();
}

class _AdvancedChartScreenState extends State<AdvancedChartScreen> {
  String _range = 'ALL';
  String _chartType = 'candle'; // candle | line
  late List<_Candle> _allCandles;

  @override
  void initState() {
    super.initState();
    _allCandles = widget.history.map((h) => _Candle.fromMap(h as Map)).toList();
  }

  List<_Candle> get _filtered {
    if (_allCandles.isEmpty) return [];
    int n;
    switch (_range) {
      case '1W': n = 5; break;
      case '1M': n = 22; break;
      case '3M': n = 66; break;
      default: n = _allCandles.length;
    }
    if (n >= _allCandles.length) return _allCandles;
    return _allCandles.sublist(_allCandles.length - n);
  }

  List<dynamic> get _filteredAsMaps {
    // for reuse with existing PriceChart widget (line mode)
    final f = _filtered;
    final startIdx = _allCandles.length - f.length;
    return widget.history.sublist(startIdx < 0 ? 0 : startIdx);
  }

  @override
  Widget build(BuildContext context) {
    final candles = _filtered;
    final isUp = (widget.changePercent ?? 0) >= 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.symbol, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(widget.companyName, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (widget.currentPrice != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${widget.currentPrice!.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${isUp ? '+' : ''}${widget.changePercent?.toStringAsFixed(2) ?? '0.00'}%', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Chart type toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _typeIcon(Icons.candlestick_chart, 'candle'),
                  const SizedBox(width: 8),
                  _typeIcon(Icons.show_chart, 'line'),
                  const Spacer(),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Chart area
            Expanded(
              child: candles.isEmpty
                  ? const Center(child: Text('No chart data available', style: TextStyle(color: AppColors.textMuted)))
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Expanded(
                            flex: 4,
                            child: _chartType == 'candle'
                                ? _CandlestickView(candles: candles)
                                : Container(
                                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                                    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                                    child: PriceChart(history: _filteredAsMaps),
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            flex: 1,
                            child: _VolumeView(candles: candles),
                          ),
                        ],
                      ),
                    ),
            ),

            // Range tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['1W', '1M', '3M', 'ALL'].map((r) => _rangeTab(r)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeIcon(IconData icon, String type) {
    final active = _chartType == type;
    return GestureDetector(
      onTap: () => setState(() => _chartType = type),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Icon(icon, size: 18, color: active ? AppColors.primary : AppColors.textMuted),
      ),
    );
  }

  Widget _rangeTab(String r) {
    final active = _range == r;
    return GestureDetector(
      onTap: () => setState(() => _range = r),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(r, style: TextStyle(color: active ? AppColors.primary : AppColors.textMuted, fontWeight: active ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
      ),
    );
  }
}

class _CandlestickView extends StatelessWidget {
  final List<_Candle> candles;
  const _CandlestickView({required this.candles});

  @override
  Widget build(BuildContext context) {
    double maxP = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    double minP = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final pad = (maxP - minP) * 0.08;
    maxP += pad == 0 ? 1 : pad;
    minP -= pad == 0 ? 1 : pad;

    return Container(
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: SizedBox(
                width: (candles.length * 10).toDouble().clamp(MediaQuery.of(context).size.width - 60, double.infinity),
                child: CustomPaint(
                  painter: _CandlestickPainter(candles: candles, minPrice: minP, maxPrice: maxP),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: CustomPaint(
              painter: _PriceAxisPainter(minPrice: minP, maxPrice: maxP),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class _CandlestickPainter extends CustomPainter {
  final List<_Candle> candles;
  final double minPrice, maxPrice;
  _CandlestickPainter({required this.candles, required this.minPrice, required this.maxPrice});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    final candleWidth = size.width / candles.length;
    final bodyWidth = (candleWidth * 0.6).clamp(1.5, 14.0);

    double yFor(double price) {
      final range = maxPrice - minPrice;
      if (range <= 0) return size.height / 2;
      return size.height - ((price - minPrice) / range) * size.height;
    }

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final x = candleWidth * i + candleWidth / 2;
      final isUp = c.close >= c.open;
      final color = isUp ? const Color(0xFF26A69A) : const Color(0xFFEF5350);
      final wickPaint = Paint()..color = color..strokeWidth = 1.2;
      final bodyPaint = Paint()..color = color..style = PaintingStyle.fill;

      canvas.drawLine(Offset(x, yFor(c.high)), Offset(x, yFor(c.low)), wickPaint);

      final top = yFor(isUp ? c.close : c.open);
      final bottom = yFor(isUp ? c.open : c.close);
      final rectTop = top;
      final rectHeight = (bottom - top).abs().clamp(1.0, double.infinity);
      canvas.drawRect(Rect.fromLTWH(x - bodyWidth / 2, rectTop, bodyWidth, rectHeight), bodyPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) => true;
}

class _PriceAxisPainter extends CustomPainter {
  final double minPrice, maxPrice;
  _PriceAxisPainter({required this.minPrice, required this.maxPrice});

  @override
  void paint(Canvas canvas, Size size) {
    const steps = 5;
    for (int i = 0; i <= steps; i++) {
      final price = minPrice + (maxPrice - minPrice) * (steps - i) / steps;
      final y = size.height * i / steps;
      final tp = TextPainter(
        text: TextSpan(text: price.toStringAsFixed(1), style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, (y - tp.height / 2).clamp(0, size.height - tp.height)));
    }
  }

  @override
  bool shouldRepaint(covariant _PriceAxisPainter oldDelegate) => true;
}

class _VolumeView extends StatelessWidget {
  final List<_Candle> candles;
  const _VolumeView({required this.candles});

  @override
  Widget build(BuildContext context) {
    final maxVol = candles.map((c) => c.volume).fold<double>(0, (a, b) => b > a ? b : a);
    return Container(
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: SizedBox(
          width: (candles.length * 10).toDouble().clamp(MediaQuery.of(context).size.width - 60, double.infinity),
          child: CustomPaint(
            painter: _VolumePainter(candles: candles, maxVol: maxVol == 0 ? 1 : maxVol),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _VolumePainter extends CustomPainter {
  final List<_Candle> candles;
  final double maxVol;
  _VolumePainter({required this.candles, required this.maxVol});

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / candles.length;
    final w = (barWidth * 0.6).clamp(1.5, 14.0);
    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final isUp = c.close >= c.open;
      final color = (isUp ? const Color(0xFF26A69A) : const Color(0xFFEF5350)).withOpacity(0.5);
      final h = (c.volume / maxVol) * size.height;
      final x = barWidth * i + barWidth / 2;
      canvas.drawRect(Rect.fromLTWH(x - w / 2, size.height - h, w, h), Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _VolumePainter oldDelegate) => true;
}