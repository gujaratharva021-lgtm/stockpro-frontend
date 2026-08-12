import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class UserManualScreen extends StatelessWidget {
  const UserManualScreen({super.key});

  static const List<Map<String, dynamic>> _sections = [
    {
      'title': 'Getting Started',
      'points': [
        'Complete your KYC from Profile > Personal Details to unlock all features.',
        'Add your bank account to enable withdrawals.',
        'Set up biometric login for faster, secure access.',
      ],
    },
    {
      'title': 'Trading',
      'points': [
        'Use the Watchlist to track stocks you are interested in.',
        'Place market, limit, or stop-loss orders from a stock\'s detail page.',
        'Track open positions and order status under Orders and Pending Orders.',
      ],
    },
    {
      'title': 'Funds',
      'points': [
        'Add funds to your wallet using UPI, card, or netbanking via Add Funds.',
        'Withdraw funds anytime to your linked bank account.',
        'Check your live wallet balance on the Profile screen.',
      ],
    },
    {
      'title': 'Mutual Funds & SIPs',
      'points': [
        'Browse mutual funds and start a SIP from the Mutual Funds tab.',
        'Manage or cancel active SIPs under My SIPs in Profile.',
      ],
    },
    {
      'title': 'Reports & Taxes',
      'points': [
        'View your realized and unrealized P&L under Tax P&L Report.',
        'Use the Brokerage Calculator to estimate charges before placing a trade.',
      ],
    },
    {
      'title': 'Security',
      'points': [
        'Change your password anytime under Security.',
        'Turn on Privacy Mode to hide sensitive amounts on screen.',
        'Enable biometric login for quick, secure sign-in.',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 16, 0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                  const Expanded(child: Text('User Manual', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18))),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _sections.length,
                itemBuilder: (ctx, i) {
                  final section = _sections[i];
                  final points = section['points'] as List<String>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ExpansionTile(
                      title: Text(section['title'] as String, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                      iconColor: AppColors.primary,
                      collapsedIconColor: AppColors.textMuted,
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: points.map((p) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 5),
                                child: Icon(Icons.circle, size: 5, color: AppColors.textMuted),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(p, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4))),
                            ],
                          ),
                        );
                      }).toList(),
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