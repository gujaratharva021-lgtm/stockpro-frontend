import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/theme/app_typography.dart';
import 'package:stock_app/features/profile/screens/personal_details_screen.dart';
import 'package:stock_app/features/profile/screens/funds_screen.dart';
import 'package:stock_app/features/assistant/screens/assistant_screen.dart';
import 'package:stock_app/features/profile/screens/settings_screen.dart';
import 'package:stock_app/features/profile/screens/user_manual_screen.dart';
import 'package:stock_app/features/profile/screens/invite_friends_screen.dart';
import 'package:stock_app/features/profile/screens/tradebook_screen.dart';
import 'package:stock_app/features/profile/screens/downloads_screen.dart';
import 'package:stock_app/features/profile/screens/connected_apps_screen.dart';
import 'package:stock_app/features/profile/screens/family_screen.dart';
import 'package:stock_app/features/profile/screens/gift_stocks_screen.dart';
import 'package:stock_app/features/profile/screens/app_code_screen.dart';
import 'package:stock_app/features/profile/screens/link_web_session_screen.dart';
import 'package:stock_app/features/profile/screens/help_support_screen.dart';
import 'package:stock_app/features/tax/screens/pnl_report_screen.dart';
import 'package:stock_app/core/services/privacy_mode_service.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';

