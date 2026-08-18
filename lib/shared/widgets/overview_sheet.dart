import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

/// Shows the shared "Overview" bottom sheet: NIFTY 50 + NIFTY BANK index
/// quotes with a historical trend sparkline for each, plus the user's real
/// wallet balance. Call this from the down-arrow next to any screen title.
Future<void> showOverviewSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const OverviewSheet(),
  );
}

class OverviewSheet extends StatefulWidget {
  const OverviewSheet({super.key});

  @override
  State<OverviewSheet> createState() => _OverviewSheetState();
}

class _OverviewSheetState extends State<OverviewSheet> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _nifty50Quote;
  Map<String, dynamic>? _niftyBankQuote;
  List<dynamic> _nifty50History = [];
  List<dynamic> _niftyBankHistory = [];
  double? _balance;

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
      final results = await Future.wait([
        ApiService.getQuote('NIFTY50'),
        ApiService.getQuote('NIFTYBANK'),
        ApiService.getHistory('NIFTY50'),
        ApiService.getHistory('NIFTYBANK'),
        ApiService.getBalance(),
      ]);
      if (mounted) {
        setState(() {
          _nifty50Quote = results[0] as Map<String, dynamic>;
          _niftyBankQuote = results[1] as Map<String, dynamic>;
          _nifty50History = results[2] as List<dynamic>;
          _niftyBankHistory = results[3] as List<dynamic>;
          _balance = results[4] as double;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load market overview';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Overview',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                IconButton(icon: const Icon(Icons.close, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _indexCard('NIFTY 50', _nifty50Quote!, _nifty50History)),
                  const SizedBox(width: 20),
                  Expanded(child: _indexCard('NIFTY BANK', _niftyBankQuote!, _niftyBankHistory)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('* Charts indicate historical trend', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              const Divider(height: 32, color: AppColors.border),
              const Text('Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text('₹${(_balance ?? 0).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 22, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _indexCard(String label, Map<String, dynamic> quote, List<dynamic> history) {
    final price = (quote['price'] as num?)?.toDouble() ?? 0;
    final change = (quote['change'] as num?)?.toDouble() ?? 0;
    final changePct = (quote['change_percent'] as num?)?.toDouble() ?? 0;
    final isUp = change >= 0;

    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      final close = (history[i]['close'] as num?)?.toDouble();
      if (close != null) spots.add(FlSpot(i.toDouble(), close));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text(price.toStringAsFixed(2), style: const TextStyle(fontSize: 18, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Row(children: [
          Text('${isUp ? '+' : ''}${change.toStringAsFixed(2)}',
              style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text('${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%',
              style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: spots.length < 2
              ? const SizedBox.shrink()
              : LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: isUp ? AppColors.success : AppColors.danger,
                        barWidth: 1.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
