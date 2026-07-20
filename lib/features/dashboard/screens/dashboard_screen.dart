import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/core/constants/nifty_symbols.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String _userName = '';
  double _balance = 0;
  List<dynamic> _stocks = [];
  final Map<String, Map<String, dynamic>> _quotes = {};
  List<dynamic> _chartHistory = [];
  List<dynamic> _ipos = [];

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
  }

  double _changePctOf(String symbol) {
    final q = _quotes[symbol];
    return q != null ? (q['change_percent'] as num?)?.toDouble() ?? 0 : 0;
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

  @override
  Widget build(BuildContext context) {
    return MainShell(
      currentIndex: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FB),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _headerBanner(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Transform.translate(
                            offset: const Offset(0, -36),
                            child: Row(
                              children: [
                                Expanded(child: _marginCard('Equity', _balance, Icons.account_balance_wallet_rounded, const Color(0xFF6366F1))),
                                const SizedBox(width: 20),
                                Expanded(child: _marginCard('Commodity', 0, Icons.local_fire_department_rounded, const Color(0xFFF59E0B))),
                              ],
                            ),
                          ),
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

  Widget _headerBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 90),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_greeting, $_userName',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              Text('Here\'s what\'s happening in the markets today',
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.85))),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.insights_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _marginCard(String title, double amount, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 16),
          Text(amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Margins used', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const Text('0', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Opening balance', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              Text(amount.toStringAsFixed(0), style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moversCard(String title, List<dynamic> list, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          if (list.isEmpty)
            const Text('No data yet', style: TextStyle(color: AppColors.textMuted, fontSize: 12))
          else
            ...list.map((s) {
              final symbol = s['symbol'];
              final q = _quotes[symbol];
              final price = q != null ? (q['price'] as num?)?.toDouble() : null;
              final pct = _changePctOf(symbol);
              final color = pct >= 0 ? AppColors.success : AppColors.danger;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
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
                      child: Text(symbol, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(price?.toStringAsFixed(2) ?? '-', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                          child: Text('${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                        ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rocket_launch_rounded, color: Color(0xFF7C3AED), size: 18),
              const SizedBox(width: 8),
              const Text('Upcoming IPOs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          if (_ipos.isEmpty)
            const Text('No IPOs right now', style: TextStyle(color: AppColors.textMuted, fontSize: 12))
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
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isOpen ? AppColors.success : const Color(0xFFF59E0B)).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(status, style: TextStyle(fontSize: 10, color: isOpen ? AppColors.success : const Color(0xFFF59E0B), fontWeight: FontWeight.w600)),
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

    return Container(
      padding: const EdgeInsets.all(24),
      height: 340,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: trendColor, size: 18),
              const SizedBox(width: 8),
              const Text('Market overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: spots.isEmpty
                ? const Center(child: Text('No chart data', style: TextStyle(color: AppColors.textMuted)))
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
                              colors: [trendColor.withOpacity(0.18), trendColor.withOpacity(0.0)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}