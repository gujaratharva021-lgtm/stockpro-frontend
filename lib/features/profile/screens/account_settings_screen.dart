import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/profile/screens/personal_details_screen.dart';
import 'package:stock_app/features/profile/screens/bank_accounts_screen.dart';
import 'package:stock_app/features/profile/screens/kyc_documents_screen.dart';

/// Account Settings -- groups the account-level screens (Personal Info,
/// Bank Accounts, KYC Documents) that were previously scattered elsewhere,
/// under a single "Account Settings" entry point from the Settings screen.
class AccountSettingsScreen extends StatelessWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Account Settings', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Personal Info, Permissions & More', style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                _navItem(
                  context,
                  Icons.badge_outlined,
                  'Personal Details',
                  'Name, email, phone & profile photo',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalDetailsScreen())),
                ),
                _divider(),
                _navItem(
                  context,
                  Icons.account_balance_outlined,
                  'Bank Accounts',
                  'Linked accounts for withdrawals & payouts',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BankAccountsScreen())),
                ),
                _divider(),
                _navItem(
                  context,
                  Icons.verified_user_outlined,
                  'KYC Documents',
                  'PAN, Aadhaar & verification status',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KycDocumentsScreen())),
                  showDivider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1, color: AppColors.border));

  Widget _navItem(BuildContext context, IconData icon, String title, String subtitle, {required VoidCallback onTap, bool showDivider = true}) {
    return InkWell(
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
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
