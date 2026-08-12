import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});
  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  List<dynamic> _allStocks = [];
  Map<String, dynamic>? _stockA;
  Map<String, dynamic>? _stockB;
  Map<String, dynamic>? _quoteA;
  Map<String, dynamic>? _quoteB;
  bool _loadingA = false;
  bool _loadingB = false;
  List<dynamic> _historyA = [];
  List<dynamic> _historyB = [];

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  Future<void> _loadStocks() async {
    try {
      final stocks = await ApiService.getStocks();
      setState(() => _allStocks = stocks);
    } catch (_) {}
  }

  Future<void> _pickStock(bool isA) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _StockPickerSheet(stocks: _allStocks),
    );

    if (selected == null) return;

    setState(() {
      if (isA) {
        _stockA = selected;
        _loadingA = true;
      } else {
        _stockB = selected;
        _loadingB = true;
      }
    });

    try {
      final quote = await ApiService.getQuote(selected['symbol']);
      final history = await ApiService.getHistory(selected['symbol']);
      setState(() {
        if (isA) {
          _quoteA = quote;
          _historyA = history;
        } else {
          _quoteB = quote;
          _historyB = history;
        }
      });
    } catch (_) {
      // ignore, will just show N/A
    } finally {
      setState(() {
        if (isA) {
          _loadingA = false;
        } else {
          _loadingB = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCompare = _stockA != null && _stockB != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Compare Stocks',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _StockSlot(
                      stock: _stockA,
                      loading: _loadingA,
                      placeholder: 'Select Stock A',
                      onTap: () => _pickStock(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.textPrimary),
                    child: const Center(
                      child: Text('VS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StockSlot(
                      stock: _stockB,
                      loading: _loadingB,
                      placeholder: 'Select Stock B',
                      onTap: () => _pickStock(false),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!canCompare)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.compare_arrows, color: AppColors.textMuted, size: 48),
                      const SizedBox(height: 12),
                      const Text('Select two stocks to compare', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (_historyA.isNotEmpty && _historyB.isNotEmpty)
                      _buildComparisonChart(),
                    if (_historyA.isNotEmpty && _historyB.isNotEmpty)
                      const SizedBox(height: 16),
                    _comparisonRow('Price', _fmtPrice(_quoteA), _fmtPrice(_quoteB)),
                    _comparisonRow('Change %', _fmtChange(_quoteA), _fmtChange(_quoteB),
                        highlightA: _isHigherChange(_quoteA, _quoteB),
                        highlightB: _isHigherChange(_quoteB, _quoteA)),
                    _comparisonRow('Volume', _fmtVolume(_quoteA), _fmtVolume(_quoteB)),
                    _comparisonRow('Prev. Close', _fmtPrevClose(_quoteA), _fmtPrevClose(_quoteB)),
                    _comparisonRow('Exchange', _stockA?['exchange'] ?? '-', _stockB?['exchange'] ?? '-'),
                    _comparisonRow('Sector', _stockA?['sector'] ?? '-', _stockB?['sector'] ?? '-'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmtPrice(Map<String, dynamic>? q) {
    if (q == null || q['price'] == null) return 'N/A';
    return '₹${(q['price'] as num).toStringAsFixed(2)}';
  }

  String _fmtChange(Map<String, dynamic>? q) {
    if (q == null || q['change_percent'] == null) return 'N/A';
    final v = (q['change_percent'] as num).toDouble();
    final sign = v >= 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(2)}%';
  }

  String _fmtVolume(Map<String, dynamic>? q) {
    if (q == null || q['volume'] == null) return 'N/A';
    final v = (q['volume'] as num).toInt();
    if (v == 0) return 'N/A';
    return v.toString();
  }

  String _fmtPrevClose(Map<String, dynamic>? q) {
    if (q == null || q['prev_close'] == null) return 'N/A';
    return '₹${(q['prev_close'] as num).toStringAsFixed(2)}';
  }

  bool _isHigherChange(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null || b == null || a['change_percent'] == null || b['change_percent'] == null) return false;
    return (a['change_percent'] as num) > (b['change_percent'] as num);
  }

  Widget _buildComparisonChart() {
    final lenA = _historyA.length;
    final lenB = _historyB.length;
    final len = lenA < lenB ? lenA : lenB;
    if (len < 2) return const SizedBox.shrink();

    final slicedA = _historyA.sublist(lenA - len);
    final slicedB = _historyB.sublist(lenB - len);

    final baseA = (slicedA.first['close'] as num?)?.toDouble() ?? 1;
    final baseB = (slicedB.first['close'] as num?)?.toDouble() ?? 1;

    final spotsA = <FlSpot>[];
    final spotsB = <FlSpot>[];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < len; i++) {
      final closeA = (slicedA[i]['close'] as num?)?.toDouble() ?? baseA;
      final closeB = (slicedB[i]['close'] as num?)?.toDouble() ?? baseB;
      final pctA = baseA > 0 ? ((closeA - baseA) / baseA) * 100 : 0.0;
      final pctB = baseB > 0 ? ((closeB - baseB) / baseB) * 100 : 0.0;
      spotsA.add(FlSpot(i.toDouble(), pctA));
      spotsB.add(FlSpot(i.toDouble(), pctB));
      if (pctA < minY) minY = pctA;
      if (pctB < minY) minY = pctB;
      if (pctA > maxY) maxY = pctA;
      if (pctB > maxY) maxY = pctB;
    }

    final padding = ((maxY - minY).abs() * 0.15).clamp(1.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _legendDot(AppColors.primary, _stockA?['symbol'] ?? 'A'),
              const SizedBox(width: 16),
              _legendDot(AppColors.danger, _stockB?['symbol'] ?? 'B'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minY - padding,
                maxY: maxY + padding,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ((maxY - minY).abs() / 4).clamp(0.5, double.infinity),
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
                      reservedSize: 48,
                      getTitlesWidget: (value, meta) {
                        if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            '${value.toStringAsFixed(1)}%',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
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
                      '${s.y.toStringAsFixed(2)}%',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    )).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spotsA,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: spotsB,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.danger,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _comparisonRow(String label, String valueA, String valueB, {bool highlightA = false, bool highlightB = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  valueA,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: highlightA ? AppColors.success : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  valueB,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: highlightB ? AppColors.success : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StockSlot extends StatelessWidget {
  final Map<String, dynamic>? stock;
  final bool loading;
  final String placeholder;
  final VoidCallback onTap;

  const _StockSlot({required this.stock, required this.loading, required this.placeholder, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: loading
            ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)))
            : stock == null
                ? Center(
                    child: Column(
                      children: [
                        const Icon(Icons.add_circle_outline, color: AppColors.textMuted, size: 22),
                        const SizedBox(height: 4),
                        Text(placeholder, style: const TextStyle(color: AppColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Text(stock!['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        stock!['company_name'] ?? '',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _StockPickerSheet extends StatefulWidget {
  final List<dynamic> stocks;
  const _StockPickerSheet({required this.stocks});

  @override
  State<_StockPickerSheet> createState() => _StockPickerSheetState();
}

class _StockPickerSheetState extends State<_StockPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.stocks
        : widget.stocks.where((s) {
            final symbol = (s['symbol'] ?? '').toString().toLowerCase();
            final name = (s['company_name'] ?? '').toString().toLowerCase();
            return symbol.contains(_query.toLowerCase()) || name.contains(_query.toLowerCase());
          }).toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search stock',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final s = filtered[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Text((s['symbol'] ?? '?').toString().substring(0, 1), style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(s['symbol'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(s['company_name'] ?? ''),
                  onTap: () => Navigator.pop(context, s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}