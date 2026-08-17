import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/shared/widgets/app_card.dart';
import 'package:stock_app/shared/widgets/price_change.dart';
import 'package:stock_app/shared/widgets/section_header.dart';
import 'package:stock_app/shared/widgets/status_badge.dart';
import 'package:stock_app/core/constants/nifty_symbols.dart';
import 'package:stock_app/features/search/screens/search_screen.dart';
import 'package:stock_app/features/wallet/screens/wallet_history_screen.dart';
import 'package:stock_app/features/profile/screens/funds_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Hero-gradient-specific colors only. Card surfaces/borders now come from
  // AppCard/AppColors (Phase 2 design-system consolidation) -- these two
  // remain screen-local because the hero section's gradient and its muted
  // text tone are a deliberate one-off treatment, not reused elsewhere.
  static const _bgTop = Color(0xFF15303A);
  static const _bgBottom = Color(0xFF0A0E14);
  static const _textMutedD = Color(0xFF8A93A3);

  bool _loading = true;
  String _userName = '';
  bool _kycDone = false;
  double _balance = 0;
  List<dynamic> _stocks = [];
  final Map<String, Map<String, dynamic>> _quotes = {};
  List<dynamic> _chartHistory = [];
  List<dynamic> _ipos = [];
  List<dynamic> _holdings = [];
  List<dynamic> _watchlist = [];
  List<Map<String, dynamic>> _perfPoints = [];

  static const List<String> _ranges = ['1W', 'MTD', '1M', '3M', 'YTD', '1Y', 'All'];
  String _range = '1M';
  String _valueTab = 'Value'; // 'Value' or 'Performance'

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        ApiService.getMe(),
        ApiService.getBalance(),
        ApiService.getStocks(),
        ApiService.getIPOs(),
      ]);

      final me = results[0] as Map<String, dynamic>;
      final user = me['user'] ?? {};
      final balance = results[1] as double;
      final allStocks = results[2] as List<dynamic>;
      final ipos = results[3] as List<dynamic>;
      final sample = allStocks.where((s) => kNiftyWatchSymbols.contains(s['symbol'])).toList();

      if (mounted) {
        setState(() {
          _userName = (user['name'] ?? user['full_name'] ?? 'Trader').toString();
          _kycDone = user['kyc_completed'] == true;
          _balance = balance;
          _stocks = sample;
          _ipos = ipos;
        });
      }

      for (final s in sample) {
        final symbol = s['symbol'];
        try {
          final q = await ApiService.getQuote(symbol);
          if (mounted) setState(() => _quotes[symbol] = q);
        } catch (_) {}
      }

      if (sample.isNotEmpty) {
        try {
          final hist = await ApiService.getHistory(sample.first['symbol']);
          if (mounted) setState(() => _chartHistory = hist);
        } catch (_) {}
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    try {
      final holdings = await ApiService.getHoldings();
      if (mounted) setState(() => _holdings = holdings);
      for (final h in holdings) {
        final symbol = h['symbol'];
        if (symbol == null || _quotes.containsKey(symbol)) continue;
        try {
          final q = await ApiService.getQuote(symbol);
          if (mounted) setState(() => _quotes[symbol] = q);
        } catch (_) {}
      }
    } catch (_) {}

    try {
      final watchlist = await ApiService.getWatchlist();
      if (mounted) setState(() => _watchlist = watchlist);
      for (final w in watchlist.take(10)) {
        final symbol = w['symbol'];
        if (symbol == null || _quotes.containsKey(symbol)) continue;
        try {
          final q = await ApiService.getQuote(symbol);
          if (mounted) setState(() => _quotes[symbol] = q);
        } catch (_) {}
      }
    } catch (_) {}

    try {
      final perf = await ApiService.getPerformance();
      final points = (perf['performance'] as List? ?? []);
      final parsed = points
          .map((p) => {
                'date': DateTime.tryParse(p['date'].toString()) ?? DateTime.now(),
                'value': (p['value'] as num?)?.toDouble() ?? 0.0,
              })
          .toList()
          .cast<Map<String, dynamic>>();
      parsed.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      if (mounted) setState(() => _perfPoints = parsed);
    } catch (_) {}
  }

  double _changePctOf(String symbol) {
    final q = _quotes[symbol];
    return q != null ? (q['change_percent'] as num?)?.toDouble() ?? 0 : 0;
  }

  double? _priceOf(String symbol) {
    final q = _quotes[symbol];
    return q != null ? (q['price'] as num?)?.toDouble() : null;
  }

  List<dynamic> get _topGainers {
    final list = List<dynamic>.from(_stocks);
    list.sort((a, b) => _changePctOf(b['symbol']).compareTo(_changePctOf(a['symbol'])));
    return list.take(5).toList();
  }

  List<dynamic> get _topLosers {
    final list = List<dynamic>.from(_stocks);
    list.sort((a, b) => _changePctOf(a['symbol']).compareTo(_changePctOf(b['symbol'])));
    return list.take(5).toList();
  }

  List<Map<String, dynamic>> get _filteredPerf {
    if (_perfPoints.isEmpty) return [];
    final last = _perfPoints.last['date'] as DateTime;
    DateTime cutoff;
    switch (_range) {
      case '1W':
        cutoff = last.subtract(const Duration(days: 7));
        break;
      case 'MTD':
        cutoff = DateTime(last.year, last.month, 1);
        break;
      case '1M':
        cutoff = last.subtract(const Duration(days: 30));
        break;
      case '3M':
        cutoff = last.subtract(const Duration(days: 90));
        break;
      case 'YTD':
        cutoff = DateTime(last.year, 1, 1);
        break;
      case '1Y':
        cutoff = last.subtract(const Duration(days: 365));
        break;
      default:
        cutoff = _perfPoints.first['date'] as DateTime;
    }
    final list = _perfPoints.where((p) => !(p['date'] as DateTime).isBefore(cutoff)).toList();
    return list.isEmpty ? _perfPoints : list;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Color _avatarColor(String symbol) {
    final colors = [
      const Color(0xFF6366F1), const Color(0xFF8B5CF6), const Color(0xFFEC4899),
      const Color(0xFF06B6D4), const Color(0xFFF59E0B), const Color(0xFF10B981),
      const Color(0xFF3B82F6), const Color(0xFFEF4444),
    ];
    final idx = symbol.codeUnits.fold<int>(0, (a, b) => a + b) % colors.length;
    return colors[idx];
  }

  String _fmtAxis(double v) {
    final sign = v < 0 ? '-' : '';
    final av = v.abs();
    if (av >= 1000000) return '$sign${(av / 1000000).toStringAsFixed(av % 1000000 == 0 ? 0 : 2)}M';
    if (av >= 1000) return '$sign${(av / 1000).toStringAsFixed(0)}K';
    return '$sign${av.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final outerPad = isMobile ? 16.0 : 32.0;

    return MainShell(
      currentIndex: 5,
      child: Scaffold(
        backgroundColor: _bgBottom,
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroSection(isMobile),
                    Padding(
                      padding: EdgeInsets.fromLTRB(outerPad, 20, outerPad, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_kycDone) ...[
                            _kycBanner(context),
                            const SizedBox(height: 20),
                          ],
                          _quickIconsRow(context),
                          const SizedBox(height: 22),
                          _topHoldingsCard(context),
                          const SizedBox(height: 20),
                          _watchlistStrip(context),
                          const SizedBox(height: 20),
                          if (isMobile)
                            _moversRowMobile()
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _moversCard('Top Gainers', _topGainers, Icons.trending_up_rounded, AppColors.success)),
                                const SizedBox(width: 20),
                                Expanded(flex: 2, child: _moversCard('Top Losers', _topLosers, Icons.trending_down_rounded, AppColors.danger)),
                                const SizedBox(width: 20),
                                Expanded(flex: 2, child: _iposCard()),
                              ],
                            ),
                          const SizedBox(height: 20),
                          _marketOverviewCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // Dark hero: greeting/bell + Value|Performance toggle + big number +
  // change line + chart with right-side value labels + timeframe tabs.
  // Backed by the real /portfolio/performance series -- no mock numbers.
  Widget _heroSection(bool isMobile) {
    final pad = isMobile ? 20.0 : 32.0;
    final filtered = _filteredPerf;
    final beginning = filtered.isNotEmpty ? filtered.first['value'] as double : _balance;
    final ending = filtered.isNotEmpty ? filtered.last['value'] as double : _balance;
    final change = ending - beginning;
    final changePct = beginning != 0 ? (change / beginning) * 100 : 0.0;
    final isUp = change >= 0;
    final trendColor = isUp ? AppColors.success : AppColors.danger;

    final showingPerf = _valueTab == 'Performance';
    final rawSpots = <FlSpot>[
      for (var i = 0; i < filtered.length; i++)
        FlSpot(
          i.toDouble(),
          showingPerf
              ? (beginning != 0 ? ((filtered[i]['value'] as double) - beginning) / beginning * 100 : 0.0)
              : filtered[i]['value'] as double,
        ),
    ];

    double minY = 0, maxY = 0;
    if (rawSpots.isNotEmpty) {
      minY = rawSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      maxY = rawSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      if (minY == maxY) {
        minY -= 1;
        maxY += 1;
      }
      final range = maxY - minY;
      minY -= range * 0.15;
      maxY += range * 0.25;
      if (minY > 0) minY = 0;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(pad, 40, pad, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgBottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('$_greeting, $_userName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push('/notifications'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
                  child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _valueTab = 'Value'),
                child: Text('Value',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _valueTab == 'Value' ? Colors.white : _textMutedD,
                    )),
              ),
              const SizedBox(width: 10),
              Container(width: 1, height: 14, color: _textMutedD.withValues(alpha: 0.4)),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => setState(() => _valueTab = 'Performance'),
                child: Text('Performance',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _valueTab == 'Performance' ? Colors.white : _textMutedD,
                    )),
              ),
              const Spacer(),
              Icon(Icons.info_outline_rounded, color: _textMutedD.withValues(alpha: 0.6), size: 18),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              showingPerf ? '${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%' : '\u20b9${ending.toStringAsFixed(2)}',
              maxLines: 1,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${isUp ? '+' : ''}\u20b9${change.toStringAsFixed(2)} (${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%) $_range',
            style: TextStyle(fontSize: 14, color: trendColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: isMobile ? 240 : 300,
            child: rawSpots.length < 2
                ? Center(child: Text('Not enough data yet', style: TextStyle(color: _textMutedD, fontSize: 12)))
                : LineChart(
                    LineChartData(
                      minY: minY,
                      maxY: maxY,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        show: true,
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 54,
                            interval: (maxY - minY) / 5,
                            getTitlesWidget: (val, _) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(showingPerf ? '${val.toStringAsFixed(0)}%' : _fmtAxis(val),
                                  style: TextStyle(color: _textMutedD, fontSize: 10.5)),
                            ),
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: rawSpots,
                          isCurved: false,
                          color: const Color(0xFF4A9EFF),
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: _ranges.map((r) {
              final active = r == _range;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _range = r),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF4A9EFF).withValues(alpha: 0.18) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(r,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: active ? const Color(0xFF4A9EFF) : _textMutedD,
                          fontWeight: active ? FontWeight.bold : FontWeight.w500,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Mirrors the "Ready to invest with real money? Finish Application"
  // promo card, but wired to this app's real KYC flow instead of a made-up
  // promotion -- only shown while the account is unverified. Kept as a
  // light card against the dark background, same as the reference design.
  Widget _kycBanner(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/onboarding'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.verified_user_rounded, color: Color(0xFFF59E0B), size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ready to invest with real money?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF191919))),
                  SizedBox(height: 4),
                  Text('Finish Application', style: TextStyle(fontSize: 13, color: Color(0xFFF59E0B), fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF191919)),
          ],
        ),
      ),
    );
  }

  // Explore / Transactions / Account / Withdraw / Deposit as translucent
  // dark circular buttons, matching the reference icon row style.
  Widget _quickIconsRow(BuildContext context) {
    final items = <_IconAction>[
      _IconAction('Explore', Icons.search_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()))),
      _IconAction('Transactions', Icons.attach_money_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletHistoryScreen()))),
      _IconAction('Account', Icons.person_rounded, () => context.push('/profile')),
      _IconAction('Withdraw', Icons.north_east_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FundsScreen()))),
      _IconAction('Deposit', Icons.south_west_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FundsScreen()))),
    ];
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final a = items[i];
          return InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: a.onTap,
            child: SizedBox(
              width: 64,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
                    child: Icon(a.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(a.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5, color: _textMutedD, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _topHoldingsCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Top Holdings',
            icon: Icons.pie_chart_rounded,
            iconColor: const Color(0xFF4A9EFF),
            actionLabel: 'See all',
            onAction: () => context.go('/portfolio'),
          ),
          const SizedBox(height: 16),
          if (_holdings.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Text("You don't own any stocks yet", style: TextStyle(color: _textMutedD, fontSize: 13)),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => context.go('/watchlist'),
                    child: const Text('Explore Stocks', style: TextStyle(color: Color(0xFF4A9EFF), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            )
          else
            ..._holdings.take(5).map((h) {
              final symbol = (h['symbol'] ?? '').toString();
              final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
              final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
              final ltp = _priceOf(symbol);
              final pct = _changePctOf(symbol);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: _avatarColor(symbol), shape: BoxShape.circle),
                      child: Center(
                        child: Text(symbol.isNotEmpty ? symbol[0] : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(symbol, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                          Text('${qty.toStringAsFixed(0)} qty @ \u20b9${avg.toStringAsFixed(2)}',
                              style: TextStyle(fontSize: 11, color: _textMutedD)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(ltp != null ? '\u20b9${ltp.toStringAsFixed(2)}' : '-',
                            style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
                        PriceChange(change: pct, changePercent: pct, fontSize: 11.5, showParens: false),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _watchlistStrip(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Watchlist',
            icon: Icons.star_rounded,
            iconColor: const Color(0xFFF59E0B),
            actionLabel: 'Show All',
            onAction: () => context.go('/watchlist'),
          ),
          const SizedBox(height: 14),
          if (_watchlist.isEmpty)
            Text('No stocks in your watchlist yet', style: TextStyle(color: _textMutedD, fontSize: 12))
          else
            SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _watchlist.take(10).length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, i) {
                  final w = _watchlist[i];
                  final symbol = (w['symbol'] ?? '').toString();
                  final pct = _changePctOf(symbol);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: _avatarColor(symbol), shape: BoxShape.circle),
                        child: Center(
                          child: Text(symbol.isNotEmpty ? symbol[0] : '?',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(symbol,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w500)),
                      PriceChange(change: pct, changePercent: pct, fontSize: 9.5, showParens: false),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _moversRowMobile() {
    const cardWidth = 240.0;
    return SizedBox(
      height: 268,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          SizedBox(width: cardWidth, child: _moversCard('Top Gainers', _topGainers, Icons.trending_up_rounded, AppColors.success)),
          const SizedBox(width: 14),
          SizedBox(width: cardWidth, child: _moversCard('Top Losers', _topLosers, Icons.trending_down_rounded, AppColors.danger)),
          const SizedBox(width: 14),
          SizedBox(width: cardWidth, child: _iposCard()),
        ],
      ),
    );
  }

  Widget _moversCard(String title, List<dynamic> list, IconData icon, Color accent) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title, icon: icon, iconColor: accent),
          const SizedBox(height: 14),
          if (list.isEmpty)
            Text('No data yet', style: TextStyle(color: _textMutedD, fontSize: 12))
          else
            ...list.map((s) {
              final symbol = s['symbol'];
              final price = _priceOf(symbol);
              final pct = _changePctOf(symbol);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: _avatarColor(symbol), shape: BoxShape.circle),
                      child: Center(
                        child: Text(symbol.isNotEmpty ? symbol[0] : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(symbol, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(price?.toStringAsFixed(2) ?? '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        PriceChange(change: pct, changePercent: pct, fontSize: 9.5, showParens: false),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _iposCard() {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Upcoming IPOs', icon: Icons.rocket_launch_rounded, iconColor: Color(0xFF7C3AED)),
          const SizedBox(height: 14),
          if (_ipos.isEmpty)
            Text('No IPOs right now', style: TextStyle(color: _textMutedD, fontSize: 12))
          else
            ..._ipos.take(6).map((ipo) {
              final status = (ipo['status'] ?? '').toString();
              final isOpen = status.toLowerCase() == 'open';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text((ipo['company_name'] ?? ipo['name'] ?? '-').toString(),
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    StatusBadge(
                      label: status,
                      tone: isOpen ? AppStatusTone.positive : AppStatusTone.warning,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _marketOverviewCard() {
    final spots = <FlSpot>[];
    for (var i = 0; i < _chartHistory.length; i++) {
      final p = _chartHistory[i];
      final close = (p['close'] as num?)?.toDouble() ?? (p['price'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), close));
    }
    final isUp = spots.length > 1 ? spots.last.y >= spots.first.y : true;
    final trendColor = isUp ? AppColors.success : AppColors.danger;

    return SizedBox(
      height: 340,
      child: AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Market overview', icon: Icons.show_chart_rounded, iconColor: trendColor),
          const SizedBox(height: 18),
          Expanded(
            child: spots.isEmpty
                ? Center(child: Text('No chart data', style: TextStyle(color: _textMutedD)))
                : LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: trendColor,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [trendColor.withValues(alpha: 0.18), trendColor.withValues(alpha: 0.0)],
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
    );
  }
}

class _IconAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _IconAction(this.label, this.icon, this.onTap);
}
