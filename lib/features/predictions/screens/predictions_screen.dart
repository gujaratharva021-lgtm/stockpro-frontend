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
                  'Predictions â€” Coming Soon',
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