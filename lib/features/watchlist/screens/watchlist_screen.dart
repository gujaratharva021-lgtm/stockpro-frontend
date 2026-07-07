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
  static const Color _kiteBlue = Color(0xFF387ED1);

  List<dynamic> _watchlist = [];
  Map<String, Map<String, dynamic>> _quotes = {};
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

  // ===== Combined gray header + floating search bar + "New group" link =====
  // These were three separate SliverToBoxAdapter widgets, shifted up with
  // Transform.translate. Transform only moves the *paint*, not the layout
  // box, so the shifted content could get clipped against neighbouring
  // slivers -> that's the cropped search bar. Fix: build the whole block as
  // one Stack in a single sliver, positioned properly, nothing to clip.
  Widget _buildHeaderBlock() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          color: const Color(0xFFF0F1F3),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Watchlist',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary, size: 26),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _listNames.map((name) {
                          final isActive = name == _selectedList;
                          return Padding(
                            padding: const EdgeInsets.only(right: 24),
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedList = name);
                                _load();
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: isActive ? _kiteBlue : AppColors.textMuted,
                                      fontSize: 15,
                                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (isActive)
                                    Container(width: name.length * 8.0 + 4, height: 2, color: _kiteBlue),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _createNewList,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _kiteBlue.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.layers_outlined, color: _kiteBlue, size: 16),
                          Positioned(
                            bottom: 5,
                            right: 5,
                            child: Icon(Icons.add, color: _kiteBlue, size: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Floating white search bar — overlaps the gray/white boundary.
        Positioned(
          left: 16,
          right: 16,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.textMuted, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _addStock,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Search & add', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                    ),
                  ),
                ),
                Text('${_watchlist.length}/250', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(width: 10),
                const Icon(Icons.tune, color: AppColors.textPrimary, size: 20),
              ],
            ),
          ),
        ),

        // "+ New group" link — sits just below the search bar, still overlapping.
        Positioned(
          right: 16,
          bottom: -28,
          child: GestureDetector(
            onTap: _createNewList,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.add, color: _kiteBlue, size: 18),
                SizedBox(width: 4),
                Text('New group', style: TextStyle(color: _kiteBlue, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainShell(
      currentIndex: 0,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        onPressed: _addStock,
        child: const Icon(Icons.trending_up, color: AppColors.textPrimary),
      ),
      child: SafeArea(
        child: RefreshIndicator(
          color: _kiteBlue,
          backgroundColor: Colors.white,
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              // ===== Gray header + floating search bar + New group link (combined) =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: _buildHeaderBlock(),
                ),
              ),

              // ===== Stock rows (flat, no cards) =====
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: _kiteBlue)),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary))),
                )
              else if (_watchlist.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bookmark_border, color: AppColors.textMuted, size: 48),
                        const SizedBox(height: 12),
                        const Text('Your watchlist is empty', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('Add stocks to track them here', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _addStock,
                          style: ElevatedButton.styleFrom(backgroundColor: _kiteBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          icon: const Icon(Icons.add, color: Colors.white, size: 18),
                          label: const Text('Add Stock', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _watchlist[index];
                      final symbol = item['symbol'];
                      final quote = _quotes[symbol];
                      final price = quote != null ? (quote['price'] as num).toDouble() : null;
                      final changePercent = quote != null ? (quote['change_percent'] as num).toDouble() : null;
                      final change = quote != null ? (quote['change'] as num?)?.toDouble() : null;
                      final isUp = (changePercent ?? 0) >= 0;
                      final hasEvent = item['has_event'] == true;

                      return GestureDetector(
                        onTap: () => showStockQuoteSheet(context, {
                          'id': item['stock_id'] ?? item['id'],
                          'symbol': item['symbol'],
                          'company_name': item['company_name'],
                          'exchange': item['exchange'] ?? '',
                          'sector': item['sector'] ?? '',
                        }).then((_) => _load()),
                        onLongPress: () => _showStockOptions(item),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['symbol'] ?? '',
                                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.normal),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(item['exchange'] ?? 'NSE', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                        if (hasEvent) ...[
                                          const SizedBox(width: 8),
                                          const Text('EVENT', style: TextStyle(color: _kiteBlue, fontSize: 12, fontWeight: FontWeight.w600)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    price != null ? price.toStringAsFixed(2) : '--',
                                    style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    change != null
                                        ? '${isUp ? '+' : ''}${change.toStringAsFixed(2)} (${isUp ? '+' : ''}${changePercent?.toStringAsFixed(2) ?? '0.00'}%)'
                                        : '--',
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: _watchlist.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }
}
