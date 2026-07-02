import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/stock_detail/screens/stock_detail_screen.dart';
import 'package:stock_app/features/search/screens/search_screen.dart';
import 'package:stock_app/shared/widgets/stock_logo.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});
  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<dynamic> _watchlist = [];
  Map<String, Map<String, dynamic>> _quotes = {};
  Map<String, List<double>> _history = {};
  bool _loading = true;
  String? _error;
  List<String> _listNames = ['My Watchlist'];
  String _selectedList = 'My Watchlist';

  Map<String, dynamic> _nifty = {'value': '--', 'change': '--', 'percent': '--', 'isUp': true};
  Map<String, dynamic> _sensex = {'value': '--', 'change': '--', 'percent': '--', 'isUp': true};

  @override
  void initState() {
    super.initState();
    _loadListNames();
    _load();
    _loadIndices();
  }

  Future<void> _loadIndices() async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 12)));

    Future<Map<String, dynamic>> fetchIndex(String yahooSymbol) async {
      try {
        final res = await dio.get('https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol');
        final meta = res.data['chart']['result'][0]['meta'];
        final price = (meta['regularMarketPrice'] as num).toDouble();
        final prevClose = (meta['previousClose'] as num? ?? meta['chartPreviousClose'] as num).toDouble();
        final change = price - prevClose;
        final percent = prevClose > 0 ? (change / prevClose) * 100 : 0.0;
        return {
          'value': price.toStringAsFixed(2),
          'change': '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}',
          'percent': '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%',
          'isUp': change >= 0,
        };
      } catch (_) {
        return {'value': '--', 'change': '--', 'percent': '--', 'isUp': true};
      }
    }

    final nifty = await fetchIndex('%5ENSEI');
    final sensex = await fetchIndex('%5EBSESN');
    if (mounted) setState(() {
      _nifty = nifty;
      _sensex = sensex;
    });
  }

  Future<void> _loadListNames() async {
    try {
      final names = await ApiService.getWatchlistNames();
      if (mounted) setState(() => _listNames = names);
    } catch (_) {}
  }

  void _createNewList() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Watchlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Tech Stocks'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              setState(() {
                if (!_listNames.contains(name)) _listNames = [..._listNames, name];
                _selectedList = name;
              });
              _load();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getWatchlist(listName: _selectedList);
      setState(() => _watchlist = data);

      for (final item in data) {
        final symbol = item['symbol'];
        if (symbol == null) continue;
        try {
          final quote = await ApiService.getQuote(symbol);
          if (mounted) setState(() => _quotes[symbol] = quote);
        } catch (_) {}
        try {
          final history = await ApiService.getHistory(symbol);
          final closes = history
              .map((p) => (p['close'] as num?)?.toDouble())
              .whereType<double>()
              .toList();
          final recent = closes.length > 10 ? closes.sublist(closes.length - 10) : closes;
          if (mounted) setState(() => _history[symbol] = recent);
        } catch (_) {}
      }
    } catch (e) {
      setState(() => _error = 'Could not load watchlist');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addStock() async {
    final stock = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen(selectMode: true)),
    );
    if (stock != null && mounted) {
      try {
        await ApiService.addToWatchlist(stock['id'], listName: _selectedList);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add stock to watchlist')));
        }
      }
    }
  }

  void _showStockOptions(dynamic item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(item['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined, color: AppColors.textSecondary),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StockDetailScreen(stock: {
                      'id': item['stock_id'] ?? item['id'],
                      'symbol': item['symbol'],
                      'company_name': item['company_name'],
                      'exchange': item['exchange'] ?? '',
                      'sector': item['sector'] ?? '',
                    }),
                  ),
                ).then((_) => _load());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('Remove from watchlist', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(ctx);
                await ApiService.removeFromWatchlist(item['stock_id'] ?? item['id'], listName: _selectedList);
                _load();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sparkline(List<double>? closes, bool isUp) {
    if (closes == null || closes.length < 2) {
      return const SizedBox(width: 48, height: 28);
    }
    final spots = [for (int i = 0; i < closes.length; i++) FlSpot(i.toDouble(), closes[i])];
    final minY = closes.reduce((a, b) => a < b ? a : b);
    final maxY = closes.reduce((a, b) => a > b ? a : b);
    final color = isUp ? AppColors.success : AppColors.danger;
    return SizedBox(
      width: 48,
      height: 28,
      child: LineChart(
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
              barWidth: 1.6,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _indexCard(String label, Map<String, dynamic> data) {
    final isUp = data['isUp'] == true;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              children: [
                Flexible(child: Text(data['value'] ?? '--', style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${data['change'] ?? ''} (${data['percent'] ?? '--'})',
                    style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainShell(
      currentIndex: 1,
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: Colors.white,
          onRefresh: () async {
            await _load();
            await _loadIndices();
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Watchlist',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.search, color: AppColors.textPrimary),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: AppColors.textPrimary),
                            onPressed: _addStock,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                    children: [
                      ..._listNames.map((name) {
                        final isActive = name == _selectedList;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedList = name);
                              _load();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isActive ? AppColors.primary : AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
                              ),
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                                style: TextStyle(
                                  color: isActive ? Colors.white : AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      GestureDetector(
                        onTap: _createNewList,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add, size: 14, color: AppColors.primaryDark),
                              SizedBox(width: 4),
                              Text('New', style: TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _indexCard('NIFTY 50', _nifty),
                      const SizedBox(width: 10),
                      _indexCard('SENSEX', _sensex),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (_watchlist.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: const [
                        Expanded(flex: 3, child: Text('Stock', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                        Expanded(flex: 2, child: Text('Price', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                        SizedBox(width: 8),
                        Expanded(flex: 2, child: Text('% Change', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                        SizedBox(width: 36),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else if (_watchlist.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star_outline, color: AppColors.textMuted, size: 48),
                          const SizedBox(height: 12),
                          const Text('Your watchlist is empty', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                          const SizedBox(height: 4),
                          const Text('Add stocks to track them here', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _addStock,
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            icon: const Icon(Icons.add, color: Colors.white, size: 18),
                            label: const Text('Add Stock', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final item = _watchlist[index];
                          final symbol = item['symbol'];
                          final quote = _quotes[symbol];
                          final price = quote != null ? (quote['price'] as num).toDouble() : null;
                          final changePercent = quote != null ? (quote['change_percent'] as num).toDouble() : null;
                          final change = quote != null ? (quote['change'] as num?)?.toDouble() : null;
                          final isUp = (changePercent ?? 0) >= 0;

                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StockDetailScreen(stock: {
                                  'id': item['stock_id'] ?? item['id'],
                                  'symbol': item['symbol'],
                                  'company_name': item['company_name'],
                                  'exchange': item['exchange'] ?? '',
                                  'sector': item['sector'] ?? '',
                                }),
                              ),
                            ).then((_) => _load()),
                            onLongPress: () => _showStockOptions(item),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                              ),
                              child: Row(
                                children: [
                                  StockLogo(symbol: item['symbol']?.toString(), companyName: item['company_name']?.toString(), size: 34),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(item['symbol'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                                        Text(item['exchange'] ?? 'NSE', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 42, height: 28, child: _sparkline(_history[symbol], isUp)),
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 64,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(price != null ? '₹${price.toStringAsFixed(2)}' : '--', maxLines: 1, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                        ),
                                        if (change != null)
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text('${isUp ? '+' : ''}${change.toStringAsFixed(2)}', maxLines: 1, style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 10)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 54,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (isUp ? AppColors.success : AppColors.danger).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '${isUp ? '+' : ''}${changePercent?.toStringAsFixed(2) ?? '0.00'}%',
                                          maxLines: 1,
                                          style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 32,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.star, color: AppColors.primary, size: 18),
                                      onPressed: () async {
                                        await ApiService.removeFromWatchlist(item['stock_id'] ?? item['id'], listName: _selectedList);
                                        _load();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: _watchlist.length,
                      ),
                    ),
                  ),
              if (_watchlist.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: GestureDetector(
                      onTap: _addStock,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primary, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_circle_outline, color: AppColors.primaryDark, size: 18),
                            SizedBox(width: 6),
                            Text('Add Stock', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_watchlist.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Center(
                      child: Text(
                        'Long press on a stock to view options',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}