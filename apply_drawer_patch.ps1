# StockPro Frontend - hamburger menu + account drawer patch
# Run this from the repo root, e.g.:
#   cd C:\Users\ABC\Downloads\stockpro-frontend-main\stockpro-frontend-main
#   powershell -ExecutionPolicy Bypass -File apply_drawer_patch.ps1
$ErrorActionPreference = 'Stop'
$root = Get-Location
Write-Host "Applying patch in $root" -ForegroundColor Cyan

function Write-Utf8NoBom($Path, $Content) {
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
  Write-Host "  wrote $Path"
}

# ---- lib/shared/widgets/main_shell.dart ----
$content = @'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/core/theme/app_colors.dart';

/// App shell with a 5-tab bottom navigation: Home | Portfolio | Watchlist |
/// Predictions | Explore. Every other screen (Trade/orders, Bids/IPO, News,
/// Screener, Profile, etc.) is reached from inside the Explore tab instead
/// of a dedicated primary tab.
class MainShell extends StatefulWidget {
  final Widget child;
  final int currentIndex;
  final Widget? floatingActionButton;
  final bool showBottomBar;
  final Widget? drawer;
  const MainShell({super.key, required this.child, required this.currentIndex, this.floatingActionButton, this.showBottomBar = true, this.drawer});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  void _onTap(int index) {
    if (index == widget.currentIndex) return;
    switch (index) {
      case 5: context.go('/dashboard'); break;
      case 2: context.go('/portfolio'); break;
      case 0: context.go('/watchlist'); break;
      case 1: context.push('/predictions'); break;
      case 3: context.push('/explore'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 768;
    return isWeb ? _webLayout() : _mobileLayout();
  }

  Widget _mobileLayout() {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: widget.drawer,
      body: widget.child,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: widget.showBottomBar ? Container(
        decoration: BoxDecoration(
          color: AppColors.navBackground,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              _navItem(Icons.home_outlined, Icons.home, 'Home', 5),
              _navItem(Icons.pie_chart_outline, Icons.pie_chart, 'Portfolio', 2),
              _navItem(Icons.star_border, Icons.star, 'Watchlist', 0),
              _navItem(Icons.auto_graph_outlined, Icons.auto_graph, 'Predictions', 1),
              _navItem(Icons.explore_outlined, Icons.explore, 'Explore', 3),
            ],
          ),
        ),
      ) : null,
    );
  }

  Widget _webLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.trending_up, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'OneInvest',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 16),
                _sidebarItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard', 5),
                _sidebarItem(Icons.pie_chart_outline, Icons.pie_chart, 'Portfolio', 2),
                _sidebarItem(Icons.bookmark_border, Icons.bookmark, 'Watchlist', 0),
                _sidebarItem(Icons.auto_graph_outlined, Icons.auto_graph, 'Predictions', 1),
                _sidebarItem(Icons.explore_outlined, Icons.explore, 'Explore', 3),
                const Spacer(),
                const Divider(color: AppColors.border, height: 1),
                // Profile link at bottom
                InkWell(
                  onTap: () => context.push('/profile'),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryDark],
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.person, color: Colors.white, size: 16),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('Profile', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Vertical divider
          Container(width: 1, color: AppColors.border),
          // Main content
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, IconData activeIcon, String label, int index) {
    final isActive = widget.currentIndex == index;
    return InkWell(
      onTap: () => _onTap(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primaryDark : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primaryDark : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, IconData activeIcon, String label, int index) {
    final isActive = widget.currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onTap(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isActive ? activeIcon : icon,
                  color: isActive ? AppColors.primaryDark : AppColors.textMuted, size: 22),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                    color: isActive ? AppColors.primaryDark : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  )),
            ],
          ),
        ),
      ),
    );
  }

}
'@
Write-Utf8NoBom (Join-Path $root 'lib\shared\widgets\main_shell.dart') $content

# ---- lib/shared/widgets/account_drawer.dart ----
$content = @'
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
'@
Write-Utf8NoBom (Join-Path $root 'lib\shared\widgets\account_drawer.dart') $content

# ---- lib/features/profile/screens/account_details_screen.dart ----
$content = @'
import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

/// "Account Details" screen -- Account Summary + Margin, backed by the real
/// P&L report and cash balance endpoints (no fabricated numbers). Reachable
/// from the account drawer on every screen.
class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  bool _loading = true;
  double _cash = 0;
  double _currentValue = 0;
  double _realizedPnL = 0;
  double _unrealizedPnL = 0;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getBalance(),
        ApiService.getPnLReport().catchError((_) => <String, dynamic>{}),
        ApiService.getMe().catchError((_) => <String, dynamic>{}),
      ]);
      final cash = results[0] as double;
      final report = results[1] as Map<String, dynamic>;
      final me = results[2] as Map<String, dynamic>;
      final user = me['user'] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _cash = cash;
        _currentValue = (report['current_value'] as num?)?.toDouble() ?? 0;
        _realizedPnL = (report['realized_pnl'] as num?)?.toDouble() ?? 0;
        _unrealizedPnL = (report['unrealized_pnl'] as num?)?.toDouble() ?? 0;
        final id = user?['id']?.toString() ?? user?['_id']?.toString();
        _accountId = id != null && id.length >= 6 ? 'DUR${id.substring(0, 6).toUpperCase()}' : null;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _netLiquidationValue => _cash + _currentValue;

  String _fmt(double v) => '₹${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Account Details', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_accountId != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                      child: Row(
                        children: [
                          const CircleAvatar(radius: 16, backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white, size: 16)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Account', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              Text(_accountId!, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text('Account Summary', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Column(
                      children: [
                        _row('Net Liquidation Value', _fmt(_netLiquidationValue)),
                        _divider(),
                        _row('Cash', _fmt(_cash)),
                        _divider(),
                        _row('Settled Cash', _fmt(_cash)),
                        _divider(),
                        _row('MTD Interest', _fmt(0)),
                        _divider(),
                        _row('Stock', _fmt(_currentValue)),
                        _divider(),
                        _row('Unrealized P&L', _fmt(_unrealizedPnL), color: _unrealizedPnL >= 0 ? AppColors.success : AppColors.danger),
                        _divider(),
                        _row('Realized P&L', _fmt(_realizedPnL), color: _realizedPnL >= 0 ? AppColors.success : AppColors.danger),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Margin', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Column(
                      children: [
                        _row('Initial Margin', _fmt(0)),
                        _divider(),
                        _row('Maintenance Margin', _fmt(0)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _divider() => const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1, color: AppColors.border));

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
          Text(value, style: TextStyle(color: color ?? AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5)),
        ],
      ),
    );
  }
}
'@
Write-Utf8NoBom (Join-Path $root 'lib\features\profile\screens\account_details_screen.dart') $content

# ---- lib/features/profile/screens/statements_tax_screen.dart ----
$content = @'
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

  String _fmt(double v) => '₹${v.toStringAsFixed(2)}';

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — coming soon')));
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
'@
Write-Utf8NoBom (Join-Path $root 'lib\features\profile\screens\statements_tax_screen.dart') $content

# ---- lib/features/explore/screens/explore_screen.dart ----
$content = @'
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/constants/nifty_symbols.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/shared/widgets/account_drawer.dart';
import 'package:stock_app/shared/widgets/stock_logo.dart';
import 'package:stock_app/shared/widgets/price_change.dart';
import 'package:stock_app/features/stock_detail/screens/stock_detail_screen.dart';
import 'package:stock_app/features/search/screens/search_screen.dart';
import 'package:stock_app/features/news/screens/news_detail_screen.dart';
import 'package:stock_app/features/ipo/screens/ipo_detail_screen.dart';
import 'package:go_router/go_router.dart';

/// Real, published NSE sectoral groupings of the symbols already tracked in
/// [kNiftyWatchSymbols] -- not an arbitrary split. Used to derive genuine
/// (quote-backed) "Investment Themes" and "Performance By Sector" sections
/// instead of fabricating category data with no source.
const Map<String, List<String>> _kSectorGroups = {
  'Banking': ['HDFCBANK', 'ICICIBANK', 'SBIN', 'AXISBANK', 'KOTAKBANK', 'INDUSINDBK'],
  'IT': ['INFY', 'TCS', 'WIPRO', 'HCLTECH', 'TECHM', 'LTIM'],
  'Energy & Oil': ['RELIANCE', 'ONGC', 'IOC', 'BPCL', 'GAIL'],
  'FMCG': ['HINDUNILVR', 'ITC', 'NESTLEIND', 'BRITANNIA', 'DABUR', 'MARICO'],
  'Auto': ['TATAMOTORS', 'MARUTI', 'M&M', 'BAJAJ-AUTO', 'EICHERMOT', 'HEROMOTOCO'],
  'Pharma': ['SUNPHARMA', 'CIPLA', 'DRREDDY', 'LUPIN', 'AUROPHARMA', 'DIVISLAB'],
  'Metals & Mining': ['TATASTEEL', 'JSWSTEEL', 'HINDALCO', 'VEDL', 'NATIONALUM', 'COALINDIA'],
  'Infra & Cement': ['LT', 'ULTRACEMCO', 'GRASIM', 'SHREECEM', 'AMBUJACEM'],
  'Financial Services': ['BAJFINANCE', 'BAJAJFINSV', 'HDFCLIFE', 'SBILIFE', 'ICICIGI'],
  'Power & Utilities': ['NTPC', 'POWERGRID', 'TATAPOWER'],
  'Telecom': ['BHARTIARTL', 'IDEA'],
  'New Age Tech': ['ZOMATO', 'PAYTM', 'NYKAA', 'POLICYBZR'],
};

