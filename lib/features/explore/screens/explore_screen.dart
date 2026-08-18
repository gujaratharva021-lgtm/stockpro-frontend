import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/constants/nifty_symbols.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/shared/widgets/account_drawer.dart';
import 'package:stock_app/shared/widgets/stock_logo.dart';
import 'package:stock_app/shared/widgets/price_change.dart';
import 'package:stock_app/features/stock_detail/screens/stock_detail_screen.dart';
import 'package:stock_app/features/search/screens/search_screen.dart';
import 'package:stock_app/features/news/screens/news_detail_screen.dart';
import 'package:stock_app/features/ipo/screens/ipo_detail_screen.dart';
import 'package:go_router/go_router.dart';

/// Real, published NSE sectoral groupings of the symbols already tracked in
/// [kNiftyWatchSymbols] -- not an arbitrary split. Used to derive genuine
/// (quote-backed) "Investment Themes" and "Performance By Sector" sections
/// instead of fabricating category data with no source.
const Map<String, List<String>> _kSectorGroups = {
  'Banking': ['HDFCBANK', 'ICICIBANK', 'SBIN', 'AXISBANK', 'KOTAKBANK', 'INDUSINDBK'],
  'IT': ['INFY', 'TCS', 'WIPRO', 'HCLTECH', 'TECHM', 'LTIM'],
  'Energy & Oil': ['RELIANCE', 'ONGC', 'IOC', 'BPCL', 'GAIL'],
  'FMCG': ['HINDUNILVR', 'ITC', 'NESTLEIND', 'BRITANNIA', 'DABUR', 'MARICO'],
  'Auto': ['TATAMOTORS', 'MARUTI', 'M&M', 'BAJAJ-AUTO', 'EICHERMOT', 'HEROMOTOCO'],
  'Pharma': ['SUNPHARMA', 'CIPLA', 'DRREDDY', 'LUPIN', 'AUROPHARMA', 'DIVISLAB'],
  'Metals & Mining': ['TATASTEEL', 'JSWSTEEL', 'HINDALCO', 'VEDL', 'NATIONALUM', 'COALINDIA'],
  'Infra & Cement': ['LT', 'ULTRACEMCO', 'GRASIM', 'SHREECEM', 'AMBUJACEM'],
  'Financial Services': ['BAJFINANCE', 'BAJAJFINSV', 'HDFCLIFE', 'SBILIFE', 'ICICIGI'],
  'Power & Utilities': ['NTPC', 'POWERGRID', 'TATAPOWER'],
  'Telecom': ['BHARTIARTL', 'IDEA'],
  'New Age Tech': ['ZOMATO', 'PAYTM', 'NYKAA', 'POLICYBZR'],
};

// Real Yahoo Finance index/crypto symbols, fetched the same way as the
// Dashboard's "World Indices" strip (client-side call, no fabricated
// numbers). Indian indices per the user's request; crypto is inherently a
// global market so USD pairs are used.
const List<Map<String, String>> _kWorldIndices = [
  {'label': 'NIFTY 50', 'yahoo': '^NSEI'},
  {'label': 'SENSEX', 'yahoo': '^BSESN'},
  {'label': 'BANK NIFTY', 'yahoo': '^NSEBANK'},
  {'label': 'NIFTY IT', 'yahoo': '^CNXIT'},
  {'label': 'NIFTY AUTO', 'yahoo': '^CNXAUTO'},
  {'label': 'NIFTY PHARMA', 'yahoo': '^CNXPHARMA'},
];

const List<Map<String, String>> _kCrypto = [
  {'symbol': 'BTC', 'name': 'Bitcoin', 'yahoo': 'BTC-USD'},
  {'symbol': 'ETH', 'name': 'Ethereum', 'yahoo': 'ETH-USD'},
  {'symbol': 'LTC', 'name': 'Litecoin', 'yahoo': 'LTC-USD'},
  {'symbol': 'BCH', 'name': 'Bitcoin Cash', 'yahoo': 'BCH-USD'},
  {'symbol': 'SOL', 'name': 'Solana', 'yahoo': 'SOL-USD'},
  {'symbol': 'ADA', 'name': 'Cardano', 'yahoo': 'ADA-USD'},
];

