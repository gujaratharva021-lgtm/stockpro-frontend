import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';

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

      final sample = allStocks.take(20).toList();

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

  @override
  Widget build(BuildContext context) {
    return MainShell(
      currentIndex: 5,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hi, $_userName',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _marginCard('Equity', _balance)),
                        const SizedBox(width: 20),
                        Expanded(child: _marginCard('Commodity', 0)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _moversCard('Top Gainers', _topGainers, true)),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: _moversCard('Top Losers', _topLosers, false)),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: _iposCard()),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _marketOverviewCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _marginCard(String title, double amount) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 12),
          Text(amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Margins used', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const Text('0', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Opening balance', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              Text(amount.toStringAsFixed(0), style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _moversCard(String title, List<dynamic> list, bool isGainers) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
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
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(symbol, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(price?.toStringAsFixed(2) ?? '-', style: TextStyle(fontSize: 13, color: color)),
                        Text('${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(2)}%', style: TextStyle(fontSize: 11, color: color)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Upcoming IPOs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          if (_ipos.isEmpty)
            const Text('No IPOs right now', style: TextStyle(color: AppColors.textMuted, fontSize: 12))
          else
            ..._ipos.take(6).map((ipo) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text((ipo['company_name'] ?? ipo['name'] ?? '-').toString(),
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
                      ),
                      Text((ipo['status'] ?? '').toString(), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                )),
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

    return Container(
      padding: const EdgeInsets.all(24),
      height: 320,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Market overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
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
                          color: AppColors.primary,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: true, color: AppColors.primary.withOpacity(0.08)),
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