const Color _kPurple = Color(0xFF7C6FF0);
const Color _kOrange = AppColors.warning;
const Color _kTeal = Color(0xFF14B8A6);
const Color _kDarkBanner = Color(0xFF0F241C);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  bool _uploadingAvatar = false;
  bool _privacyMode = false;

  List<dynamic> _holdings = [];
  List<dynamic> _myFunds = [];
  List<dynamic> _myEtfs = [];
  final Map<String, Map<String, dynamic>> _quotes = {};

  @override
  void initState() {
    super.initState();
    _load();
    _privacyMode = PrivacyModeService.enabled.value;
    PrivacyModeService.enabled.addListener(_onPrivacyModeChanged);
  }

  void _onPrivacyModeChanged() {
    if (mounted) setState(() => _privacyMode = PrivacyModeService.enabled.value);
  }

  @override
  void dispose() {
    PrivacyModeService.enabled.removeListener(_onPrivacyModeChanged);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getMe(),
        ApiService.getHoldings().catchError((_) => []),
        ApiService.getMyFunds().catchError((_) => []),
        ApiService.getMyETFs().catchError((_) => []),
      ]);
      final me = results[0] as Map<String, dynamic>;
      final holdings = results[1] as List<dynamic>;
      final myFunds = results[2] as List<dynamic>;
      final myEtfs = results[3] as List<dynamic>;

      setState(() {
        _user = me['user'];
        _holdings = holdings;
        _myFunds = myFunds;
        _myEtfs = myEtfs;
      });

      for (final h in holdings) {
        final symbol = h['symbol'];
        if (symbol == null) continue;
        try {
          final quote = await ApiService.getQuote(symbol);
          if (mounted) setState(() => _quotes[symbol] = quote);
        } catch (_) {}
      }
    } catch (_) {
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

  double get _totalInvested => _stocksInvested + _mfInvested + _etfInvested;
  double get _totalReturns => _stocksCurrent - _stocksInvested;
  double get _totalReturnsPct => _totalInvested > 0 ? (_totalReturns / _totalInvested) * 100 : 0;

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      await ApiService.uploadAvatar(picked.path);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not upload image')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    if (mounted) context.go('/login');
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordController = TextEditingController();
    bool obscure = true;
    String? error;
    bool deleting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Delete Account'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will permanently delete your account and all your data (orders, portfolio, watchlist). This cannot be undone.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Enter your password to confirm',
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: deleting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: deleting
                      ? null
                      : () async {
                          if (passwordController.text.isEmpty) {
                            setDialogState(() => error = 'Password is required');
                            return;
                          }
                          setDialogState(() {
                            deleting = true;
                            error = null;
                          });
                          try {
                            await ApiService.deleteAccount(passwordController.text);
                            await ApiService.clearToken();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Account deleted successfully')),
                              );
                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                              if (!mounted) return;
                              context.go('/login');
                            }
                          } catch (e) {
                            setDialogState(() {
                              deleting = false;
                              error = 'Incorrect password or something went wrong';
                            });
                          }
                        },
                  child: deleting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Delete', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final kycDone = _user?['kyc_completed'] == true;
    final name = _user?['name'] ?? 'Trader';
    final email = _user?['email'] ?? '';
    final returnsPositive = _totalReturns >= 0;

    return MainShell(
      currentIndex: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('Profile', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 28)),
                                  SizedBox(height: 2),
                                  Text('Manage your account', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                ],
                              ),
                            ),
                            _roundIconButton(Icons.notifications_none, onTap: () {}),
                            const SizedBox(width: 10),
                            _roundIconButton(Icons.settings_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
                          ),
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalDetailsScreen())),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: _pickAndUploadAvatar,
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.success.withValues(alpha: 0.15),
                                              image: _user?['avatar_url'] != null
                                                  ? DecorationImage(
                                                      image: NetworkImage('https://${ApiService.host}${_user!['avatar_url']}'),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                            ),
                                            child: _user?['avatar_url'] == null
                                                ? Center(
                                                    child: Text(
                                                      name.isNotEmpty ? name[0].toUpperCase() : 'T',
                                                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 22),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          if (_uploadingAvatar)
                                            Positioned.fill(
                                              child: Container(
                                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                                                child: const Center(
                                                  child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success),
                                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 19)),
                                              if (kycDone) ...[
                                                const SizedBox(width: 6),
                                                const Icon(Icons.verified, color: AppColors.primary, size: 16),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(email, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (kycDone ? AppColors.success : _kOrange).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(kycDone ? Icons.check_circle : Icons.error_outline, color: kycDone ? AppColors.success : _kOrange, size: 13),
                                                const SizedBox(width: 4),
                                                Text(
                                                  kycDone ? 'Account Verified' : 'KYC Pending',
                                                  style: TextStyle(color: kycDone ? AppColors.success : _kOrange, fontSize: 11, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                              const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, color: AppColors.border)),
                              Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.success, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Total Invested', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                        Text('₹${_totalInvested.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                                      ],
                                    ),
                                  ),
                                  Container(width: 1, height: 32, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 8)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Total Returns', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                        Text(
                                          '${returnsPositive ? '+' : ''}₹${_totalReturns.toStringAsFixed(0)} (${_totalReturnsPct.toStringAsFixed(1)}%)',
                                          style: TextStyle(color: returnsPositive ? AppColors.success : AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => context.push('/portfolio'),
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(color: _kPurple.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                      child: Icon(Icons.bar_chart, color: _kPurple, size: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: _kDarkBanner, borderRadius: BorderRadius.circular(18)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      kycDone ? 'Your account is ready!' : 'Complete your KYC',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      kycDone ? "You're all set to invest & grow your wealth." : 'Finish KYC to unlock investing and all features.',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                                    ),
                                    const SizedBox(height: 14),
                                    GestureDetector(
                                      onTap: () {
                                        if (kycDone) {
                                          context.push('/portfolio');
                                        } else {
                                          context.go('/onboarding');
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(10)),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(kycDone ? 'Explore Investments' : 'Complete KYC', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('🚀', style: TextStyle(fontSize: 64)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Quick Access', style: AppTypography.screenTitle),
                            const SizedBox(height: 14),
                            GridView.count(
                              crossAxisCount: 4,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 8,
                              childAspectRatio: 0.72,
                              children: [
                                _quickTile(Icons.account_balance_wallet_outlined, 'Funds', AppColors.success, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FundsScreen()))),
                                _quickTile(Icons.lock_outline, 'App Code', _kPurple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppCodeScreen()))),
                                _quickTile(Icons.desktop_windows_outlined, 'Link Web\nSession', _kOrange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkWebSessionScreen()))),
                                _quickTile(Icons.person_outline, 'Profile', AppColors.primary, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalDetailsScreen()))),
                                _quickTile(Icons.settings_outlined, 'Settings', _kPurple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                                _quickTile(Icons.hub_outlined, 'Connected\nApps', _kTeal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectedAppsScreen()))),
                                _quickTile(Icons.auto_awesome, 'AI Assistant', _kPurple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantScreen()))),
                                _quickTile(Icons.logout, 'Logout', AppColors.danger, _logout),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: _kPurple.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: Icon(Icons.support_agent, color: _kPurple, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Need help?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                    SizedBox(height: 2),
                                    Text('Our support team is here to help you.', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                                  child: Text('Contact Support', style: TextStyle(color: _kPurple, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListTile(
                            title: const Text('Privacy mode', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                            trailing: Switch(
                              value: _privacyMode,
                              onChanged: (val) => PrivacyModeService.enabled.value = val,
                              activeThumbColor: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text('More', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Console', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 20,
                              runSpacing: 12,
                              children: [
                                _consoleLink('Portfolio', () => context.push('/portfolio')),
                                _consoleLink('Tradebook', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TradebookScreen()))),
                                _consoleLink('P&L', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PnLReportScreen()))),
                                _consoleLink('Tax P&L', () => context.push('/tax-report')),
                                _consoleLink('Gift stocks', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GiftStocksScreen()))),
                                _consoleLink('Family', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyScreen()))),
                                _consoleLink('Downloads', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen()))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _menuSection('Support', [
                        _menuItem(Icons.support_agent_outlined, 'Support portal', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()))),
                        _menuItem(Icons.help_outline, 'User Manual', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManualScreen()))),
                        _menuItem(Icons.call_outlined, 'Contact', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()))),
                      ]),
                      const SizedBox(height: 16),
                      _menuSection('Others', [
                        _menuItem(Icons.person_add_alt_outlined, 'Invite Friends', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InviteFriendsScreen()))),
                        _menuItem(Icons.description_outlined, 'Licenses', onTap: () => showLicensePage(context: context, applicationName: 'OneInvest', applicationVersion: 'v1.0')),
                      ]),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextButton(
                          onPressed: _confirmDeleteAccount,
                          child: const Text('Delete Account', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w500, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(child: Text('OneInvest v1.0', style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _roundIconButton(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }

  Widget _quickTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuSection(String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(children: items),
          ),
        ],
      ),
    );
  }

  Widget _consoleLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _menuItem(IconData icon, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}