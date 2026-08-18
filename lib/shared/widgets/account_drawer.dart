import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/features/profile/screens/funds_screen.dart';
import 'package:stock_app/features/profile/screens/settings_screen.dart';
import 'package:stock_app/features/profile/screens/account_details_screen.dart';
import 'package:stock_app/features/profile/screens/statements_tax_screen.dart';

class DrawerFeature {
  final IconData icon;
  final String label;
  final String route;
  const DrawerFeature(this.icon, this.label, this.route);
}

/// Screens that don't have a dedicated bottom-nav tab -- kept reachable from
/// the account drawer's "More" section so nothing is lost.
const List<DrawerFeature> kMoreFeatures = [
  DrawerFeature(Icons.swap_horiz_outlined, 'Trade / Orders', '/pending-orders'),
  DrawerFeature(Icons.gavel_outlined, 'Bids / IPO', '/ipo'),
  DrawerFeature(Icons.article_outlined, 'News', '/news'),
  DrawerFeature(Icons.filter_alt_outlined, 'Screener', '/screener'),
  DrawerFeature(Icons.compare_arrows, 'Compare', '/compare'),
  DrawerFeature(Icons.grid_view_outlined, 'Heatmap', '/heatmap'),
  DrawerFeature(Icons.dashboard_customize_outlined, 'Smallcase', '/smallcase'),
  DrawerFeature(Icons.bar_chart_outlined, 'FII / DII', '/fii-dii'),
  DrawerFeature(Icons.calculate_outlined, 'Brokerage Calculator', '/brokerage-calculator'),
  DrawerFeature(Icons.autorenew, 'SIP', '/sip'),
  DrawerFeature(Icons.smart_toy_outlined, 'AI Assistant', '/assistant'),
  DrawerFeature(Icons.notifications_outlined, 'Notifications', '/notifications'),
  DrawerFeature(Icons.trending_up, 'Performance', '/performance'),
  DrawerFeature(Icons.receipt_long_outlined, 'Tax Report', '/tax-report'),
  DrawerFeature(Icons.account_circle_outlined, 'Profile', '/profile'),
];

/// Account-style drawer opened from the hamburger icon on every screen.
/// Shows account value / cash / invested (like the reference Account
/// screen), then Account Details, Statements & Tax (replaces "Support") and
/// Settings, followed by the rest of the app's features and Log Out.
class AccountDrawer extends StatefulWidget {
  const AccountDrawer({super.key});

  @override
  State<AccountDrawer> createState() => _AccountDrawerState();
}

class _AccountDrawerState extends State<AccountDrawer> {
  Map<String, dynamic>? _user;
  double _cash = 0;
  List<dynamic> _holdings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.getMe().catchError((_) => <String, dynamic>{}),
        ApiService.getBalance().catchError((_) => 0.0),
        ApiService.getHoldings().catchError((_) => []),
      ]);
      if (!mounted) return;
      setState(() {
        _user = (results[0] as Map<String, dynamic>)['user'] as Map<String, dynamic>?;
        _cash = results[1] as double;
        _holdings = results[2] as List<dynamic>;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _invested => _holdings.fold(0.0, (sum, h) {
        final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
        final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
        return sum + qty * avg;
      });

  double get _totalValue => _invested + _cash;

  void _go(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final kycDone = _user?['kyc_completed'] == true;
    final name = (_user?['name'] as String?)?.trim();

    return Drawer(
      backgroundColor: AppColors.cardBackground,
      child: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        const CircleAvatar(radius: 18, backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white, size: 18)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Account', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              Text(
                                (name != null && name.isNotEmpty) ? name : 'Trader',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Value', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('₹${_totalValue.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 22)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Invested', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    Text('₹${_invested.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Cash', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                    Text('₹${_cash.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _go(const FundsScreen()),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                              child: const Text('Transfers', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!kycDone) ...[
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.pop(context);
                          context.go('/onboarding');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning.withValues(alpha: 0.3))),
                          child: Row(
                            children: [
                              const Icon(Icons.rocket_launch_outlined, color: AppColors.warning, size: 20),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text('Ready to invest with real money? Finish Application', style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.account_balance_outlined, color: AppColors.textSecondary),
                    title: const Text('Account Details', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    onTap: () => _go(const AccountDetailsScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined, color: AppColors.textSecondary),
                    title: const Text('Statements & Tax', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    onTap: () => _go(const StatementsTaxScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
                    title: const Text('Settings', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    onTap: () => _go(const SettingsScreen()),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 14, 20, 6),
                    child: Text('More', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  ...kMoreFeatures.map((item) => ListTile(
                        leading: Icon(item.icon, color: AppColors.textSecondary, size: 20),
                        title: Text(item.label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                        onTap: () {
                          Navigator.pop(context);
                          context.push(item.route);
                        },
                      )),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.danger),
                    title: const Text('Log Out', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 14)),
                    onTap: () async {
                      Navigator.pop(context);
                      await ApiService.clearToken();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
      ),
    );
  }
}