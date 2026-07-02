import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});
  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int? _expandedFaq;

  final List<Map<String, String>> _faqs = [
    {'q': 'How do I buy stocks?', 'a': 'Go to any stock detail screen and tap the BUY button. Enter quantity, select order type (Market/Limit) and confirm your order.'},
    {'q': 'How do I add money to my wallet?', 'a': 'Go to Account → Add Funds. Enter the amount and complete payment via Razorpay using UPI, debit card or net banking.'},
    {'q': 'What is SIP?', 'a': 'SIP (Systematic Investment Plan) allows you to invest a fixed amount in mutual funds regularly (daily/weekly/monthly) to build wealth over time.'},
    {'q': 'How do I start a SIP?', 'a': 'Go to Mutual Funds, select any fund, tap "Start SIP", enter amount and frequency, then complete payment.'},
    {'q': 'What is a Limit Order?', 'a': 'A limit order lets you buy/sell stocks at a specific price. The order executes only when the stock reaches your target price.'},
    {'q': 'How do I withdraw funds?', 'a': 'Go to Account → Withdraw. Enter the amount to withdraw. Funds will be credited to your linked bank account within 1-3 business days.'},
    {'q': 'What is KYC?', 'a': 'KYC (Know Your Customer) is a mandatory verification process. Complete it to unlock all trading features.'},
    {'q': 'How do I cancel a SIP?', 'a': 'Go to Account → My SIPs, find your active SIP and tap "Cancel SIP".'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 16, 0),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                    const Expanded(child: Text('Help & Support', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18))),
                  ],
                ),
              ),
            ),

            // Contact options
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Contact Us', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _contactCard(Icons.email_outlined, 'Email', 'support@stockpro.in', const Color(0xFF1E88E5), () => _openUrl('mailto:support@stockpro.in'))),
                        const SizedBox(width: 12),
                        Expanded(child: _contactCard(Icons.chat_outlined, 'WhatsApp', 'Chat with us', const Color(0xFF25D366), () => _openUrl('https://wa.me/919999999999'))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _contactCardFull(Icons.access_time_outlined, 'Support Hours', 'Mon-Fri: 9 AM - 6 PM IST', const Color(0xFFF59E0B)),
                  ],
                ),
              ),
            ),

            // FAQ
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: const Text('Frequently Asked Questions', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        key: Key('faq_$index'),
                        initiallyExpanded: _expandedFaq == index,
                        onExpansionChanged: (val) => setState(() => _expandedFaq = val ? index : null),
                        title: Text(_faqs[index]['q']!, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                        iconColor: AppColors.primary,
                        collapsedIconColor: AppColors.textMuted,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(_faqs[index]['a']!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  childCount: _faqs.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _contactCardFull(IconData icon, String title, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    try { await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
  }
}