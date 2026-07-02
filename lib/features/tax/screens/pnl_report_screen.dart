import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class PnLReportScreen extends StatefulWidget {
  const PnLReportScreen({super.key});
  @override
  State<PnLReportScreen> createState() => _PnLReportScreenState();
}

class _PnLReportScreenState extends State<PnLReportScreen> {
  Map<String, dynamic>? _report;
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
      final report = await ApiService.getPnLReport();
      setState(() => _report = report);
    } catch (_) {
      setState(() => _error = 'Could not load P&L report');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final holdings = (_report?['holdings'] as List<dynamic>?) ?? [];
    final realizedPnL = (_report?['realized_pnl'] as num?)?.toDouble() ?? 0;
    final unrealizedPnL = (_report?['unrealized_pnl'] as num?)?.toDouble() ?? 0;
    final totalPnL = (_report?['total_pnl'] as num?)?.toDouble() ?? 0;
    final totalInvested = (_report?['total_invested'] as num?)?.toDouble() ?? 0;
    final currentValue = (_report?['current_value'] as num?)?.toDouble() ?? 0;

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
                    'P&L Report',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_error != null)
              Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary))))
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      // Summary card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total P&L', style: TextStyle(color: Colors.white70, fontSize: 13)),
                            const SizedBox(height: 6),
                            Text(
                              '${totalPnL >= 0 ? '+' : ''}₹${totalPnL.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: totalPnL >= 0 ? AppColors.success : AppColors.danger,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: _summaryStat('Realized', realizedPnL)),
                                const SizedBox(width: 16),
                                Expanded(child: _summaryStat('Unrealized', unrealizedPnL)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _investStat('Invested', totalInvested),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _investStat('Current Value', currentValue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (holdings.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.pie_chart_outline, color: AppColors.textMuted, size: 48),
                                SizedBox(height: 12),
                                Text('No holdings yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        const Text(
                          'Holdings Breakdown',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 10),
                        ...holdings.map((h) => _holdingCard(h)),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryStat(String label, double value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            '${value >= 0 ? '+' : ''}₹${value.toStringAsFixed(2)}',
            style: TextStyle(
              color: value >= 0 ? AppColors.success : AppColors.danger,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _investStat(String label, double value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 4),
          Text('₹${value.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _holdingCard(Map<String, dynamic> h) {
    final pnl = (h['pnl'] as num).toDouble();
    final pnlPercent = (h['pnl_percent'] as num).toDouble();
    final isProfit = pnl >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(h['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                    if ((h['company_name'] ?? '').toString().isNotEmpty)
                      Text(h['company_name'], style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isProfit ? '+' : ''}₹${pnl.toStringAsFixed(2)}',
                    style: TextStyle(color: isProfit ? AppColors.success : AppColors.danger, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    '${isProfit ? '+' : ''}${pnlPercent.toStringAsFixed(2)}%',
                    style: TextStyle(color: isProfit ? AppColors.success : AppColors.danger, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${h['quantity']} shares • Avg ₹${(h['avg_price'] as num).toStringAsFixed(2)} • LTP ₹${(h['current_price'] as num).toStringAsFixed(2)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}