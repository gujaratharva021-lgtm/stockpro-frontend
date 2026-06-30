import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/utils/export_helper.dart';

class TaxReportScreen extends StatefulWidget {
  const TaxReportScreen({super.key});
  @override
  State<TaxReportScreen> createState() => _TaxReportScreenState();
}

class _TaxReportScreenState extends State<TaxReportScreen> {
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
      final report = await ApiService.getTaxReport();
      setState(() => _report = report);
    } catch (_) {
      setState(() => _error = 'Could not load tax report');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gains = (_report?['gains'] as List<dynamic>?) ?? [];
    final totalStcg = (_report?['total_stcg'] as num?)?.toDouble() ?? 0;
    final totalLtcg = (_report?['total_ltcg'] as num?)?.toDouble() ?? 0;
    final estStcgTax = (_report?['estimated_stcg_tax'] as num?)?.toDouble() ?? 0;
    final estLtcgTax = (_report?['estimated_ltcg_tax'] as num?)?.toDouble() ?? 0;
    final totalTax = (_report?['total_estimated_tax'] as num?)?.toDouble() ?? 0;

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
                    'Tax P&L Report',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const Spacer(),
                  if (_report != null)
                    IconButton(
                      icon: const Icon(Icons.share_outlined, color: AppColors.textSecondary),
                      onPressed: () => ExportHelper.exportTaxReportPdf(_report!),
                    ),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_error != null)
              Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary))))
            else if (gains.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, color: AppColors.textMuted, size: 48),
                      SizedBox(height: 12),
                      Text('No realized gains yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      SizedBox(height: 4),
                      Text('Sell some holdings to see your tax report', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
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
                          const Text('Estimated Total Tax', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            '₹${totalTax.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _summaryStat('STCG Gain', totalStcg, estStcgTax, '20%'),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _summaryStat('LTCG Gain', totalLtcg, estLtcgTax, '12.5%'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Transaction Breakdown',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    ...gains.map((g) => _gainCard(g)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'This is an estimate for informational purposes only, based on FIFO matching. Please consult a tax professional for filing.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summaryStat(String label, double gain, double tax, String rate) {
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
            '₹${gain.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text('Tax ($rate): ₹${tax.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _gainCard(Map<String, dynamic> g) {
    final isLtcg = g['type'] == 'LTCG';
    final gain = (g['gain'] as num).toDouble();
    final isProfit = gain >= 0;

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
              Row(
                children: [
                  Text(g['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isLtcg ? AppColors.success.withOpacity(0.12) : AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      g['type'] ?? '',
                      style: TextStyle(
                        color: isLtcg ? AppColors.success : AppColors.primaryDark,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '${isProfit ? '+' : ''}₹${gain.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isProfit ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${g['quantity']} shares • Bought ₹${g['buy_price']} on ${g['buy_date']} • Sold ₹${g['sell_price']} on ${g['sell_date']}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          Text(
            'Holding period: ${g['holding_days']} days',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}