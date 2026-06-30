import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/services/websocket_service.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/features/stock_detail/screens/stock_detail_screen.dart';
import 'package:stock_app/features/search/screens/search_screen.dart';
import 'package:stock_app/features/mutualfunds/screens/mutualfunds_screen.dart';
import 'package:stock_app/features/ipo/screens/ipo_screen.dart';
import 'package:stock_app/features/etf/screens/etf_screen.dart';
import 'package:stock_app/features/mtf/screens/mtf_screen.dart';
import 'package:stock_app/features/fd/screens/fd_screen.dart';
import 'package:stock_app/features/commodity/screens/commodity_screen.dart';
import 'package:stock_app/features/markets/screens/markets_screen.dart';
import 'package:dio/dio.dart';

const _bg = Color(0xFFF5F6FA);
const _card = Color(0xFFFFFFFF);
const _cardBorder = Color(0xFFE8EAF0);
const _accent = Color(0xFFF59E0B); // yellow (was green in mockup)
const _textPrimary = Color(0xFF111827);
const _textSub = Color(0xFF6B7280);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _stocks = [];
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _user;
  double _holdingsValue = 0;
  double _investedValue = 0;
  Map<String, dynamic> _livePrices = {};
  StreamSubscription? _priceSub;
  bool _balanceHidden = false;

  Map<String, dynamic> _nifty = {'value': '--', 'change': '--', 'percent': '--', 'isUp': true};
  Map<String, dynamic> _sensex = {'value': '--', 'change': '--', 'percent': '--', 'isUp': true};
  Map<String, dynamic> _bankNifty = {'value': '--', 'change': '--', 'percent': '--', 'isUp': true};
  int _selectedIndex = 0; // 0=NIFTY, 1=SENSEX, 2=BANK NIFTY

  String _chartRange = '1D';
  List<FlSpot> _chartSpots = [];
  bool _chartLoading = true;

  List<dynamic> _newsItems = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadIndices();
    _loadNews();
    _loadChartData();
    WebSocketService.connect();
    _priceSub = WebSocketService.priceStream.listen((quotes) {
      if (mounted) setState(() => _livePrices = quotes);
    });
  }

  @override
  void dispose() {
    _priceSub?.cancel();
    super.dispose();
  }

  String get _selectedYahooSymbol {
    switch (_selectedIndex) {
      case 1:
        return '%5EBSESN'; // SENSEX
      case 2:
        return '%5ENSEBANK'; // BANK NIFTY
      default:
        return '%5ENSEI'; // NIFTY 50
    }
  }

  Future<void> _loadChartData() async {
    setState(() => _chartLoading = true);
    final rangeMap = {
      '1D': {'interval': '5m', 'range': '1d'},
      '1W': {'interval': '30m', 'range': '5d'},
      '1M': {'interval': '1d', 'range': '1mo'},
      '1Y': {'interval': '1wk', 'range': '1y'},
      'ALL': {'interval': '1mo', 'range': '5y'},
    };
    final params = rangeMap[_chartRange]!;
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 15)));
      final res = await dio.get(
        'https://query1.finance.yahoo.com/v8/finance/chart/$_selectedYahooSymbol?interval=${params['interval']}&range=${params['range']}',
      );
      final result = res.data['chart']['result'][0];
      final closes = (result['indicators']['quote'][0]['close'] as List<dynamic>?) ?? [];
      final spots = <FlSpot>[];
      for (int i = 0; i < closes.length; i++) {
        if (closes[i] == null) continue;
        spots.add(FlSpot(i.toDouble(), (closes[i] as num).toDouble()));
      }
      if (mounted) setState(() => _chartSpots = spots);
    } catch (e) {
      debugPrint('CHART LOAD ERROR: $e');
      if (mounted) setState(() => _chartSpots = []);
    } finally {
      if (mounted) setState(() => _chartLoading = false);
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stocks = await ApiService.getStocks();
      final me = await ApiService.getMe();
      final holdings = await ApiService.getHoldings();
      double holdingsValue = 0, investedValue = 0;
      for (final h in holdings) {
        final qty = (h['quantity'] as num).toDouble();
        final avgPrice = (h['avg_price'] as num).toDouble();
        investedValue += qty * avgPrice;
        try {
          final quote = await ApiService.getQuote(h['symbol']);
          holdingsValue += qty * (quote['price'] as num).toDouble();
        } catch (_) {
          holdingsValue += qty * avgPrice;
        }
      }
      setState(() {
        _stocks = stocks;
        _user = me['user'];
        _holdingsValue = holdingsValue;
        _investedValue = investedValue;
      });
    } catch (e) {
      setState(() => _error = 'Could not load data.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadNews() async {
    try {
      final news = await ApiService.getNews();
      if (mounted) setState(() => _newsItems = news.take(3).toList());
    } catch (_) {}
  }

  Future<void> _loadIndices() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'User-Agent': 'Mozilla/5.0',
          'Accept': 'application/json',
          'Referer': 'https://www.nseindia.com',
        },
      ));
      final res = await dio.get('https://www.nseindia.com/api/allIndices');
      final data = res.data['data'] as List<dynamic>;

      Map<String, dynamic> findIndex(String name) {
        final found = data.firstWhere(
              (e) => e['index']?.toString().toUpperCase() == name,
          orElse: () => null,
        );
        if (found == null) return {'value': '--', 'change': '--', 'percent': '--', 'isUp': true};
        final last = (found['last'] as num?)?.toDouble() ?? 0;
        final change = (found['variation'] as num?)?.toDouble() ?? 0;
        final percent = (found['percentChange'] as num?)?.toDouble() ?? 0;
        return {
          'value': last.toStringAsFixed(2),
          'change': '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}',
          'percent': '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%',
          'isUp': change >= 0,
        };
      }

      if (mounted) {
        setState(() {
          _nifty = findIndex('NIFTY 50');
          _bankNifty = findIndex('NIFTY BANK');
        });
      }
    } catch (e) {
      debugPrint('INDICES LOAD ERROR: $e');
    }

    try {
      final yahooDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final sensexRes = await yahooDio.get('https://query1.finance.yahoo.com/v8/finance/chart/%5EBSESN');
      final result = sensexRes.data['chart']['result'][0];
      final meta = result['meta'];
      final price = (meta['regularMarketPrice'] as num).toDouble();
      final prevClose = (meta['previousClose'] as num? ?? meta['chartPreviousClose'] as num).toDouble();
      final change = price - prevClose;
      final percent = (change / prevClose) * 100;
      if (mounted) {
        setState(() {
          _sensex = {
            'value': price.toStringAsFixed(2),
            'change': '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}',
            'percent': '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%',
            'isUp': change >= 0,
          };
        });
      }
    } catch (e) {
      debugPrint('SENSEX LOAD ERROR: $e');
    }
  }

  List<dynamic> get _gainers {
    final list = List<dynamic>.from(_stocks);
    list.sort((a, b) {
      final ap = (_livePrices[a['symbol']]?['change_percent'] as num?)?.toDouble() ?? 0;
      final bp = (_livePrices[b['symbol']]?['change_percent'] as num?)?.toDouble() ?? 0;
      return bp.compareTo(ap);
    });
    return list.take(3).toList();
  }

  List<dynamic> get _losers {
    final list = List<dynamic>.from(_stocks);
    list.sort((a, b) {
      final ap = (_livePrices[a['symbol']]?['change_percent'] as num?)?.toDouble() ?? 0;
      final bp = (_livePrices[b['symbol']]?['change_percent'] as num?)?.toDouble() ?? 0;
      return ap.compareTo(bp);
    });
    return list.take(3).toList();
  }

  Map<String, dynamic> get _selectedIndexData {
    switch (_selectedIndex) {
      case 1:
        return {'label': 'SENSEX', ..._sensex};
      case 2:
        return {'label': 'BANK NIFTY', ..._bankNifty};
      default:
        return {'label': 'NIFTY 50', ..._nifty};
    }
  }

  void _showProductsMenu() {
    final items = [
      {'icon': Icons.water_drop_outlined, 'label': 'Commodity', 'color': const Color(0xFF1E88E5), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommodityScreen()))},
      {'icon': Icons.campaign_outlined, 'label': 'IPO', 'color': const Color(0xFFD81B60), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IpoScreen()))},
      {'icon': Icons.compare_arrows, 'label': 'ETF', 'color': const Color(0xFF43A047), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EtfScreen()))},
      {'icon': Icons.percent, 'label': 'MTF', 'color': const Color(0xFF8E24AA), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MtfScreen()))},
    ];
    final fixedIncome = [
      {'icon': Icons.savings, 'label': 'FD', 'color': const Color(0xFFFF7043), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FdScreen()))},
    ];

    Widget buildGridItem(Map<String, dynamic> item, BuildContext dialogCtx) {
      final itemColor = item['color'] as Color;
      return InkWell(
        onTap: () {
          Navigator.pop(dialogCtx);
          (item['onTap'] as VoidCallback)();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(shape: BoxShape.circle, color: itemColor.withOpacity(0.14)),
              child: Icon(item['icon'] as IconData, color: itemColor, size: 24),
            ),
            const SizedBox(height: 6),
            Text(item['label'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: _textPrimary, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    Widget sectionTitle(String text) {
      return Row(
        children: [
          Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _textPrimary)),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: _cardBorder)),
        ],
      );
    }

    showGeneralDialog(
      context: context,
      barrierLabel: 'Products',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(icon: const Icon(Icons.close, color: _textPrimary), onPressed: () => Navigator.pop(dialogCtx)),
                        ),
                        sectionTitle('Trade & Invest'),
                        const SizedBox(height: 20),
                        GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.85,
                          children: items.map((i) => buildGridItem(i, dialogCtx)).toList(),
                        ),
                        const SizedBox(height: 20),
                        sectionTitle('Fixed Income'),
                        const SizedBox(height: 20),
                        GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.85,
                          children: fixedIncome.map((i) => buildGridItem(i, dialogCtx)).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secAnim, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }

  Widget _quickActionCircle(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: _textSub, fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _rangeTab(String label) {
    final selected = _chartRange == label;
    return GestureDetector(
      onTap: () {
        setState(() => _chartRange = label);
        _loadChartData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? _accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(color: selected ? _accent : _textSub, fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.w500)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?['name']?.toString().split(' ').first ?? 'Trader';
    final avatarUrl = _user?['avatar_url'];
    final idx = _selectedIndexData;
    final dayChangeValue = _holdingsValue - _investedValue;
    final dayChangePct = _investedValue > 0 ? (dayChangeValue / _investedValue) * 100 : 0.0;
    final isUp = dayChangeValue >= 0;

    return MainShell(
      currentIndex: 0,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/assistant'),
        backgroundColor: _accent,
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: RefreshIndicator(
            color: _accent,
            backgroundColor: _card,
            onRefresh: () async {
              await _loadData();
              await _loadIndices();
              await _loadNews();
              await _loadChartData();
            },
            child: CustomScrollView(
              slivers: [
                // ── Header ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _showProductsMenu,
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _accent.withOpacity(0.15),
                                    image: avatarUrl != null
                                        ? DecorationImage(image: NetworkImage('https://stock-backend-11rm.onrender.com$avatarUrl'), fit: BoxFit.cover)
                                        : null,
                                  ),
                                  child: avatarUrl == null
                                      ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'T', style: const TextStyle(color: _accent, fontWeight: FontWeight.bold, fontSize: 16)))
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Hello, $name', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 18), overflow: TextOverflow.ellipsis),
                                      const Text('Track markets. Build wealth.', style: TextStyle(color: _textSub, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search, color: _textPrimary),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                        ),
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: _textPrimary),
                          onPressed: () => context.push('/notifications'),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Portfolio value + day's gain ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('Total Portfolio Value', style: TextStyle(color: _textSub, fontSize: 13)),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => setState(() => _balanceHidden = !_balanceHidden),
                                    child: Icon(_balanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16, color: _textSub),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _balanceHidden ? '₹ •••••••' : '₹${_holdingsValue.toStringAsFixed(2)}',
                                  style: const TextStyle(color: _textPrimary, fontSize: 26, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (!_balanceHidden)
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, color: isUp ? _green : _red, size: 14),
                                    Text(
                                      ' ₹${dayChangeValue.abs().toStringAsFixed(2)} (${dayChangePct.abs().toStringAsFixed(2)}%) ',
                                      style: TextStyle(color: isUp ? _green : _red, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                    const Text('Overall', style: TextStyle(color: _textSub, fontSize: 12)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("Day's Gain", style: TextStyle(color: _textSub, fontSize: 11), overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, color: isUp ? _green : _red, size: 12),
                                      const SizedBox(width: 2),
                                      Text('₹${dayChangeValue.abs().toStringAsFixed(0)}', style: TextStyle(color: isUp ? _green : _red, fontSize: 14, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text('(${dayChangePct.abs().toStringAsFixed(2)}%)', style: TextStyle(color: isUp ? _green : _red, fontSize: 11), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 18)),

                // ── Index ticker + chart card ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), border: Border.all(color: _cardBorder)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _indexTab('NIFTY 50', _nifty, 0),
                              const SizedBox(width: 18),
                              _indexTab('SENSEX', _sensex, 1),
                              const SizedBox(width: 18),
                              _indexTab('BANK NIFTY', _bankNifty, 2),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: ['1D', '1W', '1M', '1Y', 'ALL'].map(_rangeTab).toList(),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 160,
                            child: _chartLoading
                                ? const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2))
                                : _chartSpots.isEmpty
                                ? const Center(child: Text('Chart unavailable', style: TextStyle(color: _textSub, fontSize: 12)))
                                : LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: false),
                                titlesData: const FlTitlesData(show: false),
                                borderData: FlBorderData(show: false),
                                lineTouchData: const LineTouchData(enabled: false),
                                minY: _chartSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.998,
                                maxY: _chartSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.002,
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _chartSpots,
                                    isCurved: true,
                                    color: idx['isUp'] == true ? _green : _accent,
                                    barWidth: 2.5,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        colors: [
                                          (idx['isUp'] == true ? _green : _accent).withOpacity(0.25),
                                          (idx['isUp'] == true ? _green : _accent).withOpacity(0.0),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 18)),

                // ── Quick action icons ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), border: Border.all(color: _cardBorder)),
                      child: Row(
                        children: [
                          _quickActionCircle(Icons.candlestick_chart_outlined, 'Stocks', const Color(0xFFE53935), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MarketsScreen()))),
                          _quickActionCircle(Icons.savings_outlined, 'Mutual Funds', const Color(0xFFFB8C00), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MutualFundsScreen()))),
                          _quickActionCircle(Icons.campaign_outlined, 'IPO', const Color(0xFFD81B60), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IpoScreen()))),
                          _quickActionCircle(Icons.water_drop_outlined, 'Commodity', const Color(0xFF1E88E5), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommodityScreen()))),
                        ],
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 22)),

                // ── Top Gainers ──
                _sectionHeader('Top Gainers', () => context.push('/screener')),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                if (!_loading)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cardBorder)),
                        child: Column(children: _gainers.map((s) => _movementRow(s)).toList()),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 22)),

                // ── Top Losers ──
                _sectionHeader('Top Losers', () => context.push('/screener')),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                if (!_loading)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cardBorder)),
                        child: Column(children: _losers.map((s) => _movementRow(s)).toList()),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 22)),

                // ── News & Updates ──
                _sectionHeader('News & Updates', () => context.push('/news')),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: _newsItems.isEmpty
                        ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cardBorder)),
                      child: const Text('No news available right now', style: TextStyle(color: _textSub, fontSize: 12)),
                    )
                        : Container(
                      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _cardBorder)),
                      child: Column(children: _newsItems.map((n) => _newsRow(n)).toList()),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 22)),

                // ── Quick Actions grid (Buy/Sell/IPO/MF/Commodity) ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Text('Quick Actions', style: TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _qaButton('Buy', Icons.arrow_upward, _green, () => context.push('/watchlist')),
                        const SizedBox(width: 10),
                        _qaButton('Sell', Icons.arrow_downward, _red, () => context.push('/watchlist')),
                        const SizedBox(width: 10),
                        _qaButton('ETF', Icons.compare_arrows, const Color(0xFF43A047), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EtfScreen()))),
                        const SizedBox(width: 10),
                        _qaButton('MTF', Icons.percent, const Color(0xFF8E24AA), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MtfScreen()))),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                // ── SIP banner ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MutualFundsScreen())),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Start SIP in Mutual Funds', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  const Text('Invest small, grow big wealth', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                                    child: const Text('Explore Funds', style: TextStyle(color: Color(0xFF1B5E20), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.savings, color: Colors.white.withOpacity(0.85), size: 56),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),

                if (_loading)
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: _accent)))
                else if (_error != null)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off, color: _textSub, size: 40),
                          const SizedBox(height: 12),
                          Text(_error!, style: const TextStyle(color: _textSub, fontSize: 13)),
                          const SizedBox(height: 12),
                          TextButton(onPressed: _loadData, child: const Text('Retry', style: TextStyle(color: _accent))),
                        ],
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _indexTab(String label, Map<String, dynamic> data, int index) {
    final selected = _selectedIndex == index;
    final isUp = data['isUp'] == true;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        _loadChartData();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: selected ? _accent : _textSub, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(data['value'] ?? '--', style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Text(data['percent'] ?? '--', style: TextStyle(color: isUp ? _green : _red, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          if (selected) Container(margin: const EdgeInsets.only(top: 4), height: 2, width: 28, color: _accent),
        ],
      ),
    );
  }

  SliverToBoxAdapter _sectionHeader(String title, VoidCallback onViewAll) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
            GestureDetector(onTap: onViewAll, child: const Text('See All >', style: TextStyle(color: _accent, fontSize: 12))),
          ],
        ),
      ),
    );
  }

  Widget _movementRow(dynamic stock) {
    final live = _livePrices[stock['symbol']];
    final price = (live?['price'] as num?)?.toDouble();
    final change = (live?['change_percent'] as num?)?.toDouble() ?? 0;
    final isUp = change >= 0;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockDetailScreen(stock: stock))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _cardBorder, width: 0.6))),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: (isUp ? _green : _red).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(stock['symbol'].toString().substring(0, 1), style: TextStyle(color: isUp ? _green : _red, fontWeight: FontWeight.bold, fontSize: 14))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stock['company_name'] ?? stock['symbol'] ?? '', style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                  Text(stock['symbol'] ?? '', style: const TextStyle(color: _textSub, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price != null ? '₹${price.toStringAsFixed(2)}' : '--', style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, color: isUp ? _green : _red, size: 11),
                    Text('${change.abs().toStringAsFixed(2)}%', style: TextStyle(color: isUp ? _green : _red, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _newsRow(dynamic n) {
    return GestureDetector(
      onTap: () => context.push('/news'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _cardBorder, width: 0.6))),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: n['image_url'] != null
                  ? Image.network(n['image_url'], width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 56, height: 56, color: _bg))
                  : Container(width: 56, height: 56, color: _bg, child: const Icon(Icons.article_outlined, color: _textSub)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n['title'] ?? '', style: const TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(n['source'] ?? 'Market News', style: const TextStyle(color: _textSub, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qaButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.25))),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}