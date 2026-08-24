import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/shared/widgets/account_drawer.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/stock_detail/screens/stock_detail_screen.dart';
import 'package:stock_app/features/search/screens/search_screen.dart';
import 'package:stock_app/shared/widgets/empty_state.dart';
import 'package:stock_app/shared/widgets/error_state.dart';
import 'package:stock_app/core/theme/app_typography.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});
  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<dynamic> _watchlist = [];
  Map<String, String> _exchangeBySymbol = {};
  final Map<String, Map<String, dynamic>> _quotes = {};
  final Map<String, List<double>> _sparklines = {};
  bool _loading = true;
  String? _error;
  List<String> _listNames = ['My Watchlist'];
  String _selectedList = 'My Watchlist';
  bool _seedAttempted = false;

  static const List<String> _demoSymbols = ['HDFCBANK', 'INFY', 'TCS', 'ONGC', 'HINDUNILVR'];

  @override
  void initState() {
    super.initState();
    _loadListNames();
    _load().then((_) => _seedDemoStocksIfMissing());
    _loadExchanges();
  }

  Future<void> _loadExchanges() async {
    try {
      final stocks = await ApiService.getStocks();
      final map = <String, String>{};
      for (final s in stocks) {
        final symbol = s['symbol'];
        final exchange = s['exchange'];
        if (symbol != null && exchange != null) map[symbol] = exchange;
      }
      if (mounted) setState(() => _exchangeBySymbol = map);
    } catch (_) {}
  }

  Future<void> _loadListNames() async {
    try {
      final names = await ApiService.getWatchlistNames();
      final combined = List<String>.from(names);
      int n = 1;
      while (combined.length < 7) {
        final candidate = 'Watchlist $n';
        if (!combined.contains(candidate)) combined.add(candidate);
        n++;
        if (n > 50) break;
      }
      if (mounted) setState(() => _listNames = combined);
    } catch (_) {}
  }

  Future<void> _seedDemoStocksIfMissing() async {
    if (_seedAttempted) return;
    _seedAttempted = true;
    try {
      final existingSymbols = _watchlist.map((e) => (e['symbol'] ?? '').toString()).toSet();
      final missing = _demoSymbols.where((s) => !existingSymbols.contains(s)).toList();
      if (missing.isEmpty) return;

      final allStocks = await ApiService.getStocks();
      var addedAny = false;
      for (final symbol in missing) {
        final match = allStocks.firstWhere(
          (s) => (s['symbol'] ?? '').toString() == symbol,
          orElse: () => null,
        );
        if (match == null) continue;
        try {
          await ApiService.addToWatchlist(match['id'], listName: _selectedList);
          addedAny = true;
        } catch (_) {}
      }
      if (addedAny) await _load();
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

  // Bottom sheet list-switcher, opened by tapping the "My Watchlist v" title.
  void _showListSwitcher() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Switch Watchlist', style: AppTypography.titleMedium),
            ),
            ..._listNames.map((name) {
              final isActive = name == _selectedList;
              return ListTile(
                leading: Icon(Icons.list_alt, color: isActive ? AppColors.primary : AppColors.textMuted),
                title: Text(name, style: TextStyle(color: isActive ? AppColors.primary : AppColors.textPrimary, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
                trailing: isActive ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (!isActive) {
                    setState(() => _selectedList = name);
                    _load();
                  }
                },
              );
            }),
            const Divider(height: 1, color: AppColors.border),
            ListTile(
              leading: const Icon(Icons.add, color: AppColors.primary),
              title: const Text('New Watchlist', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _createNewList();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
          final intraday = await ApiService.getIntraday(symbol, '15m');
          final closes = intraday
              .map((p) => (p['close'] as num?)?.toDouble() ?? (p['price'] as num?)?.toDouble())
              .whereType<double>()
              .toList();
          if (mounted && closes.isNotEmpty) setState(() => _sparklines[symbol] = closes);
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
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(item['symbol'] ?? '', style: AppTypography.titleMedium),
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

  // ===== IBKR-style app bar: "My Watchlist v"  ...  [+]  [more] =====
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      automaticallyImplyLeading: false,
      leadingWidth: 40,
      leading: Builder(
        builder: (ctx) => IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.menu, color: AppColors.textPrimary),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      titleSpacing: 4,
      title: GestureDetector(
        onTap: _showListSwitcher,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_selectedList, style: AppTypography.titleLarge),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary, size: 22),
          ],
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.add, color: AppColors.textPrimary), onPressed: _addStock),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz, color: AppColors.textPrimary),
          onSelected: (v) {
            if (v == 'new_list') _createNewList();
            if (v == 'switch_list') _showListSwitcher();
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'new_list', child: Text('New Watchlist')),
            PopupMenuItem(value: 'switch_list', child: Text('Switch Watchlist')),
          ],
        ),
      ],
    );
  }

  // ===== Column header row: Instrument | Last | Chg % =====
  Widget _buildColumnHeader() {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Expanded(
            child: Text('Instrument', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          ),
          SizedBox(
            width: 56,
            child: Text('Intraday', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          ),
          SizedBox(
            width: 92,
            child: Text('Change', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(dynamic item) {
    final symbol = item['symbol'];
    final quote = _quotes[symbol];
    final price = quote != null ? (quote['price'] as num?)?.toDouble() : null;
    final changePercent = quote != null ? (quote['change_percent'] as num?)?.toDouble() : null;
    final change = quote != null ? (quote['change'] as num?)?.toDouble() : null;
    final exchange = _exchangeBySymbol[symbol] ?? item['exchange'] ?? '';
    final isUp = (changePercent ?? 0) >= 0;
    final color = isUp ? AppColors.success : AppColors.danger;
    final spark = _sparklines[symbol];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StockDetailScreen(stock: {
            'id': item['stock_id'] ?? item['id'],
            'symbol': item['symbol'],
            'company_name': item['company_name'],
            'exchange': _exchangeBySymbol[item['symbol']] ?? item['exchange'] ?? '',
            'sector': item['sector'] ?? '',
          }),
        ),
      ).then((_) => _load()),
      onLongPress: () => _showStockOptions(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(item['symbol'] ?? '', style: AppTypography.priceMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (exchange.toString().isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(exchange.toString(), style: AppTypography.caption),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['company_name'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySecondary,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 56,
              height: 30,
              child: (spark == null || spark.length < 2)
                  ? const SizedBox.shrink()
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData: const LineTouchData(enabled: false),
                        minY: spark.reduce((a, b) => a < b ? a : b),
                        maxY: spark.reduce((a, b) => a > b ? a : b),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [for (var i = 0; i < spark.length; i++) FlSpot(i.toDouble(), spark[i])],
                            isCurved: false,
                            color: color,
                            barWidth: 1.3,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: price == null
                  ? const Text('--', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textMuted, fontSize: 13))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            '${isUp ? '+' : ''}${changePercent?.toStringAsFixed(2) ?? '0.00'}%',
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${price.toStringAsFixed(2)}${change != null ? ' (${isUp ? '+' : ''}${change.toStringAsFixed(2)})' : ''}',
                          style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainShell(
      currentIndex: 0,
      child: Scaffold(
        backgroundColor: AppColors.background,
        drawer: const AccountDrawer(),
        appBar: _buildAppBar(),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.cardBackground,
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : _watchlist.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 80),
                              EmptyState(
                                icon: Icons.bookmark_border,
                                message: "Your watchlist is empty.\nAdd stocks to track them here.",
                                actionLabel: 'Add Stock',
                                onAction: _addStock,
                              ),
                            ],
                          )
                        : ListView(
                            children: [
                              _buildColumnHeader(),
                              ..._watchlist.map(_buildRow),
                              const SizedBox(height: 80),
                            ],
                          ),
          ),
        ),
      ),
    );
  }
}