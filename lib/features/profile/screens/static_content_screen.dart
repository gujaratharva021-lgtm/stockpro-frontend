import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class StaticContentSection {
  final String? heading;
  final String body;
  const StaticContentSection({this.heading, required this.body});
}

class StaticContentScreen extends StatelessWidget {
  final String title;
  final List<StaticContentSection> sections;
  const StaticContentScreen({super.key, required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final s in sections) ...[
            if (s.heading != null) ...[
              Text(s.heading!, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
            ],
            Text(s.body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}