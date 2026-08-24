import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = [
    {
      'q': 'Is this real trading with real money?',
      'a': 'No. All trades here are virtual and use simulated funds for learning purposes only.',
    },
    {
      'q': 'Why is my order still Pending?',
      'a': 'Limit and stop-loss orders stay Pending until the market price reaches your trigger price. You can check status anytime under Orders.',
    },
    {
      'q': 'How do I cancel or modify an order?',
      'a': 'Go to Orders, then tap Modify or Cancel on the relevant order.',
    },
    {
      'q': 'How do I link my brokerage account?',
      'a': 'You can link a read-only brokerage account from the Import Holdings option in your Portfolio to view your real holdings alongside your virtual ones.',
    },
    {
      'q': 'How do I reset my password?',
      'a': 'Use the Forgot Password link on the sign-in screen to receive a reset link on your registered email.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Help & Support', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Frequently Asked Questions', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                for (int i = 0; i < _faqs.length; i++)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      iconColor: AppColors.primary,
                      collapsedIconColor: AppColors.textMuted,
                      title: Text(_faqs[i]['q']!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_faqs[i]['a']!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text('Still need help?', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.email_outlined, color: AppColors.primary, size: 18),
                    SizedBox(width: 10),
                    Text('support@oneinvest.app', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.access_time, color: AppColors.primary, size: 18),
                    SizedBox(width: 10),
                    Text('We usually respond within 24-48 hours', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}