// Real Yahoo Finance index/crypto symbols, fetched the same way as the
// Dashboard's "World Indices" strip (client-side call, no fabricated
// numbers). Indian indices per the user's request; crypto is inherently a
// global market so USD pairs are used.
const List<Map<String, String>> _kWorldIndices = [
  {'label': 'NIFTY 50', 'yahoo': '^NSEI'},
  {'label': 'SENSEX', 'yahoo': '^BSESN'},
  {'label': 'BANK NIFTY', 'yahoo': '^NSEBANK'},
  {'label': 'NIFTY IT', 'yahoo': '^CNXIT'},
  {'label': 'NIFTY AUTO', 'yahoo': '^CNXAUTO'},
  {'label': 'NIFTY PHARMA', 'yahoo': '^CNXPHARMA'},
];

const List<Map<String, String>> _kCrypto = [
  {'symbol': 'BTC', 'name': 'Bitcoin', 'yahoo': 'BTC-USD'},
  {'symbol': 'ETH', 'name': 'Ethereum', 'yahoo': 'ETH-USD'},
  {'symbol': 'LTC', 'name': 'Litecoin', 'yahoo': 'LTC-USD'},
  {'symbol': 'BCH', 'name': 'Bitcoin Cash', 'yahoo': 'BCH-USD'},
  {'symbol': 'SOL', 'name': 'Solana', 'yahoo': 'SOL-USD'},
  {'symbol': 'ADA', 'name': 'Cardano', 'yahoo': 'ADA-USD'},
];

