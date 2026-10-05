import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class FeatureInfoScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  const FeatureInfoScreen({super.key, required this.title, required this.icon});

  static const Map<String, List<String>> _info = {
    'Mutual Fund': [
      'Invest in top mutual funds directly from StockPro, with no paperwork.',
      'Direct plans with zero commission',
      'Start SIP from just Rs 500 per month',
      'Track all your funds in one place',
    ],
    'F&O': [
      'Trade Futures and Options with live prices and real-time margin details.',
      'Live futures and options data',
      'Margin calculator before every trade',
      'Track open positions and P&L instantly',
    ],
    'Intraday': [
      'Buy and sell within the same day with leverage and quick execution.',
      'Higher buying power with margin',
      'Fast order placement and square-off',
      'Auto square-off before market close',
    ],
    'Option Trading': [
      'Analyse option chains and trade calls and puts with ease.',
      'Complete option chain with live Greeks',
      'Build strategies like straddle and spreads',
      'Payoff charts before you trade',
    ],
    'Stock Exchange': [
      'Access NSE and BSE markets with live indices and market data.',
      'Live NSE and BSE indices',
      'Top gainers, losers and most active stocks',
      'Market timings and holiday calendar',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final data = _info[title] ?? ['Available in StockPro.'];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withValues(alpha: 0.15)),
                  child: Icon(icon, color: AppColors.primary, size: 44),
                ),
              ),
              const SizedBox(height: 24),
              Center(child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold))),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Coming soon', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),
              Text(data.first, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5)),
              const SizedBox(height: 24),
              ...data.skip(1).map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        Container(
                          width: 26, height: 26,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success),
                          child: const Icon(Icons.check, color: Colors.white, size: 15),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(b, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
                      ]),
                    ),
                  )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Got it', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}