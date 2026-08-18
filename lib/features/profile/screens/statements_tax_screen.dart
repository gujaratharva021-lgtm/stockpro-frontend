import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/profile/screens/tradebook_screen.dart';
import 'package:stock_app/features/profile/screens/settings_screen.dart';
import 'package:stock_app/features/notifications/screens/notifications_screen.dart';
import 'package:stock_app/features/profile/screens/security_screen.dart';
import 'package:stock_app/features/tax/screens/pnl_report_screen.dart';

/// Combined "Statements & Tax" destination -- replaces the old "Support"
/// entry in the account drawer. Brings together Account Summary, Settings
/// and Statements & Tax in one place so nothing from any of those sections
/// is lost.
class StatementsTaxScreen extends StatefulWidget {
  const StatementsTaxScreen({super.key});

  @override
  State<StatementsTaxScreen> createState() => _StatementsTaxScreenState();
}

class _StatementsTaxScreenState extends State<StatementsTaxScreen> {
  bool _loading = true;
  double _cash = 0;
  double _currentValue = 0;
  double _realizedPnL = 0;
  double _unrealizedPnL = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.getBalance(),
        ApiService.getPnLReport().catchError((_) => <String, dynamic>{}),
      ]);
      final cash = results[0] as double;
      final report = results[1] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _cash = cash;
        _currentValue = (report['current_value'] as num?)?.toDouble() ?? 0;
        _realizedPnL = (report['realized_pnl'] as num?)?.toDouble() ?? 0;
        _unrealizedPnL = (report['unrealized_pnl'] as num?)?.toDouble() ?? 0;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(double v) => 'â‚¹${v.toStringAsFixed(2)}';

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label â€” coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Statements & Tax', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle('Account Summary'),
                _card([
                  _row('Net Liquidation Value', _fmt(_cash + _currentValue)),
                  _row('Cash', _fmt(_cash)),
                  _row('Settled Cash', _fmt(_cash)),
                  _row('MTD Interest', _fmt(0)),
                  _row('Stock', _fmt(_currentValue)),
                  _row('Unrealized P&L', _fmt(_unrealizedPnL), color: _unrealizedPnL >= 0 ? AppColors.success : AppColors.danger),
                  _row('Realized P&L', _fmt(_realizedPnL), color: _realizedPnL >= 0 ? AppColors.success : AppColors.danger),
                  _row('Initial Margin', _fmt(0)),
                  _row('Maintenance Margin', _fmt(0)),
                ]),
                const SizedBox(height: 24),
                _sectionTitle('Settings'),
                _card([
                  _navItem(Icons.person_outline, 'Account Settings', 'Personal Info, Permissions & More',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                  _navItem(Icons.account_circle_outlined, 'User Settings', 'Login, Communication & More',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                  _navItem(Icons.tune_outlined, 'Trading Presets', 'Customize Your Trade Defaults', onTap: () => _comingSoon('Trading Presets')),
                  _navItem(Icons.brightness_6_outlined, 'Display', 'App Theme & Accessibility', onTap: () => _comingSoon('Display')),
                  _navItem(Icons.article_outlined, 'News Language Settings', 'Filter news articles by selected languages', onTap: () => _comingSoon('News Language Settings')),
                  _navItem(Icons.notifications_outlined, 'Notifications', 'Push Notifications & Email',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
                  _navItem(Icons.shield_outlined, 'Security', 'Password, Privacy & 2FA',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen()))),
                  _navItem(Icons.public_outlined, 'Localization', 'Language, Base Currency & More', onTap: () => _comingSoon('Localization')),
                  _navItem(Icons.build_outlined, 'Advanced', 'Diagnostics, Debug & Extended Log', onTap: () => _comingSoon('Advanced'), showDivider: false),
                ]),
                const SizedBox(height: 24),
                _sectionTitle('Statements & Tax'),
                _card([
                  _navItem(Icons.description_outlined, 'Activity Statements', null, onTap: () => _comingSoon('Activity Statements')),
                  _navItem(Icons.insert_chart_outlined, 'Trade Reports', null,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TradebookScreen()))),
                  _navItem(Icons.file_download_outlined, 'Download Tax Forms', null,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PnLReportScreen()))),
                  _navItem(Icons.pie_chart_outline, 'Portfolio Analyst', null, onTap: () => context.push('/portfolio'), showDivider: false),
                ]),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(children: children),
      );

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
          Text(value, style: TextStyle(color: color ?? AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5)),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String title, String? subtitle, {required VoidCallback onTap, bool showDivider = true}) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
              ],
            ),
          ),
        ),
        if (showDivider) const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1, color: AppColors.border)),
      ],
    );
  }
}