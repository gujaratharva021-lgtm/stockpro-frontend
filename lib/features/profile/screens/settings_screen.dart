import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/notifications/screens/notifications_screen.dart';
import 'package:stock_app/features/profile/screens/security_screen.dart';

/// Settings screen -- original items (Notifications, Limit & Stop-Loss
/// Orders, Brokerage Calculator, Privacy Mode, Security, Help & Support,
/// Privacy Policy, Terms of Service) plus the extra items that used to
/// live duplicated inside Statements & Tax (Account Settings, User
/// Settings, Trading Presets, Display, News Language Settings,
/// Localization, Advanced). Biometric Login has been removed.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _privacyMode = false;

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
        title: const Text('Settings', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card([
            _navItem(Icons.notifications_outlined, 'Notifications', null,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            _navItem(Icons.assignment_outlined, 'Limit & Stop-Loss Orders', null,
                onTap: () => context.push('/pending-orders')),
            _navItem(Icons.calculate_outlined, 'Brokerage Calculator', null,
                onTap: () => context.push('/brokerage-calculator'), showDivider: false),
          ]),
          const SizedBox(height: 16),
          _card([
            _switchItem(Icons.visibility_outlined, 'Privacy Mode', _privacyMode,
                onChanged: (v) => setState(() => _privacyMode = v)),
            _navItem(Icons.shield_outlined, 'Security', null,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityScreen())), showDivider: false),
          ]),
          const SizedBox(height: 16),
          _card([
            _navItem(Icons.person_outline, 'Account Settings', 'Personal Info, Permissions & More',
                onTap: () => _comingSoon('Account Settings')),
            _navItem(Icons.account_circle_outlined, 'User Settings', 'Login, Communication & More',
                onTap: () => _comingSoon('User Settings')),
            _navItem(Icons.tune_outlined, 'Trading Presets', 'Customize Your Trade Defaults',
                onTap: () => _comingSoon('Trading Presets')),
            _navItem(Icons.brightness_6_outlined, 'Display', 'App Theme & Accessibility',
                onTap: () => _comingSoon('Display')),
            _navItem(Icons.article_outlined, 'News Language Settings', 'Filter news articles by selected languages',
                onTap: () => _comingSoon('News Language Settings')),
            _navItem(Icons.public_outlined, 'Localization', 'Language, Base Currency & More',
                onTap: () => _comingSoon('Localization')),
            _navItem(Icons.build_outlined, 'Advanced', 'Diagnostics, Debug & Extended Log',
                onTap: () => _comingSoon('Advanced'), showDivider: false),
          ]),
          const SizedBox(height: 16),
          _card([
            _navItem(Icons.help_outline, 'Help & Support', null, onTap: () => _comingSoon('Help & Support')),
            _navItem(Icons.privacy_tip_outlined, 'Privacy Policy', null, onTap: () => _comingSoon('Privacy Policy')),
            _navItem(Icons.description_outlined, 'Terms of Service', null, onTap: () => _comingSoon('Terms of Service'), showDivider: false),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(children: children),
      );

  Widget _navItem(IconData icon, String title, String? subtitle, {required VoidCallback onTap, bool showDivider = true}) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: AppColors.textSecondary, size: 20),
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

  Widget _switchItem(IconData icon, String title, bool value, {required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500))),
          Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
        ],
      ),
    );
  }
}