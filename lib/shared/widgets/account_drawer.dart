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
/// Matches the reference Account screen: avatar + verified name, Total
/// Value card with return badge, an "Unlock Pro Trading Tools" promo card,
/// a highlighted "Account Overview" row, then Account Details,
/// Statements & Tax and Settings, followed by the rest of the app's
/// features and Log Out.
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

  /// Unrealized return on invested capital, shown as the small badge next
  /// to Total Value (there's no separate "day open" figure available).
  double get _returnPercent => _invested > 0 ? ((_totalValue - _invested) / _invested) * 100 : 0;

  void _go(Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final name = (_user?['name'] as String?)?.trim();
    final displayName = (name != null && name.isNotEmpty) ? name : 'Trader';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T';
    final isUp = _returnPercent >= 0;

    return Drawer(
      backgroundColor: AppColors.cardBackground,
      child: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ===== Avatar + verified name + rocket badge =====
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary,
                          child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Account', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, color: AppColors.primary, size: 15),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF232C5C), Color(0xFF11142B)],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Positioned(top: 9, right: 12, child: Container(width: 2.5, height: 2.5, decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle))),
                              Positioned(top: 20, right: 6, child: Container(width: 1.5, height: 1.5, decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle))),
                              Positioned(bottom: 10, left: 9, child: Container(width: 1.5, height: 1.5, decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle))),
                              Center(
                                child: ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    begin: Alignment.bottomLeft,
                                    end: Alignment.topRight,
                                    colors: [Color(0xFF3B5BDB), Color(0xFFC7D2FF)],
                                  ).createShader(bounds),
                                  child: Transform.rotate(
                                    angle: -0.4,
                                    child: const Icon(Icons.rocket_launch, size: 30, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ===== Total Value card =====
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Total Value', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text('\u20b9${_totalValue.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 22)),
                                  ],
                                ),
                              ),
                              if (_invested > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isUp ? AppColors.success : AppColors.danger).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: (isUp ? AppColors.success : AppColors.danger).withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    '${isUp ? '+' : ''}${_returnPercent.toStringAsFixed(2)}%',
                                    style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.work_outline, color: AppColors.textMuted, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Invested', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                          Text('\u20b9${_invested.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.account_balance_outlined, color: AppColors.textMuted, size: 14),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Cash', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                          Text('\u20b9${_cash.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _go(const FundsScreen()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.add, size: 18, color: Colors.white),
                              label: const Text('Add Funds', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),


                  // ===== Account Overview (highlighted) =====
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: const Icon(Icons.pie_chart_outline, color: AppColors.primary),
                        title: const Text('Account Overview', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.account_balance_outlined, color: AppColors.textSecondary),
                    title: const Text('Account Details', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () => _go(const AccountDetailsScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.receipt_long_outlined, color: AppColors.textSecondary),
                    title: const Text('Statements & Tax', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    onTap: () => _go(const StatementsTaxScreen()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
                    title: const Text('Settings', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
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
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
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
