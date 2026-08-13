import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/stock_detail/screens/stock_detail_screen.dart';
import 'package:stock_app/features/stock_detail/screens/stock_quote_sheet.dart';
import 'package:stock_app/features/search/screens/search_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});
  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<dynamic> _watchlist = [];
  Map<String, String> _exchangeBySymbol = {};
  final Map<String, Map<String, dynamic>> _quotes = {};
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Switch Watchlist', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
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

  // ===== IBKR-style app bar: "My Watchlist v"  ...  [+]  [more] =====
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: GestureDetector(
        onTap: _showListSwitcher,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_selectedList, style: const TextStyle(color: AppColors.textPrimary, fontSize: 19, fontWeight: FontWeight.bold)),
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
      color: const Color(0xFFF7F8FA),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Expanded(
            child: Text('Instrument', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          ),
          SizedBox(
            width: 80,
            child: Text('Last', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          ),
          SizedBox(
            width: 72,
            child: Text('Chg %', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
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
    final isUp = (changePercent ?? 0) >= 0;
    final changeColor = isUp ? AppColors.success : AppColors.danger;

    return GestureDetector(
      onTap: () => showStockQuoteSheet(context, {
        'id': item['stock_id'] ?? item['id'],
        'symbol': item['symbol'],
        'company_name': item['company_name'],
        'exchange': _exchangeBySymbol[item['symbol']] ?? '',
        'sector': item['sector'] ?? '',
      }).then((_) => _load()),
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
                  Text(item['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    item['company_name'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                price != null ? price.toStringAsFixed(2) : '--',
                textAlign: TextAlign.right,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            SizedBox(
              width: 72,
              child: Text(
                changePercent != null ? '${isUp ? '+' : ''}${changePercent.toStringAsFixed(2)}%' : '--',
                textAlign: TextAlign.right,
                style: TextStyle(color: changeColor, fontSize: 13, fontWeight: FontWeight.w600),
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
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: Colors.white,
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)))
                    : _watchlist.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 80),
                              const Icon(Icons.bookmark_border, color: AppColors.textMuted, size: 48),
                              const SizedBox(height: 12),
                              const Center(child: Text('Your watchlist is empty', style: TextStyle(color: AppColors.textSecondary, fontSize: 14))),
                              const SizedBox(height: 4),
                              const Center(child: Text('Add stocks to track them here', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                              const SizedBox(height: 16),
                              Center(
                                child: ElevatedButton.icon(
                                  onPressed: _addStock,
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                                  label: const Text('Add Stock', style: TextStyle(color: Colors.white)),
                                ),
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
