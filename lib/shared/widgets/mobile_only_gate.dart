import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';

/// On web, shows a "use the mobile app" message instead of [child].
/// [child] is a builder so native-only plugins are never constructed on web.
class MobileOnlyGate extends StatelessWidget {
  final String feature;
  final WidgetBuilder builder;
  const MobileOnlyGate({super.key, required this.feature, required this.builder});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return builder(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_android, color: AppColors.textMuted, size: 48),
              const SizedBox(height: 16),
              Text('$feature is available on the mobile app', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Please use the mobile app to continue.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}