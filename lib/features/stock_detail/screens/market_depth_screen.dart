import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/stock_detail/screens/option_chain_screen.dart';

class MarketDepthScreen extends StatefulWidget {
  final Map<String, dynamic> stock;
  const MarketDepthScreen({super.key, required this.stock});

  @override
  State<MarketDepthScreen> createState() => _MarketDepthScreenState();
}

class _MarketDepthScreenState extends State<MarketDepthScreen> {
  Map<String, dynamic>? _quote;
  List<dynamic> _history = [];
  bool _loading = true;
  String? _error;
  bool _aggregated = false;
  int _tab = 0; // 0=Book, 1=Option Chains

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final symbol = widget.stock['symbol'];
      final results = await Future.wait([
        ApiService.getQuote(symbol),
        ApiService.getHistory(symbol).catchError((_) => []),
      ]);
      setState(() {
        _quote = results[0] as Map<String, dynamic>;
        _history = results[1] as List<dynamic>;
      });
    } catch (e) {
      setState(() => _error = 'Depth data unavailable right now');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stock = widget.stock;
    final price = _quote?['price'] != null ? (_quote!['price'] as num).toDouble() : null;
    final change = _quote?['change'] != null ? (_quote!['change'] as num).toDouble() : null;
    final changePercent = _quote?['change_percent'] != null ? (_quote!['change_percent'] as num).toDouble() : null;
    final isUp = (changePercent ?? 0) >= 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stock['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${stock['company_name'] ?? ''} - ${stock['exchange'] ?? 'NSE'}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.search, color: AppColors.textMuted), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.add, color: AppColors.textMuted), onPressed: _load),
                ],
              ),
            ),
            if (!_loading && price != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('₹${price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text(
                      '${change != null ? (isUp ? '+' : '') + change.toStringAsFixed(2) : '--'} (${isUp ? '+' : ''}${changePercent?.toStringAsFixed(2) ?? '0.00'}%)',
                      style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
              child: Row(
                children: [
                  _tabItem('Book', 0),
                  const SizedBox(width: 24),
                  _tabItem('Option Chains', 1),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)))
                      : _tab == 0
                          ? _buildBookTab()
                          : OptionChainScreen(stock: stock),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabItem(String label, int index) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? AppColors.primary : Colors.transparent, width: 2))),
        child: Text(label, style: TextStyle(color: active ? AppColors.primaryDark : AppColors.textSecondary, fontSize: 14, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
      ),
    );
  }

  List<Map<String, num>> _levels(List<dynamic> raw) {
    final levels = raw.map((l) => {
          'price': (l['price'] as num),
          'quantity': (l['quantity'] as num),
          'orders': (l['orders'] as num?) ?? 0,
        }).toList();
    if (!_aggregated) return levels;
    // Aggregated view: collapse levels that round to the same price.
    final Map<double, Map<String, num>> merged = {};
    for (final l in levels) {
      final key = (l['price'] as num).toDouble();
      if (merged.containsKey(key)) {
        merged[key]!['quantity'] = (merged[key]!['quantity'] as num) + l['quantity']!;
        merged[key]!['orders'] = (merged[key]!['orders'] as num) + l['orders']!;
      } else {
        merged[key] = Map.of(l);
      }
    }
    return merged.values.toList();
  }

  Widget _buildBookTab() {
    final depth = _quote?['depth'] as Map<String, dynamic>?;
    final depthBuy = _levels((depth?['buy'] as List<dynamic>?) ?? []);
    final depthSell = _levels((depth?['sell'] as List<dynamic>?) ?? []);

    if (depthBuy.isEmpty && depthSell.isEmpty) {
      return const Center(child: Text('No order book data for this stock', style: TextStyle(color: AppColors.textMuted, fontSize: 13)));
    }

    double maxQty = 1;
    for (final l in [...depthBuy, ...depthSell]) {
      final q = (l['quantity'] as num).toDouble();
      if (q > maxQty) maxQty = q;
    }
    num totalBuy = depthBuy.fold(0, (s, l) => s + (l['quantity'] as num));
    num totalSell = depthSell.fold(0, (s, l) => s + (l['quantity'] as num));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Full Depth / Aggregated toggle
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _aggregated = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: !_aggregated ? AppColors.primary : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text('Full Depth', textAlign: TextAlign.center, style: TextStyle(color: !_aggregated ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _aggregated = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _aggregated ? AppColors.primary : AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text('Aggregated', textAlign: TextAlign.center, style: TextStyle(color: _aggregated ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Column headers
        const Row(children: [
          Expanded(child: Row(children: [
            Expanded(child: Text('Bid', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
            SizedBox(width: 30, child: Text('Ord', textAlign: TextAlign.end, style: TextStyle(color: AppColors.textMuted, fontSize: 10))),
            SizedBox(width: 56, child: Text('Size', textAlign: TextAlign.end, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
          ])),
          SizedBox(width: 10),
          Expanded(child: Row(children: [
            SizedBox(width: 56, child: Text('Size', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
            SizedBox(width: 30, child: Text('Ord', textAlign: TextAlign.end, style: TextStyle(color: AppColors.textMuted, fontSize: 10))),
            Expanded(child: Text('Ask', textAlign: TextAlign.end, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
          ])),
        ]),
        const SizedBox(height: 6),

        for (int i = 0; i < (depthBuy.length > depthSell.length ? depthBuy.length : depthSell.length); i++)
          _depthRow(
            bidPrice: i < depthBuy.length ? (depthBuy[i]['price'] as num).toStringAsFixed(2) : '',
            bidOrders: i < depthBuy.length ? '${depthBuy[i]['orders']}' : '',
            bidQty: i < depthBuy.length ? '${depthBuy[i]['quantity']}' : '',
            askPrice: i < depthSell.length ? (depthSell[i]['price'] as num).toStringAsFixed(2) : '',
            askOrders: i < depthSell.length ? '${depthSell[i]['orders']}' : '',
            askQty: i < depthSell.length ? '${depthSell[i]['quantity']}' : '',
            bidFrac: i < depthBuy.length ? ((depthBuy[i]['quantity'] as num).toDouble() / maxQty) : 0,
            askFrac: i < depthSell.length ? ((depthSell[i]['quantity'] as num).toDouble() / maxQty) : 0,
          ),

        const Divider(color: AppColors.border, height: 20),
        Row(children: [
          Expanded(child: Row(children: [
            const Expanded(child: Text('Total', style: TextStyle(color: AppColors.primary, fontSize: 12))),
            Text(NumberFormat('#,##,###').format(totalBuy), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Row(children: [
            const Expanded(child: Text('Total', style: TextStyle(color: AppColors.danger, fontSize: 12))),
            Text(NumberFormat('#,##,###').format(totalSell), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 12)),
          ])),
        ]),

        if (_history.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('Recent Price Trend', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(height: 140, child: _miniTrendChart()),
        ],
      ],
    );
  }

  Widget _miniTrendChart() {
    final closes = _history
        .map((p) => (p['close'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    final recent = closes.length > 20 ? closes.sublist(closes.length - 20) : closes;
    if (recent.length < 2) return const SizedBox();
    final spots = [for (int i = 0; i < recent.length; i++) FlSpot(i.toDouble(), recent[i])];
    final minY = recent.reduce((a, b) => a < b ? a : b);
    final maxY = recent.reduce((a, b) => a > b ? a : b);
    final isUp = recent.last >= recent.first;
    final color = isUp ? AppColors.success : AppColors.danger;
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        minY: minY == maxY ? minY - 1 : minY,
        maxY: minY == maxY ? maxY + 1 : maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _depthRow({
    required String bidPrice,
    required String bidOrders,
    required String bidQty,
    required String askPrice,
    required String askOrders,
    required String askQty,
    required double bidFrac,
    required double askFrac,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: FractionallySizedBox(alignment: Alignment.centerRight, widthFactor: bidFrac.clamp(0.0, 1.0), child: Container(color: AppColors.success.withValues(alpha: 0.10)))),
                Row(children: [
                  Expanded(child: Text(bidPrice, style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600))),
                  SizedBox(width: 30, child: Text(bidOrders, textAlign: TextAlign.end, style: const TextStyle(color: AppColors.textMuted, fontSize: 11))),
                  SizedBox(width: 56, child: Text(bidQty, textAlign: TextAlign.end, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: askFrac.clamp(0.0, 1.0), child: Container(color: AppColors.danger.withValues(alpha: 0.10)))),
                Row(children: [
                  SizedBox(width: 56, child: Text(askQty, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                  SizedBox(width: 30, child: Text(askOrders, textAlign: TextAlign.end, style: const TextStyle(color: AppColors.textMuted, fontSize: 11))),
                  Expanded(child: Text(askPrice, textAlign: TextAlign.end, style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
