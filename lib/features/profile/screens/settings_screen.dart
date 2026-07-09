import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/services/biometric_service.dart';
import 'package:stock_app/core/services/privacy_mode_service.dart';
import 'package:stock_app/features/notifications/screens/notifications_screen.dart';
import 'package:stock_app/features/profile/screens/security_screen.dart';
import 'package:stock_app/features/profile/screens/help_support_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  bool _privacyMode = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    _privacyMode = PrivacyModeService.enabled.value;
    PrivacyModeService.enabled.addListener(_onPrivacyModeChanged);
  }

  @override
  void dispose() {
    PrivacyModeService.enabled.removeListener(_onPrivacyModeChanged);
    super.dispose();
  }

  void _onPrivacyModeChanged() {
    if (mounted) setState(() => _privacyMode = PrivacyModeService.enabled.value);
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
      }
    }
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

  Widget _menuItemWithToggle(IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary, size: 20),
        title: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        trailing: Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _section(List<Widget> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: items),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Settings', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section([
              _menuItem(Icons.notifications_outlined, 'Notifications', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
              _menuItem(Icons.pending_actions_outlined, 'Limit & Stop-Loss Orders', onTap: () => context.push('/pending-orders')),
              _menuItem(Icons.calculate_outlined, 'Brokerage Calculator', onTap: () => context.push('/brokerage-calculator')),
            ]),
            _section([
              if (_biometricAvailable)
                _menuItemWithToggle(Icons.fingerprint, 'Biometric Login', _biometricEnabled, (val) async {
                  await BiometricService.setEnabled(val);
                  setState(() => _biometricEnabled = val);
                }),
              _menuItemWithToggle(Icons.remove_red_eye_outlined, 'Privacy Mode', _privacyMode, (val) => PrivacyModeService.enabled.value = val),
              _menuItem(Icons.security_outlined, 'Security', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen()))),
            ]),
            _section([
              _menuItem(Icons.help_outline, 'Help & Support', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()))),
              _menuItem(Icons.privacy_tip_outlined, 'Privacy Policy', onTap: () => _openUrl('https://gujaratharva021-lgtm.github.io/stockpro-legal/privacy-policy.html')),
              _menuItem(Icons.description_outlined, 'Terms of Service', onTap: () => _openUrl('https://gujaratharva021-lgtm.github.io/stockpro-legal/terms-of-service.html')),
            ]),
          ],
        ),
      ),
    );
  }
}