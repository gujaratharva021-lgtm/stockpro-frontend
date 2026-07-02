import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/utils/export_helper.dart';
import 'package:stock_app/features/stock_detail/screens/stock_detail_screen.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});
  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  int _tab = 0; // 0=Holdings, 1=Positions, 2=Mutual Funds

  List<dynamic> _holdings = [];
  Map<String, Map<String, dynamic>> _quotes = {};
  Map<String, List<double>> _history = {};
  List<dynamic> _transactions = [];

  List<dynamic> _mtfPositions = [];
  List<dynamic> _futures = [];
  List<dynamic> _options = [];

  List<dynamic> _myFunds = [];
  List<dynamic> _myEtfs = [];

  double _balance = 0;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getHoldings(),
        ApiService.getTransactions(),
        ApiService.getMe(),
        ApiService.getMyFunds().catchError((_) => []),
        ApiService.getMyETFs().catchError((_) => []),
        ApiService.getMTFPositions().catchError((_) => []),
        ApiService.getFutures().catchError((_) => []),
        ApiService.getOptions().catchError((_) => []),
      ]);

      final holdings = results[0] as List<dynamic>;
      final transactions = results[1] as List<dynamic>;
      final me = results[2] as Map<String, dynamic>;
      final myFunds = results[3] as List<dynamic>;
      final myEtfs = results[4] as List<dynamic>;
      final mtfPositions = results[5] as List<dynamic>;
      final futures = results[6] as List<dynamic>;
      final options = results[7] as List<dynamic>;

      setState(() {
        _holdings = holdings;
        _transactions = transactions;
        _balance = (me['user']?['balance'] as num?)?.toDouble() ?? 0;
        _myFunds = myFunds;
        _myEtfs = myEtfs;
        _mtfPositions = mtfPositions;
        _futures = futures;
        _options = options;
      });

      for (final h in holdings) {
        final symbol = h['symbol'];
        if (symbol == null) continue;
        try {
          final quote = await ApiService.getQuote(symbol);
          if (mounted) setState(() => _quotes[symbol] = quote);
        } catch (_) {}
        try {
          final hist = await ApiService.getHistory(symbol);
          final closes = hist.map((p) => (p['close'] as num?)?.toDouble()).whereType<double>().toList();
          final recent = closes.length > 10 ? closes.sublist(closes.length - 10) : closes;
          if (mounted) setState(() => _history[symbol] = recent);
        } catch (_) {}
      }
    } catch (e) {
      setState(() => _error = 'Could not load portfolio');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _stocksInvested => _holdings.fold(0.0, (sum, h) {
    final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
    final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
    return sum + qty * avg;
  });

  double get _stocksCurrent => _holdings.fold(0.0, (sum, h) {
    final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
    final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
    final quote = _quotes[h['symbol']];
    final price = quote != null ? (quote['price'] as num?)?.toDouble() ?? avg : avg;
    return sum + qty * price;
  });

  double get _mfInvested => _myFunds.fold(0.0, (sum, f) {
    final qty = (f['quantity'] as num?)?.toDouble() ?? 0;
    final avg = (f['avg_price'] as num?)?.toDouble() ?? 0;
    return sum + qty * avg;
  });

  double get _etfInvested => _myEtfs.fold(0.0, (sum, e) {
    final qty = (e['quantity'] as num?)?.toDouble() ?? 0;
    final avg = (e['avg_price'] as num?)?.toDouble() ?? 0;
    return sum + qty * avg;
  });

  double get _totalCurrentValue => _stocksCurrent + _mfInvested + _etfInvested + _balance;
  double get _totalInvested => _stocksInvested + _mfInvested + _etfInvested;
  double get _totalReturns => _stocksCurrent - _stocksInvested; // MF/ETF current==invested (no live NAV yet)
  double get _totalReturnsPct => _totalInvested > 0 ? (_totalReturns / _totalInvested) * 100 : 0;

  double get _todayReturns => _holdings.fold(0.0, (sum, h) {
    final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
    final quote = _quotes[h['symbol']];
    final changePerShare = quote != null ? (quote['change'] as num?)?.toDouble() ?? 0 : 0;
    return sum + qty * changePerShare;
  });

  double get _todayReturnsPct => _stocksCurrent > 0 ? (_todayReturns / (_stocksCurrent - _todayReturns)) * 100 : 0;

  int get _positionsCount => _mtfPositions.where((p) => p['status'] == 'open').length + _futures.length + _options.length;

  @override
  Widget build(BuildContext context) {
    return MainShell(
      currentIndex: 2,
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: Colors.white,
          onRefresh: _loadAll,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Portfolio', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.show_chart, color: AppColors.textPrimary),
                            onPressed: () => context.push('/performance'),
                          ),
                          if (_transactions.isNotEmpty)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.download_outlined, color: AppColors.textSecondary, size: 22),
                              onSelected: (value) {
                                if (value == 'pdf') {
                                  ExportHelper.exportTransactionsPdf(_transactions);
                                } else {
                                  ExportHelper.exportTransactionsCsv(_transactions);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'pdf', child: Text('Download Statement (PDF)')),
                                const PopupMenuItem(value: 'csv', child: Text('Export as CSV')),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _tabChip('Holdings', _holdings.length, 0),
                      const SizedBox(width: 20),
                      _tabChip('Positions', _positionsCount, 1),
                      const SizedBox(width: 20),
                      _tabChip('Mutual Funds', _myFunds.length, 2),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: Divider(color: AppColors.border, height: 24)),

              if (_loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              else if (_error != null)
                SliverFillRemaining(child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary))))
              else ...[
                  if (_tab == 0) ..._buildHoldingsTab(),
                  if (_tab == 1) ..._buildPositionsTab(),
                  if (_tab == 2) ..._buildMutualFundsTab(),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabChip(String label, int count, int index) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(color: active ? AppColors.primaryDark : AppColors.textSecondary, fontSize: 14, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: active ? AppColors.primary.withOpacity(0.15) : AppColors.border, borderRadius: BorderRadius.circular(10)),
                child: Text('$count', style: TextStyle(color: active ? AppColors.primaryDark : AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (active) Container(margin: const EdgeInsets.only(top: 6), height: 2, width: 24, color: AppColors.primary),
        ],
      ),
    );
  }

  List<Widget> _buildHoldingsTab() {
    final isUp = _totalReturns >= 0;
    final isTodayUp = _todayReturns >= 0;
    return [
      // Summary card
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Current Value', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('₹${_totalCurrentValue.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Returns', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '${isUp ? '+' : ''}₹${_totalReturns.toStringAsFixed(2)} (${_totalReturnsPct.toStringAsFixed(2)}%)',
                            style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Invested Value', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('₹${_totalInvested.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Today's Returns", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            '${isTodayUp ? '+' : ''}₹${_todayReturns.toStringAsFixed(2)} (${_todayReturnsPct.toStringAsFixed(2)}%)',
                            style: TextStyle(color: isTodayUp ? AppColors.success : AppColors.danger, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      const Text('1D Returns ', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Text('${isTodayUp ? '+' : ''}${_todayReturnsPct.toStringAsFixed(2)}%', style: TextStyle(color: isTodayUp ? AppColors.success : AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                    GestureDetector(
                      onTap: () => context.push('/pending-orders'),
                      child: const Row(
                        children: [
                          Text('All Orders', style: TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w600)),
                          Icon(Icons.chevron_right, color: AppColors.primaryDark, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 16)),

      // Allocation card
      if (_totalCurrentValue > 0)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Allocation', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                sections: _allocationSections(),
                                centerSpaceRadius: 32,
                                sectionsSpace: 2,
                              ),
                            ),
                            const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Total', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _allocRow('Equity', AppColors.success, _stocksCurrent),
                            _allocRow('Mutual Funds', const Color(0xFF1E88E5), _mfInvested),
                            _allocRow('ETFs', const Color(0xFF8E24AA), _etfInvested),
                            _allocRow('Cash & Others', AppColors.primary, _balance),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

      const SliverToBoxAdapter(child: SizedBox(height: 16)),

      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('Holdings (${_holdings.length})', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      ),

      if (_holdings.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.pie_chart_outline, color: AppColors.textMuted, size: 40),
                  const SizedBox(height: 10),
                  const Text('No holdings yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _holdingRow(_holdings[index]),
              childCount: _holdings.length,
            ),
          ),
        ),

      const SliverToBoxAdapter(child: SizedBox(height: 16)),

      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _bottomAction(Icons.pie_chart_outline, 'Analyse', () => context.push('/performance')),
              _bottomAction(Icons.sync, 'Smart Rebalance', () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Smart Rebalance is coming soon')),
                );
              }),
              _bottomAction(Icons.file_download_outlined, 'Import Holdings', _showImportHoldings),
              _bottomAction(Icons.description_outlined, 'Tax P&L', () => context.push('/tax-report')),
            ],
          ),
        ),
      ),

      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  List<PieChartSectionData> _allocationSections() {
    final total = _totalCurrentValue;
    if (total <= 0) {
      return [PieChartSectionData(value: 1, color: AppColors.border, showTitle: false, radius: 18)];
    }
    final parts = [
      {'value': _stocksCurrent, 'color': AppColors.success},
      {'value': _mfInvested, 'color': const Color(0xFF1E88E5)},
      {'value': _etfInvested, 'color': const Color(0xFF8E24AA)},
      {'value': _balance, 'color': AppColors.primary},
    ];
    return parts
        .where((p) => (p['value'] as double) > 0)
        .map((p) => PieChartSectionData(value: p['value'] as double, color: p['color'] as Color, showTitle: false, radius: 18))
        .toList();
  }

  Widget _allocRow(String label, Color color, double value) {
    final pct = _totalCurrentValue > 0 ? (value / _totalCurrentValue) * 100 : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          Text('${pct.toStringAsFixed(2)}%', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _bottomAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryDark, size: 22),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Future<void> _showImportHoldings() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => _ImportHoldingsSheet(scrollController: scrollController, onImported: _loadAll),
      ),
    );
  }

  Widget _holdingRow(dynamic h) {
    final symbol = h['symbol'];
    final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
    final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
    final quote = _quotes[symbol];
    final price = quote != null ? (quote['price'] as num?)?.toDouble() ?? avg : avg;
    final current = qty * price;
    final invested = qty * avg;
    final returns = current - invested;
    final returnsPct = invested > 0 ? (returns / invested) * 100 : 0;
    final isUp = returns >= 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StockDetailScreen(stock: {
            'id': h['stock_id'] ?? h['id'],
            'symbol': h['symbol'],
            'company_name': h['company_name'],
            'exchange': h['exchange'] ?? 'NSE',
            'sector': h['sector'] ?? '',
          }),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.6))),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text((symbol ?? '?').toString().substring(0, 1), style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 14))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h['company_name'] ?? symbol ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('$qty shares • Avg ₹${avg.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            SizedBox(width: 44, height: 28, child: _sparkline(_history[symbol], isUp)),
            const SizedBox(width: 8),
            SizedBox(
              width: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${current.toStringAsFixed(2)}', maxLines: 1, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: (isUp ? AppColors.success : AppColors.danger).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                    child: Text('${isUp ? '+' : ''}${returnsPct.toStringAsFixed(2)}%', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                  Text('${isUp ? '+' : ''}₹${returns.toStringAsFixed(2)}', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sparkline(List<double>? closes, bool isUp) {
    if (closes == null || closes.length < 2) return const SizedBox(width: 44, height: 28);
    final spots = [for (int i = 0; i < closes.length; i++) FlSpot(i.toDouble(), closes[i])];
    final minY = closes.reduce((a, b) => a < b ? a : b);
    final maxY = closes.reduce((a, b) => a > b ? a : b);
    final color = isUp ? AppColors.success : AppColors.danger;
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        minY: minY == maxY ? minY - 1 : minY,
        maxY: minY == maxY ? maxY + 1 : maxY,
        lineBarsData: [
          LineChartBarData(spots: spots, isCurved: true, color: color, barWidth: 1.6, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: false)),
        ],
      ),
    );
  }

  List<Widget> _buildPositionsTab() {
    final allPositions = [
      ..._mtfPositions.where((p) => p['status'] == 'open').map((p) => {'type': 'MTF', 'data': p}),
      ..._futures.map((p) => {'type': 'Futures', 'data': p}),
      ..._options.map((p) => {'type': 'Options', 'data': p}),
    ];

    if (allPositions.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.candlestick_chart_outlined, color: AppColors.textMuted, size: 40),
                const SizedBox(height: 12),
                const Text('No open positions', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 4),
                const Text('MTF, Futures & Options positions appear here', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final pos = allPositions[index];
              final type = pos['type'] as String;
              final data = pos['data'] as Map;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(data['symbol']?.toString() ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                          child: Text(type, style: const TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      type == 'MTF'
                          ? 'Qty: ${data['quantity']} • Entry ₹${(data['entry_price'] as num?)?.toStringAsFixed(2)}'
                          : type == 'Futures'
                          ? '${data['position_type'] ?? ''} • Lot: ${data['lot_size']} • Entry ₹${(data['entry_price'] as num?)?.toStringAsFixed(2) ?? '-'}'
                          : '${data['option_type'] ?? ''} • Strike ₹${(data['strike_price'] as num?)?.toStringAsFixed(2) ?? '-'}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
            childCount: allPositions.length,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildMutualFundsTab() {
    if (_myFunds.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.savings_outlined, color: AppColors.textMuted, size: 40),
                const SizedBox(height: 12),
                const Text('No mutual fund investments yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final f = _myFunds[index];
              final qty = (f['quantity'] as num?)?.toDouble() ?? 0;
              final avg = (f['avg_price'] as num?)?.toDouble() ?? 0;
              final invested = qty * avg;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Units: ${qty.toStringAsFixed(3)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text('₹${invested.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              );
            },
            childCount: _myFunds.length,
          ),
        ),
      ),
    ];
  }
}

class _ImportHoldingsSheet extends StatefulWidget {
  final ScrollController scrollController;
  final VoidCallback onImported;
  const _ImportHoldingsSheet({required this.scrollController, required this.onImported});

  @override
  State<_ImportHoldingsSheet> createState() => _ImportHoldingsSheetState();
}

class _ImportHoldingsSheetState extends State<_ImportHoldingsSheet> {
  List<dynamic> _linkedHoldings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final holdings = await ApiService.getAngelOneHoldings();
      if (mounted) setState(() => _linkedHoldings = holdings);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not connect to your linked brokerage account');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
          ),
          const SizedBox(height: 16),
          const Text('Linked Brokerage Holdings', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'These are read-only holdings from your linked AngelOne account. They are not merged into your virtual portfolio.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_off, color: AppColors.textMuted, size: 36),
                  const SizedBox(height: 8),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
                : _linkedHoldings.isEmpty
                ? const Center(child: Text('No holdings in your linked account', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))
                : ListView.builder(
              controller: widget.scrollController,
              itemCount: _linkedHoldings.length,
              itemBuilder: (context, index) {
                final h = _linkedHoldings[index];
                final ltp = (h['ltp'] as num?)?.toDouble() ?? 0;
                final avgPrice = (h['averageprice'] as num?)?.toDouble() ?? 0;
                final qty = h['quantity'] ?? 0;
                final pnl = (ltp - avgPrice) * (qty is num ? qty.toDouble() : 0);
                final isProfit = pnl >= 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(h['tradingsymbol']?.toString() ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(h['exchange']?.toString() ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$qty shares @ ₹${avgPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${ltp.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                              Text('${isProfit ? '+' : ''}₹${pnl.toStringAsFixed(2)}', style: TextStyle(color: isProfit ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
