import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/search/screens/search_screen.dart';
import 'package:stock_app/features/stock_detail/screens/stock_detail_screen.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});
  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  List<dynamic> _stocks = [];
  Map<String, Map<String, dynamic>> _quotes = {};
  bool _loading = true;
  String? _error;
  String _category = 'Explore';
  final List<String> _categories = ['Explore', 'Nifty 50', 'Banking', 'IT', 'Auto'];

  Map<String, dynamic> _nifty = {'value': '--', 'percent': '--', 'isUp': true};
  Map<String, dynamic> _sensex = {'value': '--', 'percent': '--', 'isUp': true};
  Map<String, dynamic> _bankNifty = {'value': '--', 'percent': '--', 'isUp': true};
  Map<String, List<double>> _indexSpots = {};

  @override
  void initState() {
    super.initState();
    _loadStocks();
    _loadIndices();
  }

  Future<void> _loadStocks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stocks = await ApiService.getStocks();
      setState(() => _stocks = stocks);
      for (final s in stocks) {
        final symbol = s['symbol'];
        if (symbol == null) continue;
        try {
          final quote = await ApiService.getQuote(symbol);
          if (mounted) setState(() => _quotes[symbol] = quote);
        } catch (_) {}
      }
    } catch (e) {
      setState(() => _error = 'Could not load stocks');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadIndices() async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 12)));

    Future<void> fetchIndex(String yahooSymbol, String key) async {
      try {
        final res = await dio.get('https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol?interval=15m&range=1d');
        final result = res.data['chart']['result'][0];
        final meta = result['meta'];
        final price = (meta['regularMarketPrice'] as num).toDouble();
        final prevClose = (meta['previousClose'] as num? ?? meta['chartPreviousClose'] as num).toDouble();
        final percent = prevClose > 0 ? ((price - prevClose) / prevClose) * 100 : 0.0;
        final closes = (result['indicators']['quote'][0]['close'] as List<dynamic>?)
            ?.where((c) => c != null)
            .map((c) => (c as num).toDouble())
            .toList() ??
            [];

        final data = {
          'value': price.toStringAsFixed(2),
          'percent': '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%',
          'isUp': percent >= 0,
        };
        if (mounted) {
          setState(() {
            if (key == 'nifty') _nifty = data;
            if (key == 'sensex') _sensex = data;
            if (key == 'banknifty') _bankNifty = data;
            _indexSpots[key] = closes;
          });
        }
      } catch (_) {}
    }

    await Future.wait([
      fetchIndex('%5ENSEI', 'nifty'),
      fetchIndex('%5EBSESN', 'sensex'),
      fetchIndex('%5ENSEBANK', 'banknifty'),
    ]);
  }

  List<dynamic> get _categoryFiltered {
    if (_category == 'Explore') return _stocks;
    return _stocks.where((s) {
      final sector = (s['sector'] ?? '').toString().toLowerCase();
      final symbol = (s['symbol'] ?? '').toString().toLowerCase();
      switch (_category) {
        case 'Nifty 50':
          return true; // no separate index-membership flag in backend; Explore tab already shows full list
        case 'Banking':
          return sector.contains('bank') || sector.contains('financial');
        case 'IT':
          return sector.contains('it') || sector.contains('technology') || sector.contains('software');
        case 'Auto':
          return sector.contains('auto') || sector.contains('motor');
        default:
          return true;
      }
    }).toList();
  }

  List<dynamic> get _gainers {
    final list = List<dynamic>.from(_categoryFiltered);
    list.sort((a, b) {
      final ap = (_quotes[a['symbol']]?['change_percent'] as num?)?.toDouble() ?? 0;
      final bp = (_quotes[b['symbol']]?['change_percent'] as num?)?.toDouble() ?? 0;
      return bp.compareTo(ap);
    });
    return list.take(5).toList();
  }

  List<dynamic> get _losers {
    final list = List<dynamic>.from(_categoryFiltered);
    list.sort((a, b) {
      final ap = (_quotes[a['symbol']]?['change_percent'] as num?)?.toDouble() ?? 0;
      final bp = (_quotes[b['symbol']]?['change_percent'] as num?)?.toDouble() ?? 0;
      return ap.compareTo(bp);
    });
    return list.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: Colors.white,
          onRefresh: () async {
            await _loadStocks();
            await _loadIndices();
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                      const Expanded(child: Text('Stocks', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18))),
                      IconButton(
                        icon: const Icon(Icons.search, color: AppColors.textPrimary),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                      ),
                      IconButton(icon: const Icon(Icons.tune, color: AppColors.textPrimary), onPressed: () {}),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _categories.map((c) {
                      final active = _category == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _category = c),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: active ? AppColors.primary : AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: active ? AppColors.primary : AppColors.border),
                            ),
                            child: Text(c, style: TextStyle(color: active ? Colors.white : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Market Indices', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                      GestureDetector(onTap: () {}, child: const Text('View All >', style: TextStyle(color: AppColors.primaryDark, fontSize: 12))),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 78,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _indexCard('NIFTY 50', _nifty, _indexSpots['nifty']),
                      const SizedBox(width: 10),
                      _indexCard('SENSEX', _sensex, _indexSpots['sensex']),
                      const SizedBox(width: 10),
                      _indexCard('BANK NIFTY', _bankNifty, _indexSpots['banknifty']),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              if (_loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              else if (_error != null)
                SliverFillRemaining(child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary))))
              else ...[
                  _sectionHeader('Top Gainers'),
                  SliverList(delegate: SliverChildBuilderDelegate((c, i) => _stockRow(_gainers[i]), childCount: _gainers.length)),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  _sectionHeader('Top Losers'),
                  SliverList(delegate: SliverChildBuilderDelegate((c, i) => _stockRow(_losers[i]), childCount: _losers.length)),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _sectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _indexCard(String label, Map<String, dynamic> data, List<double>? spots) {
    final isUp = data['isUp'] == true;
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(data['value'] ?? '--', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                Text(data['percent'] ?? '--', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (spots != null && spots.length > 1)
            SizedBox(
              width: 40,
              height: 36,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (int i = 0; i < spots.length; i++) FlSpot(i.toDouble(), spots[i])],
                      isCurved: true,
                      color: isUp ? AppColors.success : AppColors.danger,
                      barWidth: 1.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showQuickBuy(dynamic stock, double? price) {
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price not available right now')),
      );
      return;
    }
    int qty = 1;
    bool placing = false;
    String? error;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final total = qty * price;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(stock['company_name'] ?? stock['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('₹${price.toStringAsFixed(2)} / share', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close, color: AppColors.textPrimary), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('Quantity', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      InkWell(
                        onTap: () {
                          if (qty > 1) setModalState(() => qty--);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(width: 36, height: 36, decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.remove, size: 16, color: AppColors.primary)),
                      ),
                      Expanded(child: Center(child: Text('$qty', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)))),
                      InkWell(
                        onTap: () => setModalState(() => qty++),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(width: 36, height: 36, decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.add, size: 16, color: AppColors.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: placing
                          ? null
                          : () async {
                              setModalState(() {
                                placing = true;
                                error = null;
                              });
                              try {
                                await ApiService.placeOrder(stock['id'], 'BUY', qty, price);
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Bought $qty share(s) of ${stock['symbol'] ?? ''}')),
                                  );
                                  _loadStocks();
                                }
                              } catch (e) {
                                setModalState(() {
                                  placing = false;
                                  error = 'Order failed. Please try again';
                                });
                              }
                            },
                      child: placing
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Buy Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _stockRow(dynamic s) {
    final symbol = s['symbol'];
    final quote = _quotes[symbol];
    final price = quote != null ? (quote['price'] as num?)?.toDouble() : null;
    final changePercent = quote != null ? (quote['change_percent'] as num?)?.toDouble() ?? 0 : 0;
    final isUp = changePercent >= 0;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockDetailScreen(stock: s))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: (isUp ? AppColors.success : AppColors.danger).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text((symbol ?? '?').toString().substring(0, 1), style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontWeight: FontWeight.bold, fontSize: 14))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['company_name'] ?? symbol ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(symbol ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price != null ? '₹${price.toStringAsFixed(2)}' : '--', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                Row(
                  children: [
                    Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, color: isUp ? AppColors.success : AppColors.danger, size: 11),
                    Text('${changePercent.abs().toStringAsFixed(2)}%', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _showQuickBuy(s, price),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(8)),
                child: const Text('Buy', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}