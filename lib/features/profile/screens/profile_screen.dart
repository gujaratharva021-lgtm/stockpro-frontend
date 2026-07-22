import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/profile/screens/personal_details_screen.dart';
import 'package:stock_app/features/profile/screens/funds_screen.dart';
import 'package:stock_app/features/assistant/screens/assistant_screen.dart';
import 'package:stock_app/features/profile/screens/settings_screen.dart';
import 'package:stock_app/features/profile/screens/kyc_documents_screen.dart';
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
      final res = await ApiService.getMe();
      setState(() => _user = res['user']);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
                              Navigator.pop(dialogContext);
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

    return MainShell(
      currentIndex: 4,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                              onPressed: () => Navigator.maybePop(context),
                            ),
                            const Text('Account', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _pickAndUploadAvatar,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
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
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                                            ),
                                          )
                                        : null,
                                  ),
                                  if (_uploadingAvatar)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                                        child: const Center(
                                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryDark),
                                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                                  const SizedBox(height: 2),
                                  Text(email, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
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
                              activeColor: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: kycDone ? AppColors.success.withOpacity(0.08) : AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: kycDone ? AppColors.success.withOpacity(0.3) : AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                kycDone ? Icons.verified_outlined : Icons.warning_amber_outlined,
                                color: kycDone ? AppColors.success : AppColors.primaryDark,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      kycDone ? 'Your account is set up and ready to transact' : 'KYC Pending',
                                      style: TextStyle(color: kycDone ? AppColors.success : AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      kycDone ? 'Happy investing!' : 'Complete KYC to unlock all features',
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              if (!kycDone)
                                TextButton(
                                  onPressed: () => context.go('/onboarding'),
                                  child: const Text('Complete', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _menuSection('Account', [
                        _menuItem(Icons.currency_rupee, 'Funds', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FundsScreen()))),
                        _menuItem(Icons.lock_outline, 'App Code', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppCodeScreen()))),
                        _menuItem(Icons.desktop_windows_outlined, 'Link Web Session', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkWebSessionScreen()))),
                        _menuItem(Icons.person_outline, 'Profile', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalDetailsScreen()))),
                        _menuItem(Icons.settings_outlined, 'Settings', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
                        _menuItem(Icons.apps_outlined, 'Connected Apps', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectedAppsScreen()))),
                        _menuItem(Icons.auto_awesome, 'AI Assistant', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantScreen()))),
                        _menuItem(Icons.logout, 'Logout', onTap: _logout),
                      ]),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Console', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 20,
                              runSpacing: 14,
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
                      const SizedBox(height: 24),
                      _menuSection('Support', [
                        _menuItem(Icons.support_agent_outlined, 'Support portal', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()))),
                        _menuItem(Icons.help_outline, 'User Manual', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManualScreen()))),
                        _menuItem(Icons.call_outlined, 'Contact', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()))),
                      ]),
                      const SizedBox(height: 20),
                      _menuSection('Others', [
                        _menuItem(Icons.person_add_alt_outlined, 'Invite Friends', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InviteFriendsScreen()))),
                        _menuItem(Icons.description_outlined, 'Licenses', onTap: () => showLicensePage(context: context, applicationName: 'OneInvest', applicationVersion: 'v1.0')),
                      ]),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextButton(
                          onPressed: _confirmDeleteAccount,
                          child: const Text('Delete Account', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w500, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Center(child: Text('OneInvest v1.0', style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _menuSection(String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
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