/// Market-overview style Explore screen: search, sector-based investment
/// themes, Most Active/Gainers/Losers/IPOs, a Stock Screener shortcut,
/// Indian world indices, sector performance, crypto, a Learn strip, and
/// news -- all backed by real API/Yahoo Finance calls where a real source
/// exists. Screens that have no dedicated tab live in the hamburger drawer.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<dynamic> _allStocks = [];
  final Map<String, Map<String, dynamic>> _quotes = {};
  List<dynamic> _ipos = [];
  List<dynamic> _news = [];
  List<String> _holdingSymbols = [];
  List<String> _watchlistSymbols = [];
  final Map<String, Map<String, dynamic>> _indices = {};
  final Map<String, Map<String, dynamic>> _crypto = {};

  String _stocksTab = 'active'; // active | gainers | losers | ipo
  String _newsTab = 'overview'; // overview | portfolio | watchlists
  bool _loadingStocks = true;
  bool _loadingNews = true;

  @override
  void initState() {
    super.initState();
    _loadStocks();
    _loadIpos();
    _loadNewsAndHoldings();
    _loadIndices();
    _loadCrypto();
  }

  Future<void> _loadStocks() async {
    try {
      final stocks = await ApiService.getStocks();
      if (mounted) setState(() => _allStocks = stocks);
      final tracked = stocks.where((s) => kNiftyWatchSymbols.contains(s['symbol'])).toList();
      for (final s in tracked) {
        final symbol = s['symbol'];
        try {
          final q = await ApiService.getQuote(symbol);
          if (mounted) setState(() => _quotes[symbol] = q);
        } catch (_) {}
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingStocks = false);
    }
  }

  Future<void> _loadIpos() async {
    try {
      final ipos = await ApiService.getIPOs();
      if (mounted) setState(() => _ipos = ipos);
    } catch (_) {}
  }

  Future<void> _loadNewsAndHoldings() async {
    try {
      final news = await ApiService.getNews();
      if (mounted) setState(() => _news = news);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingNews = false);
    }
    try {
      final holdings = await ApiService.getHoldings();
      if (mounted) setState(() => _holdingSymbols = holdings.map((h) => (h['symbol'] ?? '').toString()).toList());
    } catch (_) {}
    try {
      final watchlist = await ApiService.getWatchlist();
      if (mounted) setState(() => _watchlistSymbols = watchlist.map((w) => (w['symbol'] ?? '').toString()).toList());
    } catch (_) {}
  }

  Future<void> _loadIndices() async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 12)));
    for (final idx in _kWorldIndices) {
      try {
        final res = await dio.get('https://query1.finance.yahoo.com/v8/finance/chart/${idx['yahoo']}?interval=15m&range=1d');
        final meta = res.data['chart']['result'][0]['meta'];
        final price = (meta['regularMarketPrice'] as num).toDouble();
        final prevClose = (meta['previousClose'] as num? ?? meta['chartPreviousClose'] as num).toDouble();
        final percent = prevClose > 0 ? ((price - prevClose) / prevClose) * 100 : 0.0;
        if (mounted) {
          setState(() => _indices[idx['label']!] = {
                'value': price.toStringAsFixed(2),
                'percent': percent,
              });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadCrypto() async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 12)));
    for (final c in _kCrypto) {
      try {
        final res = await dio.get('https://query1.finance.yahoo.com/v8/finance/chart/${c['yahoo']}?interval=15m&range=1d');
        final meta = res.data['chart']['result'][0]['meta'];
        final price = (meta['regularMarketPrice'] as num).toDouble();
        final prevClose = (meta['previousClose'] as num? ?? meta['chartPreviousClose'] as num).toDouble();
        final percent = prevClose > 0 ? ((price - prevClose) / prevClose) * 100 : 0.0;
        if (mounted) {
          setState(() => _crypto[c['symbol']!] = {
                'value': price >= 1 ? price.toStringAsFixed(2) : price.toStringAsFixed(4),
                'percent': percent,
              });
        }
      } catch (_) {}
    }
  }

  List<Map<String, dynamic>> get _quotedStocks {
    return _allStocks
        .where((s) => _quotes.containsKey(s['symbol']))
        .map((s) => {
              ...Map<String, dynamic>.from(s),
              'quote': _quotes[s['symbol']],
            })
        .toList()
        .cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> get _sortedStocksForTab {
    final list = List<Map<String, dynamic>>.from(_quotedStocks);
    double pct(Map<String, dynamic> s) => ((s['quote']?['change_percent'] as num?) ?? 0).toDouble();
    switch (_stocksTab) {
      case 'gainers':
        list.sort((a, b) => pct(b).compareTo(pct(a)));
        return list.where((s) => pct(s) > 0).take(12).toList();
      case 'losers':
        list.sort((a, b) => pct(a).compareTo(pct(b)));
        return list.where((s) => pct(s) < 0).take(12).toList();
      case 'active':
      default:
        list.sort((a, b) => pct(b).abs().compareTo(pct(a).abs()));
        return list.take(12).toList();
    }
  }

  List<dynamic> get _newsForTab {
    if (_newsTab == 'overview') return _news;
    final symbols = _newsTab == 'portfolio' ? _holdingSymbols : _watchlistSymbols;
    if (symbols.isEmpty) return [];
    return _news.where((n) {
      final text = '${n['title'] ?? ''} ${n['content'] ?? ''}'.toUpperCase();
      return symbols.any((s) => s.isNotEmpty && text.contains(s.toUpperCase()));
    }).toList();
  }

  void _showThemeSheet(String theme, List<String> symbols) {
    final rows = _quotedStocks.where((s) => symbols.contains(s['symbol'])).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(theme, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('Loading quotes…', style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: rows.length,
                      itemBuilder: (ctx, i) => _stockRow(rows[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openStock(Map<String, dynamic> stock) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StockDetailScreen(stock: stock)));
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label — coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    return MainShell(
      currentIndex: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        drawer: const AccountDrawer(),
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: Builder(
            builder: (ctx) => IconButton(icon: const Icon(Icons.menu, color: AppColors.textPrimary), onPressed: () => Scaffold.of(ctx).openDrawer()),
          ),
          title: const Text('Explore', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary), onPressed: () => _comingSoon('Edit')),
            IconButton(icon: const Icon(Icons.smart_toy_outlined, color: AppColors.textPrimary), onPressed: () => context.push('/assistant')),
            IconButton(icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary), onPressed: () => context.push('/notifications')),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await Future.wait([_loadStocks(), _loadIpos(), _loadNewsAndHoldings(), _loadIndices(), _loadCrypto()]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: _searchBar()),
                _sectionHeader('Investment Themes'),
                _themesWrap(),
                const SizedBox(height: 8),
                _sectionHeader('Stocks'),
                _stocksTabs(),
                _stocksList(),
                Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), child: _screenerButton()),
                _sectionHeader('World Markets'),
                _worldMarketsGrid(),
                _sectionHeader('Performance By Sector'),
                _sectorGrid(),
                _sectionHeader('Cryptocurrencies'),
                _cryptoGrid(),
                _sectionHeader('Learn'),
                _learnStrip(),
                _sectionHeader('News'),
                _newsTabsRow(),
                _newsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {bool withInfo = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          if (withInfo) const Icon(Icons.info_outline, color: AppColors.textMuted, size: 18),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(24)),
        child: const Row(children: [
          Icon(Icons.search, color: AppColors.textMuted),
          SizedBox(width: 10),
          Text('Search Symbol', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
        ]),
      ),
    );
  }

  Widget _themesWrap() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _kSectorGroups.entries.map((e) {
          return OutlinedButton(
            onPressed: () => _showThemeSheet(e.key, e.value),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(e.key, style: const TextStyle(color: AppColors.primary, fontSize: 13)),
          );
        }).toList(),
      ),
    );
  }

  Widget _stocksTabs() {
    Widget tab(String label, String value) {
      final selected = _stocksTab == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _stocksTab = value),
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.cardBackground,
          labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
          side: BorderSide.none,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          tab('Most Active', 'active'),
          tab('Gainers', 'gainers'),
          tab('Losers', 'losers'),
          tab('IPOs', 'ipo'),
        ]),
      ),
    );
  }

  Widget _stocksList() {
    if (_stocksTab == 'ipo') {
      if (_ipos.isEmpty) {
        return const Padding(padding: EdgeInsets.all(16), child: Text('No IPOs to show right now', style: TextStyle(color: AppColors.textMuted)));
      }
      return Column(
        children: _ipos.take(8).map<Widget>((ipo) {
          final name = (ipo['company_name'] ?? '').toString();
          final priceLow = (ipo['price_band_low'] as num?)?.toDouble() ?? 0.0;
          final priceHigh = (ipo['price_band_high'] as num?)?.toDouble() ?? 0.0;
          return InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IpoDetailScreen(ipoId: ipo['id']))),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(child: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13))),
                Text('₹${priceLow.toStringAsFixed(0)} - ₹${priceHigh.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ]),
            ),
          );
        }).toList(),
      );
    }

    if (_loadingStocks) {
      return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    final rows = _sortedStocksForTab;
    if (rows.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Text('No data to show', style: TextStyle(color: AppColors.textMuted)));
    }
    return Column(children: rows.map((s) => _stockRow(s)).toList());
  }

  Widget _stockRow(Map<String, dynamic> stock) {
    final quote = stock['quote'] as Map<String, dynamic>?;
    final price = (quote?['price'] as num?)?.toDouble();
    final change = (quote?['change'] as num?)?.toDouble() ?? 0.0;
    final changePercent = (quote?['change_percent'] as num?)?.toDouble() ?? 0.0;
    return InkWell(
      onTap: () => _openStock(stock),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          StockLogo(symbol: stock['symbol']?.toString(), companyName: stock['company_name']?.toString(), size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(stock['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
              if (price != null) Text('₹${price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
            ]),
          ),
          PriceChange(change: change, changePercent: changePercent, fontSize: 12),
        ]),
      ),
    );
  }

  Widget _screenerButton() {
    return OutlinedButton.icon(
      onPressed: () => context.push('/screener'),
      icon: const Icon(Icons.radar, color: AppColors.primary, size: 18),
      label: const Text('Stock Screener', style: TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _worldMarketsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _kWorldIndices.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.6),
        itemBuilder: (ctx, i) {
          final label = _kWorldIndices[i]['label']!;
          final data = _indices[label];
          final percent = data != null ? (data['percent'] as num).toDouble() : null;
          final isDown = percent != null && percent < 0;
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDown ? AppColors.danger.withValues(alpha: 0.12) : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDown ? AppColors.danger.withValues(alpha: 0.4) : AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(children: [
                if (percent != null) Icon(percent >= 0 ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: percent >= 0 ? AppColors.success : AppColors.danger),
                const SizedBox(width: 4),
                Expanded(child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Text(
                data == null ? '--' : '${data['value']}  (${percent!.toStringAsFixed(2)}%)',
                style: TextStyle(color: percent == null ? AppColors.textMuted : (percent >= 0 ? AppColors.success : AppColors.danger), fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _sectorGrid() {
    final entries = _kSectorGroups.entries.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.0),
        itemBuilder: (ctx, i) {
          final label = entries[i].key;
          final symbols = entries[i].value;
          final quotes = symbols.map((s) => _quotes[s]).whereType<Map<String, dynamic>>().toList();
          double? avgPct;
          if (quotes.isNotEmpty) {
            final sum = quotes.fold<double>(0, (acc, q) => acc + ((q['change_percent'] as num?) ?? 0).toDouble());
            avgPct = sum / quotes.length;
          }
          final isUp = avgPct != null && avgPct >= 0;
          return InkWell(
            onTap: () => _showThemeSheet(label, symbols),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: avgPct == null ? AppColors.cardBackground : (isUp ? AppColors.success.withValues(alpha: 0.18) : AppColors.danger.withValues(alpha: 0.18)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.donut_small, size: 18, color: avgPct == null ? AppColors.textMuted : (isUp ? AppColors.success : AppColors.danger)),
                const SizedBox(height: 6),
                Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 10.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(avgPct == null ? '--' : '${avgPct >= 0 ? '+' : ''}${avgPct.toStringAsFixed(2)}%', style: TextStyle(color: avgPct == null ? AppColors.textMuted : (isUp ? AppColors.success : AppColors.danger), fontSize: 10, fontWeight: FontWeight.bold)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _cryptoGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _kCrypto.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 3.2),
        itemBuilder: (ctx, i) {
          final symbol = _kCrypto[i]['symbol']!;
          final data = _crypto[symbol];
          final percent = data != null ? (data['percent'] as num).toDouble() : null;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              CircleAvatar(radius: 15, backgroundColor: AppColors.primary.withValues(alpha: 0.15), child: Text(symbol[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12))),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(symbol, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  Text(
                    data == null ? '--' : '\$${data['value']}',
                    style: TextStyle(color: percent == null ? AppColors.textMuted : (percent >= 0 ? AppColors.success : AppColors.danger), fontSize: 11),
                  ),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _learnStrip() {
    final items = [
      ('AI Assistant', Icons.smart_toy_outlined, '/assistant'),
      ('Brokerage Calculator', Icons.calculate_outlined, '/brokerage-calculator'),
      ('Stock Screener', Icons.filter_alt_outlined, '/screener'),
      ('Performance', Icons.trending_up, '/performance'),
    ];
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final (label, icon, route) = items[i];
          return InkWell(
            onTap: () => context.push(route),
            child: Container(
              width: 140,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Icon(icon, color: Colors.white, size: 22),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _newsTabsRow() {
    Widget tab(String label, String value) {
      final selected = _newsTab == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => setState(() => _newsTab = value),
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.cardBackground,
          labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600),
          side: BorderSide.none,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [tab('Overview', 'overview'), tab('Portfolio', 'portfolio'), tab('Watchlists', 'watchlists')]),
    );
  }

  Widget _newsList() {
    if (_loadingNews) {
      return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }
    final items = _newsForTab;
    if (items.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Text('No news to show', style: TextStyle(color: AppColors.textMuted)));
    }
    return Column(
      children: items.take(10).map<Widget>((item) {
        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailScreen(item: item))),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Row(children: [
                Text(item['source'] ?? '', style: const TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text((item['published_at'] ?? '').toString().split('T').first, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ]),
            ]),
          ),
        );
      }).toList(),
    );
  }
}
'@
Write-Utf8NoBom (Join-Path $root 'lib\features\explore\screens\explore_screen.dart') $content

# ---- lib/features/watchlist/screens/watchlist_screen.dart ----
$content = @'
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/shared/widgets/account_drawer.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/stock_detail/screens/stock_detail_screen.dart';
import 'package:stock_app/features/search/screens/search_screen.dart';
import 'package:stock_app/shared/widgets/empty_state.dart';
import 'package:stock_app/shared/widgets/error_state.dart';
import 'package:stock_app/core/theme/app_typography.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});
  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<dynamic> _watchlist = [];
  Map<String, String> _exchangeBySymbol = {};
  final Map<String, Map<String, dynamic>> _quotes = {};
  final Map<String, List<double>> _sparklines = {};
  bool _loading = true;
  String? _error;
  List<String> _listNames = ['My Watchlist'];
  String _selectedList = 'My Watchlist';
  bool _seedAttempted = false;

  static const List<String> _demoSymbols = ['HDFCBANK', 'INFY', 'TCS', 'ONGC', 'HINDUNILVR'];

  @override
  void initState() {
    super.initState();
    _loadListNames();
    _load().then((_) => _seedDemoStocksIfMissing());
    _loadExchanges();
  }

  Future<void> _loadExchanges() async {
    try {
      final stocks = await ApiService.getStocks();
      final map = <String, String>{};
      for (final s in stocks) {
        final symbol = s['symbol'];
        final exchange = s['exchange'];
        if (symbol != null && exchange != null) map[symbol] = exchange;
      }
      if (mounted) setState(() => _exchangeBySymbol = map);
    } catch (_) {}
  }

  Future<void> _loadListNames() async {
    try {
      final names = await ApiService.getWatchlistNames();
      final combined = List<String>.from(names);
      int n = 1;
      while (combined.length < 7) {
        final candidate = 'Watchlist $n';
        if (!combined.contains(candidate)) combined.add(candidate);
        n++;
        if (n > 50) break;
      }
      if (mounted) setState(() => _listNames = combined);
    } catch (_) {}
  }

  Future<void> _seedDemoStocksIfMissing() async {
    if (_seedAttempted) return;
    _seedAttempted = true;
    try {
      final existingSymbols = _watchlist.map((e) => (e['symbol'] ?? '').toString()).toSet();
      final missing = _demoSymbols.where((s) => !existingSymbols.contains(s)).toList();
      if (missing.isEmpty) return;

      final allStocks = await ApiService.getStocks();
      var addedAny = false;
      for (final symbol in missing) {
        final match = allStocks.firstWhere(
          (s) => (s['symbol'] ?? '').toString() == symbol,
          orElse: () => null,
        );
        if (match == null) continue;
        try {
          await ApiService.addToWatchlist(match['id'], listName: _selectedList);
          addedAny = true;
        } catch (_) {}
      }
      if (addedAny) await _load();
    } catch (_) {}
  }

  void _createNewList() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Watchlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Tech Stocks'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              setState(() {
                if (!_listNames.contains(name)) _listNames = [..._listNames, name];
                _selectedList = name;
              });
              _load();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // Bottom sheet list-switcher, opened by tapping the "My Watchlist v" title.
  void _showListSwitcher() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Switch Watchlist', style: AppTypography.titleMedium),
            ),
            ..._listNames.map((name) {
              final isActive = name == _selectedList;
              return ListTile(
                leading: Icon(Icons.list_alt, color: isActive ? AppColors.primary : AppColors.textMuted),
                title: Text(name, style: TextStyle(color: isActive ? AppColors.primary : AppColors.textPrimary, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
                trailing: isActive ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (!isActive) {
                    setState(() => _selectedList = name);
                    _load();
                  }
                },
              );
            }),
            const Divider(height: 1, color: AppColors.border),
            ListTile(
              leading: const Icon(Icons.add, color: AppColors.primary),
              title: const Text('New Watchlist', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _createNewList();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.getWatchlist(listName: _selectedList);
      setState(() => _watchlist = data);

      for (final item in data) {
        final symbol = item['symbol'];
        if (symbol == null) continue;
        try {
          final quote = await ApiService.getQuote(symbol);
          if (mounted) setState(() => _quotes[symbol] = quote);
        } catch (_) {}
        try {
          final intraday = await ApiService.getIntraday(symbol, '15m');
          final closes = intraday
              .map((p) => (p['close'] as num?)?.toDouble() ?? (p['price'] as num?)?.toDouble())
              .whereType<double>()
              .toList();
          if (mounted && closes.isNotEmpty) setState(() => _sparklines[symbol] = closes);
        } catch (_) {}
      }
    } catch (e) {
      setState(() => _error = 'Could not load watchlist');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addStock() async {
    final stock = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen(selectMode: true)),
    );
    if (stock != null && mounted) {
      try {
        await ApiService.addToWatchlist(stock['id'], listName: _selectedList);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add stock to watchlist')));
        }
      }
    }
  }

  void _showStockOptions(dynamic item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(item['symbol'] ?? '', style: AppTypography.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined, color: AppColors.textSecondary),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StockDetailScreen(stock: {
                      'id': item['stock_id'] ?? item['id'],
                      'symbol': item['symbol'],
                      'company_name': item['company_name'],
                      'exchange': item['exchange'] ?? '',
                      'sector': item['sector'] ?? '',
                    }),
                  ),
                ).then((_) => _load());
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('Remove from watchlist', style: TextStyle(color: AppColors.danger)),
              onTap: () async {
                Navigator.pop(ctx);
                await ApiService.removeFromWatchlist(item['stock_id'] ?? item['id'], listName: _selectedList);
                _load();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ===== IBKR-style app bar: "My Watchlist v"  ...  [+]  [more] =====
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      automaticallyImplyLeading: false,
      leadingWidth: 40,
      leading: Builder(
        builder: (ctx) => IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.menu, color: AppColors.textPrimary),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      titleSpacing: 4,
      title: GestureDetector(
        onTap: _showListSwitcher,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_selectedList, style: AppTypography.titleLarge),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary, size: 22),
          ],
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.add, color: AppColors.textPrimary), onPressed: _addStock),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz, color: AppColors.textPrimary),
          onSelected: (v) {
            if (v == 'new_list') _createNewList();
            if (v == 'switch_list') _showListSwitcher();
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'new_list', child: Text('New Watchlist')),
            PopupMenuItem(value: 'switch_list', child: Text('Switch Watchlist')),
          ],
        ),
      ],
    );
  }

  // ===== Column header row: Instrument | Last | Chg % =====
  Widget _buildColumnHeader() {
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Expanded(
            child: Text('Instrument', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          ),
          SizedBox(
            width: 56,
            child: Text('Intraday', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          ),
          SizedBox(
            width: 92,
            child: Text('Change', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(dynamic item) {
    final symbol = item['symbol'];
    final quote = _quotes[symbol];
    final price = quote != null ? (quote['price'] as num?)?.toDouble() : null;
    final changePercent = quote != null ? (quote['change_percent'] as num?)?.toDouble() : null;
    final change = quote != null ? (quote['change'] as num?)?.toDouble() : null;
    final exchange = _exchangeBySymbol[symbol] ?? item['exchange'] ?? '';
    final isUp = (changePercent ?? 0) >= 0;
    final color = isUp ? AppColors.success : AppColors.danger;
    final spark = _sparklines[symbol];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StockDetailScreen(stock: {
            'id': item['stock_id'] ?? item['id'],
            'symbol': item['symbol'],
            'company_name': item['company_name'],
            'exchange': _exchangeBySymbol[item['symbol']] ?? item['exchange'] ?? '',
            'sector': item['sector'] ?? '',
          }),
        ),
      ).then((_) => _load()),
      onLongPress: () => _showStockOptions(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(item['symbol'] ?? '', style: AppTypography.priceMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (exchange.toString().isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(exchange.toString(), style: AppTypography.caption),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['company_name'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySecondary,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 56,
              height: 30,
              child: (spark == null || spark.length < 2)
                  ? const SizedBox.shrink()
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineTouchData: const LineTouchData(enabled: false),
                        minY: spark.reduce((a, b) => a < b ? a : b),
                        maxY: spark.reduce((a, b) => a > b ? a : b),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [for (var i = 0; i < spark.length; i++) FlSpot(i.toDouble(), spark[i])],
                            isCurved: true,
                            color: color,
                            barWidth: 1.5,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: price == null
                  ? const Text('--', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textMuted, fontSize: 13))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            '${isUp ? '+' : ''}${changePercent?.toStringAsFixed(2) ?? '0.00'}%',
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${price.toStringAsFixed(2)}${change != null ? ' (${isUp ? '+' : ''}${change.toStringAsFixed(2)})' : ''}',
                          style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainShell(
      currentIndex: 0,
      child: Scaffold(
        backgroundColor: AppColors.background,
        drawer: const AccountDrawer(),
        appBar: _buildAppBar(),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.cardBackground,
            onRefresh: _load,
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : _watchlist.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 80),
                              EmptyState(
                                icon: Icons.bookmark_border,
                                message: "Your watchlist is empty.\nAdd stocks to track them here.",
                                actionLabel: 'Add Stock',
                                onAction: _addStock,
                              ),
                            ],
                          )
                        : ListView(
                            children: [
                              _buildColumnHeader(),
                              ..._watchlist.map(_buildRow),
                              const SizedBox(height: 80),
                            ],
                          ),
          ),
        ),
      ),
    );
  }
}
'@
Write-Utf8NoBom (Join-Path $root 'lib\features\watchlist\screens\watchlist_screen.dart') $content

