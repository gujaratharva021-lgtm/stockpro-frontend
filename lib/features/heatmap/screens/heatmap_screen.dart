import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/stock_detail/screens/stock_detail_screen.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});
  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  List<dynamic> _stocks = [];
  final Map<String, Map<String, dynamic>> _quotes = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final stocks = await ApiService.getStocks();
      setState(() => _stocks = stocks);

      // Fetch quotes for all stocks in parallel
      await Future.wait(stocks.map((s) async {
        try {
          final q = await ApiService.getQuote(s['symbol']);
          _quotes[s['symbol']] = q;
        } catch (_) {
          // skip stocks whose quote fails
        }
      }));
    } catch (_) {
      // ignore, will show empty state
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, List<dynamic>> _groupBySector() {
    final Map<String, List<dynamic>> grouped = {};
    for (final s in _stocks) {
      final sector = (s['sector'] ?? 'Other').toString();
      grouped.putIfAbsent(sector, () => []).add(s);
    }
    return grouped;
  }

  Color _colorForChange(double? changePercent) {
    if (changePercent == null) return AppColors.border;
    final clamped = changePercent.clamp(-5.0, 5.0);
    if (clamped >= 0) {
      // 0% -> light green, 5%+ -> deep green
      final t = clamped / 5.0;
      return Color.lerp(const Color(0xFFD7F5E9), const Color(0xFF00B386), t)!;
    } else {
      final t = -clamped / 5.0;
      return Color.lerp(const Color(0xFFFDE2E2), const Color(0xFFE5484D), t)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupBySector();
    final sectorNames = grouped.keys.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Market Heatmap',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
                    onPressed: _load,
                  ),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: sectorNames.length,
                  itemBuilder: (context, index) {
                    final sector = sectorNames[index];
                    final stocksInSector = grouped[sector]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sector, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: stocksInSector.map((s) {
                              final symbol = s['symbol'] ?? '';
                              final quote = _quotes[symbol];
                              final changePercent = quote != null && quote['change_percent'] != null
                                  ? (quote['change_percent'] as num).toDouble()
                                  : null;

                              return GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StockDetailScreen(stock: s))),
                                child: Container(
                                  width: 104,
                                  height: 70,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _colorForChange(changePercent),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        symbol,
                                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        changePercent != null ? '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%' : 'N/A',
                                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}