/// Market-overview style Explore screen: search, sector-based investment
/// themes, Most Active/Gainers/Losers/IPOs, a Stock Screener shortcut,
/// Indian world indices, sector performance, crypto, a Learn strip, and
/// news -- all backed by real API/Yahoo Finance calls where a real source
/// exists. Screens that have no dedicated tab live in the hamburger drawer.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<dynamic> _allStocks = [];
  final Map<String, Map<String, dynamic>> _quotes = {};
  List<dynamic> _ipos = [];
  List<dynamic> _news = [];
  List<String> _holdingSymbols = [];
  List<String> _watchlistSymbols = [];
  final Map<String, Map<String, dynamic>> _indices = {};
  final Map<String, Map<String, dynamic>> _crypto = {};

  String _stocksTab = 'active'; // active | gainers | losers | ipo
  String _newsTab = 'overview'; // overview | portfolio | watchlists
  bool _loadingStocks = true;
  bool _loadingNews = true;

  @override
  void initState() {
    super.initState();
    _loadStocks();
    _loadIpos();
    _loadNewsAndHoldings();
    _loadIndices();
    _loadCrypto();
  }

  Future<void> _loadStocks() async {
    try {
      final stocks = await ApiService.getStocks();
      if (mounted) setState(() => _allStocks = stocks);
      final tracked = stocks.where((s) => kNiftyWatchSymbols.contains(s['symbol'])).toList();
      for (final s in tracked) {
        final symbol = s['symbol'];
        try {
          final q = await ApiService.getQuote(symbol);
          if (mounted) setState(() => _quotes[symbol] = q);
        } catch (_) {}
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingStocks = false);
    }
  }

  Future<void> _loadIpos() async {
    try {
      final ipos = await ApiService.getIPOs();
      if (mounted) setState(() => _ipos = ipos);
    } catch (_) {}
  }

  Future<void> _loadNewsAndHoldings() async {
    try {
      final news = await ApiService.getNews();
      if (mounted) setState(() => _news = news);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingNews = false);
    }
    try {
      final holdings = await ApiService.getHoldings();
      if (mounted) setState(() => _holdingSymbols = holdings.map((h) => (h['symbol'] ?? '').toString()).toList());
    } catch (_) {}
    try {
      final watchlist = await ApiService.getWatchlist();
      if (mounted) setState(() => _watchlistSymbols = watchlist.map((w) => (w['symbol'] ?? '').toString()).toList());
    } catch (_) {}
  }

  Future<void> _loadIndices() async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 12)));
    for (final idx in _kWorldIndices) {
      try {
        final res = await dio.get('https://query1.finance.yahoo.com/v8/finance/chart/${idx['yahoo']}?interval=15m&range=1d');
        final meta = res.data['chart']['result'][0]['meta'];
        final price = (meta['regularMarketPrice'] as num).toDouble();
        final prevClose = (meta['previousClose'] as num? ?? meta['chartPreviousClose'] as num).toDouble();
        final percent = prevClose > 0 ? ((price - prevClose) / prevClose) * 100 : 0.0;
        if (mounted) {
          setState(() => _indices[idx['label']!] = {
                'value': price.toStringAsFixed(2),
                'percent': percent,
              });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadCrypto() async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 12)));
    for (final c in _kCrypto) {
      try {
        final res = await dio.get('https://query1.finance.yahoo.com/v8/finance/chart/${c['yahoo']}?interval=15m&range=1d');
        final meta = res.data['chart']['result'][0]['meta'];
        final price = (meta['regularMarketPrice'] as num).toDouble();
        final prevClose = (meta['previousClose'] as num? ?? meta['chartPreviousClose'] as num).toDouble();
        final percent = prevClose > 0 ? ((price - prevClose) / prevClose) * 100 : 0.0;
        if (mounted) {
          setState(() => _crypto[c['symbol']!] = {
                'value': price >= 1 ? price.toStringAsFixed(2) : price.toStringAsFixed(4),
                'percent': percent,
              });
        }
      } catch (_) {}
    }
  }

  List<Map<String, dynamic>> get _quotedStocks {
    return _allStocks
        .where((s) => _quotes.containsKey(s['symbol']))
        .map((s) => {
              ...Map<String, dynamic>.from(s),
              'quote': _quotes[s['symbol']],
            })
        .toList()
        .cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> get _sortedStocksForTab {
    final list = List<Map<String, dynamic>>.from(_quotedStocks);
    double pct(Map<String, dynamic> s) => ((s['quote']?['change_percent'] as num?) ?? 0).toDouble();
    switch (_stocksTab) {
      case 'gainers':
        list.sort((a, b) => pct(b).compareTo(pct(a)));
        return list.where((s) => pct(s) > 0).take(12).toList();
      case 'losers':
        list.sort((a, b) => pct(a).compareTo(pct(b)));
        return list.where((s) => pct(s) < 0).take(12).toList();
      case 'active':
      default:
        list.sort((a, b) => pct(b).abs().compareTo(pct(a).abs()));
        return list.take(12).toList();
    }
  }

  List<dynamic> get _newsForTab {
    if (_newsTab == 'overview') return _news;
    final symbols = _newsTab == 'portfolio' ? _holdingSymbols : _watchlistSymbols;
    if (symbols.isEmpty) return [];
    return _news.where((n) {
      final text = '${n['title'] ?? ''} ${n['content'] ?? ''}'.toUpperCase();
      return symbols.any((s) => s.isNotEmpty && text.contains(s.toUpperCase()));
    }).toList();
  }

  void _showThemeSheet(String theme, List<String> symbols) {
    final rows = _quotedStocks.where((s) => symbols.contains(s['symbol'])).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(theme, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('Loading quotesâ€¦', style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: rows.length,
                      itemBuilder: (ctx, i) => _stockRow(rows[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openStock(Map<String, dynamic> stock) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StockDetailScreen(stock: stock)));
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label â€” coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return MainShell(
      currentIndex: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        drawer: const AccountDrawer(),
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: Builder(
            builder: (ctx) => IconButton(icon: const Icon(Icons.menu, color: AppColors.textPrimary), onPressed: () => Scaffold.of(ctx).openDrawer()),
          ),
          title: const Text('Explore', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary), onPressed: () => _comingSoon('Edit')),
            IconButton(icon: const Icon(Icons.smart_toy_outlined, color: AppColors.textPrimary), onPressed: () => context.push('/assistant')),
            IconButton(icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary), onPressed: () => context.push('/notifications')),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await Future.wait([_loadStocks(), _loadIpos(), _loadNewsAndHoldings(), _loadIndices(), _loadCrypto()]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: _searchBar()),
                _sectionHeader('Investment Themes'),
                _themesWrap(),
                const SizedBox(height: 8),
                _sectionHeader('Stocks'),
                _stocksTabs(),
                _stocksList(),
                Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: _screenerButton()),
                _sectionHeader('World Markets'),
                _worldMarketsGrid(),
                _sectionHeader('Performance By Sector'),
                _sectorGrid(),
                _sectionHeader('Cryptocurrencies'),
                _cryptoGrid(),
                _sectionHeader('Learn'),
                _learnStrip(),
                _sectionHeader('News'),
                _newsTabsRow(),
                _newsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {bool withInfo = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          if (withInfo) const Icon(Icons.info_outline, color: AppColors.textMuted, size: 18),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(24)),
        child: const Row(children: [
          Icon(Icons.search, color: AppColors.textMuted),
          SizedBox(width: 10),
          Text('Search Symbol', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
        ]),
      ),
    );
  }

  Widget _themesWrap() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _kSectorGroups.entries.map((e) {
          return OutlinedButton(
            onPressed: () => _showThemeSheet(e.key, e.value),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(e.key, style: const TextStyle(color: AppColors.primary, fontSize: 13)),
          );
        }).toList(),
      ),
    );
  }

  Widget _stocksTabs() {
    Widget tab(String label, String value) {
      final selected = _stocksTab == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _stocksTab = value),
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.cardBackground,
          labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
          side: BorderSide.none,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          tab('Most Active', 'active'),
          tab('Gainers', 'gainers'),
          tab('Losers', 'losers'),
          tab('IPOs', 'ipo'),
        ]),
      ),
    );
  }

  Widget _stocksList() {
    if (_stocksTab == 'ipo') {
      if (_ipos.isEmpty) {
        return const Padding(padding: EdgeInsets.all(16), child: Text('No IPOs to show right now', style: TextStyle(color: AppColors.textMuted)));
      }
      return Column(
        children: _ipos.take(8).map<Widget>((ipo) {
          final name = (ipo['company_name'] ?? '').toString();
          final priceLow = (ipo['price_band_low'] as num?)?.toDouble() ?? 0.0;
          final priceHigh = (ipo['price_band_high'] as num?)?.toDouble() ?? 0.0;
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IpoDetailScreen(ipoId: ipo['id']))),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(child: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13))),
                Text('₹${priceLow.toStringAsFixed(0)} - ₹${priceHigh.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ]),
            ),
          );
        }).toList(),
      );
    }

    if (_loadingStocks) {
      return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    final rows = _sortedStocksForTab;
    if (rows.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Text('No data to show', style: TextStyle(color: AppColors.textMuted)));
    }
    return Column(children: rows.map((s) => _stockRow(s)).toList());
  }

  Widget _stockRow(Map<String, dynamic> stock) {
    final quote = stock['quote'] as Map<String, dynamic>?;
    final price = (quote?['price'] as num?)?.toDouble();
    final change = (quote?['change'] as num?)?.toDouble() ?? 0.0;
    final changePercent = (quote?['change_percent'] as num?)?.toDouble() ?? 0.0;
    return InkWell(
      onTap: () => _openStock(stock),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          StockLogo(symbol: stock['symbol']?.toString(), companyName: stock['company_name']?.toString(), size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(stock['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
              if (price != null) Text('₹${price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
            ]),
          ),
          PriceChange(change: change, changePercent: changePercent, fontSize: 12),
        ]),
      ),
    );
  }

  Widget _screenerButton() {
    return OutlinedButton.icon(
      onPressed: () => context.push('/screener'),
      icon: const Icon(Icons.radar, color: AppColors.primary, size: 18),
      label: const Text('Stock Screener', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _worldMarketsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _kWorldIndices.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.6),
        itemBuilder: (ctx, i) {
          final label = _kWorldIndices[i]['label']!;
          final data = _indices[label];
          final percent = data != null ? (data['percent'] as num).toDouble() : null;
          final isDown = percent != null && percent < 0;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDown ? AppColors.danger.withValues(alpha: 0.12) : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDown ? AppColors.danger.withValues(alpha: 0.4) : AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(children: [
                if (percent != null) Icon(percent >= 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: percent >= 0 ? AppColors.success : AppColors.danger),
                const SizedBox(width: 4),
                Expanded(child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Text(
                data == null ? '--' : '${data['value']}  (${percent!.toStringAsFixed(2)}%)',
                style: TextStyle(color: percent == null ? AppColors.textMuted : (percent >= 0 ? AppColors.success : AppColors.danger), fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _sectorGrid() {
    final entries = _kSectorGroups.entries.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.0),
        itemBuilder: (ctx, i) {
          final label = entries[i].key;
          final symbols = entries[i].value;
          final quotes = symbols.map((s) => _quotes[s]).whereType<Map<String, dynamic>>().toList();
          double? avgPct;
          if (quotes.isNotEmpty) {
            final sum = quotes.fold<double>(0, (acc, q) => acc + ((q['change_percent'] as num?) ?? 0).toDouble());
            avgPct = sum / quotes.length;
          }
          final isUp = avgPct != null && avgPct >= 0;
          return InkWell(
            onTap: () => _showThemeSheet(label, symbols),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: avgPct == null ? AppColors.cardBackground : (isUp ? AppColors.success.withValues(alpha: 0.18) : AppColors.danger.withValues(alpha: 0.18)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.donut_small, size: 18, color: avgPct == null ? AppColors.textMuted : (isUp ? AppColors.success : AppColors.danger)),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 10.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(avgPct == null ? '--' : '${avgPct >= 0 ? '+' : ''}${avgPct.toStringAsFixed(2)}%', style: TextStyle(color: avgPct == null ? AppColors.textMuted : (isUp ? AppColors.success : AppColors.danger), fontSize: 10, fontWeight: FontWeight.bold)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _cryptoGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _kCrypto.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 3.2),
        itemBuilder: (ctx, i) {
          final symbol = _kCrypto[i]['symbol']!;
          final data = _crypto[symbol];
          final percent = data != null ? (data['percent'] as num).toDouble() : null;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              CircleAvatar(radius: 15, backgroundColor: AppColors.primary.withValues(alpha: 0.15), child: Text(symbol[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12))),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(symbol, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  Text(
                    data == null ? '--' : '\$${data['value']}',
                    style: TextStyle(color: percent == null ? AppColors.textMuted : (percent >= 0 ? AppColors.success : AppColors.danger), fontSize: 11),
                  ),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _learnStrip() {
    final items = [
      ('AI Assistant', Icons.smart_toy_outlined, '/assistant'),
      ('Brokerage Calculator', Icons.calculate_outlined, '/brokerage-calculator'),
      ('Stock Screener', Icons.filter_alt_outlined, '/screener'),
      ('Performance', Icons.trending_up, '/performance'),
    ];
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final (label, icon, route) = items[i];
          return InkWell(
            onTap: () => context.push(route),
            child: Container(
              width: 140,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Icon(icon, color: Colors.white, size: 22),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _newsTabsRow() {
    Widget tab(String label, String value) {
      final selected = _newsTab == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _newsTab = value),
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.cardBackground,
          labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
          side: BorderSide.none,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [tab('Overview', 'overview'), tab('Portfolio', 'portfolio'), tab('Watchlists', 'watchlists')]),
    );
  }

  Widget _newsList() {
    if (_loadingNews) {
      return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    final items = _newsForTab;
    if (items.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Text('No news to show', style: TextStyle(color: AppColors.textMuted)));
    }
    return Column(
      children: items.take(10).map<Widget>((item) {
        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailScreen(item: item))),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Row(children: [
                Text(item['source'] ?? '', style: const TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text((item['published_at'] ?? '').toString().split('T').first, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ]),
            ]),
          ),
        );
      }).toList(),
    );
  }
}