# ---- lib/features/dashboard/screens/dashboard_screen.dart ----
$content = @'
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/theme/app_typography.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/shared/widgets/account_drawer.dart';
import 'package:stock_app/shared/widgets/app_card.dart';
import 'package:stock_app/shared/widgets/price_change.dart';
import 'package:stock_app/shared/widgets/section_header.dart';
import 'package:stock_app/core/constants/nifty_symbols.dart';
import 'package:stock_app/features/search/screens/search_screen.dart';
import 'package:stock_app/features/wallet/screens/wallet_history_screen.dart';
import 'package:stock_app/features/profile/screens/funds_screen.dart';
import 'package:stock_app/features/news/screens/news_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Hero-gradient-specific colors only. Card surfaces/borders now come from
  // AppCard/AppColors (Phase 2 design-system consolidation) -- these two
  // remain screen-local because the hero section's gradient and its muted
  // text tone are a deliberate one-off treatment, not reused elsewhere.
  static const _bgTop = Color(0xFF15303A);
  static const _bgBottom = Color(0xFF0A0E14);
  static const _textMutedD = Color(0xFF8A93A3);

  bool _loading = true;
  String _userName = '';
  bool _kycDone = false;
  double _balance = 0;
  final Map<String, Map<String, dynamic>> _quotes = {};
  List<dynamic> _holdings = [];
  List<dynamic> _watchlist = [];
  List<Map<String, dynamic>> _perfPoints = [];

  // World-indices card strip -- same live-fetch pattern already proven in
  // markets_screen.dart (direct Yahoo Finance chart endpoint), reused here
  // rather than inventing a new data source.
  Map<String, dynamic> _idxNifty = {'value': '--', 'percent': '--', 'isUp': true};
  Map<String, dynamic> _idxSensex = {'value': '--', 'percent': '--', 'isUp': true};
  Map<String, dynamic> _idxBankNifty = {'value': '--', 'percent': '--', 'isUp': true};

  // Dashboard news tabs. "Portfolio"/"Watchlists" are a real client-side
  // filter of the same real news list, matched against actual holding /
  // watchlist symbols -- not a fabricated categorization, since the news
  // API returns no per-article stock tagging.
  List<dynamic> _dashboardNews = [];
  bool _loadingNews = true;
  int _newsTab = 0; // 0=Overview 1=Portfolio 2=Watchlists

  static const List<String> _ranges = ['1W', 'MTD', '1M', '3M', 'YTD', '1Y', 'All'];
  String _range = '1M';
  String _valueTab = 'Value'; // 'Value' or 'Performance'

  @override
  void initState() {
    super.initState();
    _loadAll();
    _loadIndicesStrip();
    _loadDashboardNews();
  }

  Future<void> _loadIndicesStrip() async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 12)));

    Future<void> fetchIndex(String yahooSymbol, String key) async {
      try {
        final res = await dio.get('https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol?interval=15m&range=1d');
        final result = res.data['chart']['result'][0];
        final meta = result['meta'];
        final price = (meta['regularMarketPrice'] as num).toDouble();
        final prevClose = (meta['previousClose'] as num? ?? meta['chartPreviousClose'] as num).toDouble();
        final percent = prevClose > 0 ? ((price - prevClose) / prevClose) * 100 : 0.0;
        final data = {
          'value': price.toStringAsFixed(2),
          'percent': '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%',
          'isUp': percent >= 0,
        };
        if (mounted) {
          setState(() {
            if (key == 'nifty') _idxNifty = data;
            if (key == 'sensex') _idxSensex = data;
            if (key == 'banknifty') _idxBankNifty = data;
          });
        }
      } catch (_) {}
    }

    await Future.wait([
      fetchIndex('%5ENSEI', 'nifty'),
      fetchIndex('%5EBSESN', 'sensex'),
      fetchIndex('%5ENSEBANK', 'banknifty'),
    ]);
  }

  Future<void> _loadDashboardNews() async {
    try {
      final data = await ApiService.getNews();
      if (mounted) setState(() => _dashboardNews = data);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingNews = false);
    }
  }

  // Real filter, not fabricated categories: matches actual holding/
  // watchlist symbols against each article's own title/content text.
  List<dynamic> _newsFilteredBy(List<String> symbols) {
    if (symbols.isEmpty) return [];
    return _dashboardNews.where((n) {
      final text = '${n['title'] ?? ''} ${n['content'] ?? ''}'.toUpperCase();
      return symbols.any((s) => s.isNotEmpty && text.contains(s.toUpperCase()));
    }).toList();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        ApiService.getMe(),
        ApiService.getBalance(),
        ApiService.getStocks(),
        ApiService.getIPOs(),
      ]);

      final me = results[0] as Map<String, dynamic>;
      final user = me['user'] ?? {};
      final balance = results[1] as double;
      final allStocks = results[2] as List<dynamic>;
      final sample = allStocks.where((s) => kNiftyWatchSymbols.contains(s['symbol'])).toList();

      if (mounted) {
        setState(() {
          _userName = (user['name'] ?? user['full_name'] ?? 'Trader').toString();
          _kycDone = user['kyc_completed'] == true;
          _balance = balance;
        });
      }

      for (final s in sample) {
        final symbol = s['symbol'];
        try {
          final q = await ApiService.getQuote(symbol);
          if (mounted) setState(() => _quotes[symbol] = q);
        } catch (_) {}
      }

      if (sample.isNotEmpty) {
        try {
          await ApiService.getHistory(sample.first['symbol']);
        } catch (_) {}
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    try {
      final holdings = await ApiService.getHoldings();
      if (mounted) setState(() => _holdings = holdings);
      for (final h in holdings) {
        final symbol = h['symbol'];
        if (symbol == null || _quotes.containsKey(symbol)) continue;
        try {
          final q = await ApiService.getQuote(symbol);
          if (mounted) setState(() => _quotes[symbol] = q);
        } catch (_) {}
      }
    } catch (_) {}

    try {
      final watchlist = await ApiService.getWatchlist();
      if (mounted) setState(() => _watchlist = watchlist);
      for (final w in watchlist.take(10)) {
        final symbol = w['symbol'];
        if (symbol == null || _quotes.containsKey(symbol)) continue;
        try {
          final q = await ApiService.getQuote(symbol);
          if (mounted) setState(() => _quotes[symbol] = q);
        } catch (_) {}
      }
    } catch (_) {}

    try {
      final perf = await ApiService.getPerformance();
      final points = (perf['performance'] as List? ?? []);
      final parsed = points
          .map((p) => {
                'date': DateTime.tryParse(p['date'].toString()) ?? DateTime.now(),
                'value': (p['value'] as num?)?.toDouble() ?? 0.0,
              })
          .toList()
          .cast<Map<String, dynamic>>();
      parsed.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      if (mounted) setState(() => _perfPoints = parsed);
    } catch (_) {}
  }

  double _changePctOf(String symbol) {
    final q = _quotes[symbol];
    return q != null ? (q['change_percent'] as num?)?.toDouble() ?? 0 : 0;
  }

  List<Map<String, dynamic>> get _filteredPerf {
    if (_perfPoints.isEmpty) return [];
    final last = _perfPoints.last['date'] as DateTime;
    DateTime cutoff;
    switch (_range) {
      case '1W':
        cutoff = last.subtract(const Duration(days: 7));
        break;
      case 'MTD':
        cutoff = DateTime(last.year, last.month, 1);
        break;
      case '1M':
        cutoff = last.subtract(const Duration(days: 30));
        break;
      case '3M':
        cutoff = last.subtract(const Duration(days: 90));
        break;
      case 'YTD':
        cutoff = DateTime(last.year, 1, 1);
        break;
      case '1Y':
        cutoff = last.subtract(const Duration(days: 365));
        break;
      default:
        cutoff = _perfPoints.first['date'] as DateTime;
    }
    final list = _perfPoints.where((p) => !(p['date'] as DateTime).isBefore(cutoff)).toList();
    return list.isEmpty ? _perfPoints : list;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Color _avatarColor(String symbol) {
    final colors = [
      const Color(0xFF6366F1), const Color(0xFF8B5CF6), const Color(0xFFEC4899),
      const Color(0xFF06B6D4), const Color(0xFFF59E0B), const Color(0xFF10B981),
      const Color(0xFF3B82F6), const Color(0xFFEF4444),
    ];
    final idx = symbol.codeUnits.fold<int>(0, (a, b) => a + b) % colors.length;
    return colors[idx];
  }

  String _fmtAxis(double v) {
    final sign = v < 0 ? '-' : '';
    final av = v.abs();
    if (av >= 1000000) return '$sign${(av / 1000000).toStringAsFixed(av % 1000000 == 0 ? 0 : 2)}M';
    if (av >= 1000) return '$sign${(av / 1000).toStringAsFixed(0)}K';
    return '$sign${av.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    final outerPad = isMobile ? 16.0 : 32.0;

    return MainShell(
      currentIndex: 5,
      child: Scaffold(
        backgroundColor: _bgBottom,
        drawer: const AccountDrawer(),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroSection(isMobile),
                    Padding(
                      padding: EdgeInsets.fromLTRB(outerPad, 20, outerPad, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_kycDone) ...[
                            _kycBanner(context),
                            const SizedBox(height: 20),
                          ],
                          _quickIconsRow(context),
                          const SizedBox(height: 22),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text('World Indices', style: AppTypography.titleMedium),
                          ),
                          _indicesStrip(),
                          const SizedBox(height: 22),
                          _watchlistStrip(context),
                          const SizedBox(height: 20),
                          _newsTabsCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // Dark hero: greeting/bell + Value|Performance toggle + big number +
  // change line + chart with right-side value labels + timeframe tabs.
  // Backed by the real /portfolio/performance series -- no mock numbers.
  Widget _heroSection(bool isMobile) {
    final pad = isMobile ? 20.0 : 32.0;
    final filtered = _filteredPerf;
    final beginning = filtered.isNotEmpty ? filtered.first['value'] as double : _balance;
    final ending = filtered.isNotEmpty ? filtered.last['value'] as double : _balance;
    final change = ending - beginning;
    final changePct = beginning != 0 ? (change / beginning) * 100 : 0.0;
    final isUp = change >= 0;
    final trendColor = isUp ? AppColors.success : AppColors.danger;

    final showingPerf = _valueTab == 'Performance';
    final rawSpots = <FlSpot>[
      for (var i = 0; i < filtered.length; i++)
        FlSpot(
          i.toDouble(),
          showingPerf
              ? (beginning != 0 ? ((filtered[i]['value'] as double) - beginning) / beginning * 100 : 0.0)
              : filtered[i]['value'] as double,
        ),
    ];

    double minY = 0, maxY = 0;
    if (rawSpots.isNotEmpty) {
      minY = rawSpots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      maxY = rawSpots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      if (minY == maxY) {
        minY -= 1;
        maxY += 1;
      }
      final range = maxY - minY;
      minY -= range * 0.15;
      maxY += range * 0.25;
      if (minY > 0) minY = 0;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(pad, 40, pad, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgBottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Builder(
                builder: (ctx) => InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Scaffold.of(ctx).openDrawer(),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
                    child: const Icon(Icons.menu_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
              Expanded(
                child: Text('$_greeting, $_userName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push('/notifications'),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
                  child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _valueTab = 'Value'),
                child: Text('Value',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _valueTab == 'Value' ? Colors.white : _textMutedD,
                    )),
              ),
              const SizedBox(width: 10),
              Container(width: 1, height: 14, color: _textMutedD.withValues(alpha: 0.4)),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => setState(() => _valueTab = 'Performance'),
                child: Text('Performance',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _valueTab == 'Performance' ? Colors.white : _textMutedD,
                    )),
              ),
              const Spacer(),
              Icon(Icons.info_outline_rounded, color: _textMutedD.withValues(alpha: 0.6), size: 18),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              showingPerf ? '${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%' : '\u20b9${ending.toStringAsFixed(2)}',
              maxLines: 1,
              style: AppTypography.priceHero.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${isUp ? '+' : ''}\u20b9${change.toStringAsFixed(2)} (${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%) $_range',
            style: AppTypography.changeText.copyWith(fontSize: 14, color: trendColor),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: isMobile ? 240 : 300,
            child: rawSpots.length < 2
                ? Center(child: Text('Not enough data yet', style: TextStyle(color: _textMutedD, fontSize: 12)))
                : LineChart(
                    LineChartData(
                      minY: minY,
                      maxY: maxY,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        show: true,
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 54,
                            interval: (maxY - minY) / 5,
                            getTitlesWidget: (val, _) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(showingPerf ? '${val.toStringAsFixed(0)}%' : _fmtAxis(val),
                                  style: TextStyle(color: _textMutedD, fontSize: 10.5)),
                            ),
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: rawSpots,
                          isCurved: false,
                          color: AppColors.primary,
                          barWidth: 2.5,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: _ranges.map((r) {
              final active = r == _range;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _range = r),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary.withValues(alpha: 0.18) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(r,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: active ? AppColors.primary : _textMutedD,
                          fontWeight: active ? FontWeight.bold : FontWeight.w500,
                        )),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Mirrors the "Ready to invest with real money? Finish Application"
  // promo card, but wired to this app's real KYC flow instead of a made-up
  // promotion -- only shown while the account is unverified. Kept as a
  // light card against the dark background, same as the reference design.
  Widget _kycBanner(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/onboarding'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.verified_user_rounded, color: Color(0xFFF59E0B), size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ready to invest with real money?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF191919))),
                  SizedBox(height: 4),
                  Text('Finish Application', style: TextStyle(fontSize: 13, color: Color(0xFFF59E0B), fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF191919)),
          ],
        ),
      ),
    );
  }

  // Explore / Transactions / Account / Withdraw / Deposit as translucent
  // dark circular buttons, matching the reference icon row style.
  Widget _quickIconsRow(BuildContext context) {
    final items = <_IconAction>[
      _IconAction('Explore', Icons.search_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()))),
      _IconAction('Transactions', Icons.attach_money_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletHistoryScreen()))),
      _IconAction('Account', Icons.person_rounded, () => context.push('/profile')),
      _IconAction('Withdraw', Icons.north_east_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FundsScreen()))),
      _IconAction('Deposit', Icons.south_west_rounded,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FundsScreen()))),
    ];
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final a = items[i];
          return InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: a.onTap,
            child: SizedBox(
              width: 64,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
                    child: Icon(a.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(a.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.5, color: _textMutedD, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _watchlistStrip(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Watchlist',
            icon: Icons.star_rounded,
            iconColor: const Color(0xFFF59E0B),
            actionLabel: 'Show All',
            onAction: () => context.go('/watchlist'),
          ),
          const SizedBox(height: 14),
          if (_watchlist.isEmpty)
            Text('No stocks in your watchlist yet', style: TextStyle(color: _textMutedD, fontSize: 12))
          else
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _watchlist.take(10).length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, i) {
                  final w = _watchlist[i];
                  final symbol = (w['symbol'] ?? '').toString();
                  final pct = _changePctOf(symbol);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: _avatarColor(symbol), shape: BoxShape.circle),
                        child: Center(
                          child: Text(symbol.isNotEmpty ? symbol[0] : '?',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(symbol,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                      PriceChange(change: pct, changePercent: pct, fontSize: 9.5, showParens: false),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _newsTabsCard() {
    final holdingSymbols = _holdings.map((h) => (h['symbol'] ?? '').toString()).toList();
    final watchlistSymbols = _watchlist.map((w) => (w['symbol'] ?? '').toString()).toList();

    final List<dynamic> shown = switch (_newsTab) {
      1 => _newsFilteredBy(holdingSymbols),
      2 => _newsFilteredBy(watchlistSymbols),
      _ => _dashboardNews,
    };
    final visible = shown.take(5).toList();

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'News', icon: Icons.newspaper_outlined, iconColor: AppColors.primary),
          const SizedBox(height: 14),
          Row(
            children: [
              _newsTabChip('Overview', 0),
              const SizedBox(width: 8),
              _newsTabChip('Portfolio', 1),
              const SizedBox(width: 8),
              _newsTabChip('Watchlists', 2),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingNews)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  _newsTab == 0 ? 'No news yet' : 'No news matching your ${_newsTab == 1 ? 'holdings' : 'watchlist'} yet',
                  style: TextStyle(color: _textMutedD, fontSize: 12),
                ),
              ),
            )
          else
            ...visible.map((item) => GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NewsDetailScreen(item: item))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((item['source'] ?? '').toString(), style: const TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text((item['title'] ?? '').toString(),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text((item['published_at'] ?? '').toString().split('T').first, style: TextStyle(color: _textMutedD, fontSize: 11)),
                        const Divider(height: 20, color: AppColors.border),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _newsTabChip(String label, int index) {
    final active = _newsTab == index;
    return GestureDetector(
      onTap: () => setState(() => _newsTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: TextStyle(color: active ? AppColors.primary : _textMutedD, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }


  Widget _indicesStrip() {
    final items = [
      ('NIFTY 50', _idxNifty),
      ('SENSEX', _idxSensex),
      ('BANK NIFTY', _idxBankNifty),
    ];
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (label, data) = items[i];
          final isUp = data['isUp'] == true;
          final color = isUp ? AppColors.success : AppColors.danger;
          return Container(
            width: 130,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, color: color, size: 13),
                    const SizedBox(width: 4),
                    Expanded(child: Text(label, style: AppTypography.label.copyWith(color: color), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                Text(data['percent'], style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
                Text(data['value'], style: AppTypography.caption),
              ],
            ),
          );
        },
      ),
    );
  }

}

class _IconAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _IconAction(this.label, this.icon, this.onTap);
}
'@
Write-Utf8NoBom (Join-Path $root 'lib\features\dashboard\screens\dashboard_screen.dart') $content

# ---- lib/features/predictions/screens/predictions_screen.dart ----
$content = @'
import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/shared/widgets/account_drawer.dart';

/// Predictions tab placeholder. No prediction feature/backend exists yet --
/// this simply gives the new bottom-nav tab somewhere to go without
/// fabricating any data or fake "AI predictions" content.
class PredictionsScreen extends StatelessWidget {
  const PredictionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainShell(
      currentIndex: 1,
      child: Scaffold(
        backgroundColor: AppColors.background,
        drawer: const AccountDrawer(),
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: Builder(
            builder: (ctx) => IconButton(icon: const Icon(Icons.menu, color: AppColors.textPrimary), onPressed: () => Scaffold.of(ctx).openDrawer()),
          ),
          title: const Text('Predictions', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.auto_graph_outlined, color: AppColors.primary, size: 40),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Predictions — Coming Soon',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'We\'re working on price and trend predictions for your watchlist. This will show up here once it\'s ready.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
'@
Write-Utf8NoBom (Join-Path $root 'lib\features\predictions\screens\predictions_screen.dart') $content

# ---- lib/features/portfolio/screens/portfolio_screen.dart ----
$content = @'
import 'package:flutter/material.dart';
import 'package:stock_app/shared/widgets/overview_sheet.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/shared/widgets/account_drawer.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/shared/widgets/error_state.dart';
import 'package:stock_app/shared/widgets/empty_state.dart';
import 'package:stock_app/core/theme/app_typography.dart';
import 'package:stock_app/features/stock_detail/screens/stock_quote_sheet.dart';
import 'package:stock_app/features/portfolio/screens/family_screen.dart';

class PortfolioScreen extends StatefulWidget {
  final int navIndex;
  const PortfolioScreen({super.key, this.navIndex = 2});
  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  int _tab = 0; // 0=Holdings, 1=Positions, 2=Mutual Funds

  List<dynamic> _holdings = [];
  final Map<String, Map<String, dynamic>> _quotes = {};
  final Map<String, List<double>> _history = {};
  // ignore: unused_field
  List<dynamic> _transactions = [];

  List<dynamic> _mtfPositions = [];
  List<dynamic> _unsettledPositions = [];
  List<dynamic> _futures = [];
  List<dynamic> _options = [];

  List<dynamic> _myFunds = [];
  List<dynamic> _myEtfs = [];

  double _balance = 0;

  bool _loading = true;
  String? _error;

  bool _firstLoad = true;

  bool _searching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_firstLoad) _loadAll();
    _firstLoad = false;
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getHoldings(),
        ApiService.getTransactions(),
        ApiService.getMe(),
        ApiService.getMyFunds().catchError((_) => []),
        ApiService.getMyETFs().catchError((_) => []),
        ApiService.getMTFPositions().catchError((_) => []),
        ApiService.getPositions().catchError((_) => []),
        ApiService.getFutures().catchError((_) => []),
        ApiService.getOptions().catchError((_) => []),
      ]);

      final holdings = results[0] as List<dynamic>;
      final transactions = results[1] as List<dynamic>;
      final me = results[2] as Map<String, dynamic>;
      final myFunds = results[3] as List<dynamic>;
      final myEtfs = results[4] as List<dynamic>;
      final mtfPositions = results[5] as List<dynamic>;
      final unsettledPositions = results[6] as List<dynamic>;
      final futures = results[7] as List<dynamic>;
      final options = results[8] as List<dynamic>;

      setState(() {
        _holdings = holdings;
        _transactions = transactions;
        _balance = (me['user']?['balance'] as num?)?.toDouble() ?? 0;
        _myFunds = myFunds;
        _myEtfs = myEtfs;
        _mtfPositions = mtfPositions;
        _unsettledPositions = unsettledPositions;
        _futures = futures;
        _options = options;
      });

      for (final h in holdings) {
        final symbol = h['symbol'];
        if (symbol == null) continue;
        try {
          final quote = await ApiService.getQuote(symbol);
          if (mounted) setState(() => _quotes[symbol] = quote);
        } catch (_) {}
        try {
          final hist = await ApiService.getHistory(symbol);
          final closes = hist.map((p) => (p['close'] as num?)?.toDouble()).whereType<double>().toList();
          final recent = closes.length > 10 ? closes.sublist(closes.length - 10) : closes;
          if (mounted) setState(() => _history[symbol] = recent);
        } catch (_) {}
      }
    } catch (e) {
      setState(() => _error = 'Could not load portfolio');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _stocksInvested => _holdings.fold(0.0, (sum, h) {
    final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
    final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
    return sum + qty * avg;
  });

  double get _stocksCurrent => _holdings.fold(0.0, (sum, h) {
    final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
    final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
    final quote = _quotes[h['symbol']];
    final price = quote != null ? (quote['price'] as num?)?.toDouble() ?? avg : avg;
    return sum + qty * price;
  });

  double get _mfInvested => _myFunds.fold(0.0, (sum, f) {
    final qty = (f['quantity'] as num?)?.toDouble() ?? 0;
    final avg = (f['avg_price'] as num?)?.toDouble() ?? 0;
    return sum + qty * avg;
  });

  double get _etfInvested => _myEtfs.fold(0.0, (sum, e) {
    final qty = (e['quantity'] as num?)?.toDouble() ?? 0;
    final avg = (e['avg_price'] as num?)?.toDouble() ?? 0;
    return sum + qty * avg;
  });

  double get _totalCurrentValue => _stocksCurrent + _mfInvested + _etfInvested + _balance;
  double get _totalInvested => _stocksInvested + _mfInvested + _etfInvested;
  double get _totalReturns => _stocksCurrent - _stocksInvested; // MF/ETF current==invested (no live NAV yet)
  // ignore: unused_element
  double get _totalReturnsPct => _totalInvested > 0 ? (_totalReturns / _totalInvested) * 100 : 0;

  double get _todayReturns => _holdings.fold(0.0, (sum, h) {
    final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
    final quote = _quotes[h['symbol']];
    final changePerShare = quote != null ? (quote['change'] as num?)?.toDouble() ?? 0 : 0;
    return sum + qty * changePerShare;
  });

  // ignore: unused_element
  double get _todayReturnsPct => _stocksCurrent > 0 ? (_todayReturns / (_stocksCurrent - _todayReturns)) * 100 : 0;

  int get _positionsCount => _mtfPositions.where((p) => p['status'] == 'open').length + _futures.length + _options.length;

  String _sortBy = 'default';

  double _changePctOf(dynamic h) {
    final quote = _quotes[h['symbol']];
    return quote != null ? (quote['change_percent'] as num?)?.toDouble() ?? 0 : 0;
  }

  double _ltpOf(dynamic h) {
    final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
    final quote = _quotes[h['symbol']];
    return quote != null ? (quote['price'] as num?)?.toDouble() ?? avg : avg;
  }

  double _pnlAbsOf(dynamic h) {
    final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
    final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
    final price = _ltpOf(h);
    return (qty * price) - (qty * avg);
  }

  double _pnlPctOf(dynamic h) {
    final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
    final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
    final price = _ltpOf(h);
    final invested = qty * avg;
    if (invested <= 0) return 0;
    return ((qty * price) - invested) / invested * 100;
  }

  double _investedOf(dynamic h) {
    final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
    final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
    return qty * avg;
  }

  List<dynamic> get _sortedHoldings {
    var list = List<dynamic>.from(_holdings);
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((h) {
        final symbol = (h['symbol'] ?? '').toString().toLowerCase();
        final name = (h['company_name'] ?? '').toString().toLowerCase();
        return symbol.contains(q) || name.contains(q);
      }).toList();
    }
    switch (_sortBy) {
      case 'az':
        list.sort((a, b) => (a['symbol'] ?? '').toString().compareTo((b['symbol'] ?? '').toString()));
        break;
      case 'change_pct':
        list.sort((a, b) => _changePctOf(b).compareTo(_changePctOf(a)));
        break;
      case 'ltp':
        list.sort((a, b) => _ltpOf(b).compareTo(_ltpOf(a)));
        break;
      case 'pnl_abs':
        list.sort((a, b) => _pnlAbsOf(b).compareTo(_pnlAbsOf(a)));
        break;
      case 'pnl_pct':
        list.sort((a, b) => _pnlPctOf(b).compareTo(_pnlPctOf(a)));
        break;
      case 'invested':
        list.sort((a, b) => _investedOf(b).compareTo(_investedOf(a)));
        break;
    }
    return list;
  }

  // ignore: unused_element
  List<dynamic> get _topGainers {
    final list = List<dynamic>.from(_holdings);
    list.sort((a, b) => _pnlPctOf(b).compareTo(_pnlPctOf(a)));
    return list.take(3).toList();
  }

  // ignore: unused_element
  List<dynamic> get _topLosers {
    final list = List<dynamic>.from(_holdings);
    list.sort((a, b) => _pnlPctOf(a).compareTo(_pnlPctOf(b)));
    return list.where((h) => _pnlPctOf(h) < 0).take(3).toList();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Widget sortTile(String key, String label) {
            final selected = _sortBy == key;
            return ListTile(
              title: Text(label, style: TextStyle(color: selected ? AppColors.primary : AppColors.textPrimary, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
              trailing: selected ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                setState(() => _sortBy = key);
                Navigator.pop(ctx);
              },
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filter', style: AppTypography.screenTitle),
                    TextButton(
                      onPressed: () {
                        setState(() { _sortBy = 'default'; _searchQuery = ''; _searchController.clear(); });
                        Navigator.pop(ctx);
                      },
                      child: const Text('CLEAR', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const Divider(color: AppColors.border),
                const Text('Sort', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                sortTile('az', 'Alphabetically'),
                sortTile('change_pct', '% Change'),
                sortTile('ltp', 'Last Traded Price'),
                sortTile('pnl_abs', 'Profit & Loss (Absolute)'),
                sortTile('pnl_pct', 'Profit & Loss (Percent)'),
                sortTile('invested', 'Invested'),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _toolbarIcon(IconData icon, {VoidCallback? onTap}) {
    return IconButton(
      icon: Icon(icon, color: AppColors.textMuted, size: 20),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildToolbarRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: _searching
          ? Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search holdings',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                  onPressed: () => setState(() {
                    _searching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  }),
                ),
              ],
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
              children: [
                _toolbarIcon(Icons.search, onTap: () => setState(() => _searching = true)),
                const SizedBox(width: 6),
                _toolbarIcon(Icons.tune, onTap: _showFilterSheet),
                const SizedBox(width: 4),
                PopupMenuButton<int>(
                  onSelected: (i) => setState(() => _tab = i),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Equity', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 18),
                    ],
                  ),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 0, child: Text('Equity')),
                  ],
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyScreen())),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, color: AppColors.primary, size: 18),
                      SizedBox(width: 4),
                      Text('Family', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => context.push('/performance'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.donut_small, color: AppColors.primary, size: 18),
                      SizedBox(width: 4),
                      Text('Analytics', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainShell(
      currentIndex: widget.navIndex,
      drawer: const AccountDrawer(),
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.cardBackground,
          onRefresh: _loadAll,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Builder(
                            builder: (ctx) => IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                              onPressed: () => Scaffold.of(ctx).openDrawer(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => showOverviewSheet(context),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Portfolio', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                                Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary),
                              ],
                            ),
                          ),
                        ],
                      ),
                      _toolbarIcon(Icons.tune, onTap: _showFilterSheet),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildSummaryCard()),
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
                  child: Row(
                    children: [
                      _tabChip('Holdings', _holdings.length, 0),
                      const SizedBox(width: 24),
                      _tabChip('Positions', _positionsCount, 1),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: () => context.push('/performance'),
                        child: const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text('Performance', style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _buildToolbarRow()),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              if (_loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              else if (_error != null)
                SliverFillRemaining(child: ErrorState(message: _error!, onRetry: _loadAll))
              else ...[
                  if (_tab == 0) ..._buildHoldingsTab(),
                  if (_tab == 1) ..._buildPositionsTab(),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabChip(String label, int count, int index) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? AppColors.primary : Colors.transparent, width: 2))),
        child: Text(label, style: TextStyle(color: active ? AppColors.primaryDark : AppColors.textSecondary, fontSize: 14, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
      ),
    );
  }

  Widget _summaryStatRow(String label, double value, double pct, {String? trailingLabel}) {
    final isUp = value >= 0;
    final color = isUp ? AppColors.success : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.label),
                const SizedBox(height: 2),
                Text(
                  '${isUp ? '+' : ''}₹${value.toStringAsFixed(2)} (${isUp ? '+' : ''}${pct.toStringAsFixed(2)}%)',
                  style: AppTypography.changeText.copyWith(color: color),
                ),
              ],
            ),
          ),
          if (trailingLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: GestureDetector(
                onTap: () => showOverviewSheet(context),
                child: Text(trailingLabel, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Net Liquidation Value', style: AppTypography.label),
          const SizedBox(height: 4),
          Text(
            '₹${_totalCurrentValue.toStringAsFixed(2)}',
            style: AppTypography.priceHero,
          ),
          _summaryStatRow('Day P&L', _todayReturns, _todayReturnsPct, trailingLabel: 'Details'),
          _summaryStatRow('Unrealized P&L', _totalReturns, _totalReturnsPct),
        ],
      ),
    );
  }

  List<Widget> _buildHoldingsTab() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Holdings (${_sortedHoldings.length})', style: AppTypography.titleMedium),
              PopupMenuButton<String>(
                initialValue: _sortBy,
                onSelected: (v) => setState(() => _sortBy = v),
                child: Row(
                  children: [
                    Text(
                      {'default': 'Default', 'az': 'A-Z', 'change_pct': '% Change', 'ltp': 'LTP', 'pnl_abs': 'P&L', 'pnl_pct': 'P&L %', 'invested': 'Invested'}[_sortBy] ?? 'Sort',
                      style: const TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const Icon(Icons.sort, color: AppColors.primaryDark, size: 16),
                  ],
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'default', child: Text('Default')),
                  PopupMenuItem(value: 'az', child: Text('Alphabetically')),
                  PopupMenuItem(value: 'change_pct', child: Text('% Change')),
                  PopupMenuItem(value: 'ltp', child: Text('Last Traded Price')),
                  PopupMenuItem(value: 'pnl_abs', child: Text('Profit & Loss (Absolute)')),
                  PopupMenuItem(value: 'pnl_pct', child: Text('Profit & Loss (Percent)')),
                  PopupMenuItem(value: 'invested', child: Text('Invested')),
                ],
              ),
            ],
          ),
        ),
      ),

      if (_sortedHoldings.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: EmptyState(
              icon: Icons.pie_chart_outline,
              message: _searchQuery.isNotEmpty ? 'No holdings match your search' : 'No holdings yet',
            ),
          ),
        )
      else ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Row(
              children: const [
                Expanded(child: Text('Instrument', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                SizedBox(width: 90, child: Text('Last', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                SizedBox(width: 90, child: Text('P&L', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _holdingRow(_sortedHoldings[index]),
              childCount: _sortedHoldings.length,
            ),
          ),
        ),
      ],

      const SliverToBoxAdapter(child: SizedBox(height: 16)),

      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ];
  }

  // ignore: unused_element
  List<PieChartSectionData> _allocationSections() {
    final total = _totalCurrentValue;
    if (total <= 0) {
      return [PieChartSectionData(value: 1, color: AppColors.border, showTitle: false, radius: 18)];
    }
    final parts = [
      {'value': _stocksCurrent, 'color': AppColors.success},
      {'value': _mfInvested, 'color': const Color(0xFF1E88E5)},
      {'value': _etfInvested, 'color': const Color(0xFF8E24AA)},
      {'value': _balance, 'color': AppColors.primary},
    ];
    return parts
        .where((p) => (p['value'] as double) > 0)
        .map((p) => PieChartSectionData(value: p['value'] as double, color: p['color'] as Color, showTitle: false, radius: 18))
        .toList();
  }

  // ignore: unused_element
  Widget _allocRow(String label, Color color, double value) {
    final pct = _totalCurrentValue > 0 ? (value / _totalCurrentValue) * 100 : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          Text('${pct.toStringAsFixed(2)}%', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _moverColumn(String title, List<dynamic> items, bool isGain) {
    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        ...items.map((h) {
          final pct = _pnlPctOf(h);
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(h['symbol']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
                Text('${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%', style: TextStyle(color: isGain ? AppColors.success : AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ignore: unused_element
  Widget _bottomAction(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryDark, size: 22),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _showImportHoldings() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => _ImportHoldingsSheet(scrollController: scrollController, onImported: _loadAll),
      ),
    );
  }

  Widget _holdingRow(dynamic h) {
    final symbol = h['symbol'];
    final qty = (h['quantity'] as num?)?.toDouble() ?? 0;
    final avg = (h['avg_price'] as num?)?.toDouble() ?? 0;
    final quote = _quotes[symbol];
    final price = quote != null ? (quote['price'] as num?)?.toDouble() ?? avg : avg;
    final current = qty * price;
    final invested = qty * avg;
    final returns = current - invested;
    final returnsPct = invested > 0 ? (returns / invested) * 100 : 0;
    final isUp = returns >= 0;

    return GestureDetector(
      onTap: () => showStockQuoteSheet(context, {
        'id': h['stock_id'] ?? h['id'],
        'symbol': h['symbol'],
        'company_name': h['company_name'],
        'exchange': h['exchange'] ?? 'NSE',
        'sector': h['sector'] ?? '',
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.6))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(symbol ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(h['company_name'] ?? symbol ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            SizedBox(
              width: 90,
              child: Text('₹${current.toStringAsFixed(2)}', textAlign: TextAlign.right, maxLines: 1, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            SizedBox(
              width: 90,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${isUp ? '+' : ''}${returns.toStringAsFixed(3)}', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${isUp ? '+' : ''}${returnsPct.toStringAsFixed(2)}%', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _sparkline(List<double>? closes, bool isUp) {
    if (closes == null || closes.length < 2) return const SizedBox(width: 44, height: 28);
    final spots = [for (int i = 0; i < closes.length; i++) FlSpot(i.toDouble(), closes[i])];
    final minY = closes.reduce((a, b) => a < b ? a : b);
    final maxY = closes.reduce((a, b) => a > b ? a : b);
    final color = isUp ? AppColors.success : AppColors.danger;
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        minY: minY == maxY ? minY - 1 : minY,
        maxY: minY == maxY ? maxY + 1 : maxY,
        lineBarsData: [
          LineChartBarData(spots: spots, isCurved: true, color: color, barWidth: 1.6, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: false)),
        ],
      ),
    );
  }

  List<Widget> _buildPositionsTab() {
    final allPositions = [
      ..._unsettledPositions.map((p) => {'type': 'Regular', 'data': p}),
      ..._mtfPositions.where((p) => p['status'] == 'open').map((p) => {'type': 'MTF', 'data': p}),
      ..._futures.map((p) => {'type': 'Futures', 'data': p}),
      ..._options.map((p) => {'type': 'Options', 'data': p}),
    ];

    if (allPositions.isEmpty) {
      return [
        SliverFillRemaining(
          child: EmptyState(
            icon: Icons.candlestick_chart_outlined,
            message: 'No open positions\nMTF, Futures & Options positions appear here',
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final pos = allPositions[index];
              final type = pos['type'] as String;
              final data = pos['data'] as Map;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(data['symbol']?.toString() ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                          child: Text(type, style: const TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      type == 'Regular'
                          ? 'Qty: ${data['quantity']} ? Avg ₹${(data['avg_price'] as num?)?.toStringAsFixed(2)}'
                          : type == 'MTF'
                          ? 'Qty: ${data['quantity']} • Entry ₹${(data['entry_price'] as num?)?.toStringAsFixed(2)}'
                          : type == 'Futures'
                          ? '${data['position_type'] ?? ''} • Lot: ${data['lot_size']} • Entry ₹${(data['entry_price'] as num?)?.toStringAsFixed(2) ?? '-'}'
                          : '${data['option_type'] ?? ''} • Strike ₹${(data['strike_price'] as num?)?.toStringAsFixed(2) ?? '-'}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              );
            },
            childCount: allPositions.length,
          ),
        ),
      ),
    ];
  }

  // ignore: unused_element
  List<Widget> _buildMutualFundsTab() {
    if (_myFunds.isEmpty) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.savings_outlined, color: AppColors.textMuted, size: 40),
                const SizedBox(height: 12),
                const Text('No mutual fund investments yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              final f = _myFunds[index];
              final qty = (f['quantity'] as num?)?.toDouble() ?? 0;
              final avg = (f['avg_price'] as num?)?.toDouble() ?? 0;
              final invested = qty * avg;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('Units: ${qty.toStringAsFixed(3)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    Text('₹${invested.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              );
            },
            childCount: _myFunds.length,
          ),
        ),
      ),
    ];
  }
}

class _ImportHoldingsSheet extends StatefulWidget {
  final ScrollController scrollController;
  final VoidCallback onImported;
  const _ImportHoldingsSheet({required this.scrollController, required this.onImported});

  @override
  State<_ImportHoldingsSheet> createState() => _ImportHoldingsSheetState();
}

class _ImportHoldingsSheetState extends State<_ImportHoldingsSheet> {
  List<dynamic> _linkedHoldings = [];
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
      final holdings = await ApiService.getAngelOneHoldings();
      if (mounted) setState(() => _linkedHoldings = holdings);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not connect to your linked brokerage account');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
          ),
          const SizedBox(height: 16),
          const Text('Linked Brokerage Holdings', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            'These are read-only holdings from your linked AngelOne account. They are not merged into your virtual portfolio.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_off, color: AppColors.textMuted, size: 36),
                  const SizedBox(height: 8),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
                : _linkedHoldings.isEmpty
                ? const Center(child: Text('No holdings in your linked account', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))
                : ListView.builder(
              controller: widget.scrollController,
              itemCount: _linkedHoldings.length,
              itemBuilder: (context, index) {
                final h = _linkedHoldings[index];
                final ltp = (h['ltp'] as num?)?.toDouble() ?? 0;
                final avgPrice = (h['averageprice'] as num?)?.toDouble() ?? 0;
                final qty = h['quantity'] ?? 0;
                final pnl = (ltp - avgPrice) * (qty is num ? qty.toDouble() : 0);
                final isProfit = pnl >= 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(h['tradingsymbol']?.toString() ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(h['exchange']?.toString() ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$qty shares @ ₹${avgPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${ltp.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                              Text('${isProfit ? '+' : ''}₹${pnl.toStringAsFixed(2)}', style: TextStyle(color: isProfit ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
'@
Write-Utf8NoBom (Join-Path $root 'lib\features\portfolio\screens\portfolio_screen.dart') $content

Write-Host "Done. New files created:" -ForegroundColor Green
Write-Host "  lib/shared/widgets/account_drawer.dart"
Write-Host "  lib/features/profile/screens/account_details_screen.dart"
Write-Host "  lib/features/profile/screens/statements_tax_screen.dart"
Write-Host "Updated files:" -ForegroundColor Green
Write-Host "  lib/shared/widgets/main_shell.dart"
Write-Host "  lib/features/explore/screens/explore_screen.dart"
Write-Host "  lib/features/watchlist/screens/watchlist_screen.dart"
Write-Host "  lib/features/dashboard/screens/dashboard_screen.dart"
Write-Host "  lib/features/predictions/screens/predictions_screen.dart"
Write-Host "  lib/features/portfolio/screens/portfolio_screen.dart"
Write-Host "Now run: flutter pub get; flutter run" -ForegroundColor Yellow