import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/profile/screens/tradebook_screen.dart';
import 'package:stock_app/features/tax/screens/pnl_report_screen.dart';
import 'package:stock_app/features/profile/screens/downloads_screen.dart';

/// "Statements & Tax" destination -- replaces the old "Support" entry in
/// the account drawer. Shows only statements/tax items (Account Settings
/// and other Settings live in their own Settings screen, not duplicated
/// here).
class StatementsTaxScreen extends StatelessWidget {
  const StatementsTaxScreen({super.key});
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card([
            _navItem(context, Icons.description_outlined, 'Activity Statements', null,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen()))),
            _navItem(context, Icons.insert_chart_outlined, 'Trade Reports', null,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TradebookScreen()))),
            _navItem(context, Icons.file_download_outlined, 'Download Tax Forms', null,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PnLReportScreen()))),
            _navItem(context, Icons.pie_chart_outline, 'Portfolio Analyst', null,
                onTap: () => context.push('/portfolio'), showDivider: false),
          ]),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Column(children: children),
      );

  Widget _navItem(BuildContext context, IconData icon, String title, String? subtitle, {required VoidCallback onTap, bool showDivider = true}) {
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

