import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class FundamentalsScreen extends StatefulWidget {
  final Map<String, dynamic> stock;
  const FundamentalsScreen({super.key, required this.stock});

  @override
  State<FundamentalsScreen> createState() => _FundamentalsScreenState();
}

class _FundamentalsScreenState extends State<FundamentalsScreen> {
  bool _loading = true;
  String? _about;
  List<dynamic> _history = [];
  Map<String, dynamic>? _quote;
  String _period = '1Y';
  bool _descExpanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final symbol = widget.stock['symbol'];
    try {
      final results = await Future.wait([
        ApiService.getQuote(symbol),
        ApiService.getHistory(symbol),
        ApiService.getAbout(symbol),
      ], eagerError: false);
      if (mounted) {
        setState(() {
          _quote = results[0] as Map<String, dynamic>?;
          _history = (results[1] as List<dynamic>?) ?? [];
          _about = results[2] as String?;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? get _fiftyTwoWeekHigh {
    if (_history.isEmpty) return null;
    double? high;
    for (final h in _history) {
      final v = (h['high'] as num?)?.toDouble();
      if (v != null && (high == null || v > high)) high = v;
    }
    return high;
  }

  double? get _fiftyTwoWeekLow {
    if (_history.isEmpty) return null;
    double? low;
    for (final h in _history) {
      final v = (h['low'] as num?)?.toDouble();
      if (v != null && (low == null || v < low)) low = v;
    }
    return low;
  }

  List<dynamic> get _filteredHistory {
    if (_history.isEmpty) return [];
    final now = DateTime.parse(_history.last['date'].toString());
    DateTime cutoff;
    switch (_period) {
      case 'YTD':
        cutoff = DateTime(now.year, 1, 1);
        break;
      case '1M':
        cutoff = now.subtract(const Duration(days: 30));
        break;
      case '1Y':
      default:
        cutoff = now.subtract(const Duration(days: 365));
    }
    return _history.where((h) => DateTime.parse(h['date'].toString()).isAfter(cutoff)).toList();
  }

  double? get _periodChangePercent {
    final list = _filteredHistory;
    if (list.length < 2) return null;
    final first = (list.first['close'] as num?)?.toDouble();
    final last = (list.last['close'] as num?)?.toDouble();
    if (first == null || last == null || first == 0) return null;
    return ((last - first) / first) * 100;
  }

  Widget _statCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final symbol = widget.stock['symbol'] ?? '';
    final sector = widget.stock['sector'] ?? '';
    final price = _quote != null ? (_quote!['price'] as num?)?.toDouble() : null;
    final changePercent = _quote != null ? (_quote!['change_percent'] as num?)?.toDouble() : null;
    final isUp = (changePercent ?? 0) >= 0;
    final high52 = _fiftyTwoWeekHigh;
    final low52 = _fiftyTwoWeekLow;
    final periodChange = _periodChangePercent;
    final periodIsUp = (periodChange ?? 0) >= 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: const Text('Fundamentals', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(symbol, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
                  if (sector.toString().isNotEmpty)
                    Text(sector, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  const SizedBox(height: 6),
                  if (price != null)
                    Row(
                      children: [
                        Text(price.toStringAsFixed(2), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(width: 8),
                        Text('(${isUp ? '+' : ''}${changePercent?.toStringAsFixed(2) ?? '0.00'}%)', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  const SizedBox(height: 20),
                  if (_about != null && _about!.isNotEmpty) ...[
                    Text(
                      _about!,
                      maxLines: _descExpanded ? null : 3,
                      overflow: _descExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _descExpanded = !_descExpanded),
                      child: Text(_descExpanded ? 'Show less' : 'Read More', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                    const Divider(height: 28, color: AppColors.border),
                  ],
                  if (high52 != null && low52 != null) ...[
                    Row(
                      children: [
                        _statCell('52W Low', low52.toStringAsFixed(2)),
                        _statCell('52W High', high52.toStringAsFixed(2)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (price != null)
                      LayoutBuilder(builder: (context, constraints) {
                        final range = high52 - low52;
                        final frac = range > 0 ? ((price - low52) / range).clamp(0.0, 1.0) : 0.5;
                        return Stack(
                          children: [
                            Container(height: 4, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.danger, Color(0xFFF59E0B), AppColors.success]), borderRadius: BorderRadius.circular(2))),
                            Positioned(
                              left: (constraints.maxWidth - 10) * frac,
                              top: -4,
                              child: const Icon(Icons.arrow_drop_up, color: AppColors.textPrimary, size: 20),
                            ),
                          ],
                        );
                      }),
                    const Divider(height: 28, color: AppColors.border),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['YTD', '1M', '1Y'].map((p) {
                      final selected = _period == p;
                      return GestureDetector(
                        onTap: () => setState(() => _period = p),
                        child: Column(
                          children: [
                            Text(p, style: TextStyle(color: selected ? AppColors.primary : AppColors.textMuted, fontWeight: selected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                            if (selected) Container(margin: const EdgeInsets.only(top: 4), height: 2, width: 24, color: AppColors.primary),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  if (periodChange != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('${periodIsUp ? '+' : ''}${periodChange.toStringAsFixed(2)}% ($_period)', style: TextStyle(color: periodIsUp ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  if (_filteredHistory.length < 2)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: Text('Not enough data for this range', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                    )
                  else
                    SizedBox(
                      height: 220,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineTouchData: const LineTouchData(enabled: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: [
                                for (int i = 0; i < _filteredHistory.length; i++)
                                  FlSpot(i.toDouble(), (_filteredHistory[i]['close'] as num).toDouble()),
                              ],
                              isCurved: true,
                              color: periodIsUp ? AppColors.success : AppColors.danger,
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(show: true, color: (periodIsUp ? AppColors.success : AppColors.danger).withOpacity(0.08)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
