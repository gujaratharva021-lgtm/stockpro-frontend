import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:lottie/lottie.dart';

class KycSuccessScreen extends StatefulWidget {
  const KycSuccessScreen({super.key});
  @override
  State<KycSuccessScreen> createState() => _KycSuccessScreenState();
}

class _KycSuccessScreenState extends State<KycSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 768;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 32),
        ScaleTransition(
          scale: _scale,
          child: SizedBox(
            width: 140, height: 140,
            child: Lottie.asset(
              'assets/animations/kyc_success.json',
              fit: BoxFit.contain,
              repeat: false,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Application Submitted!',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Your application is under review.\nThis usually takes 12-24 hours.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: () => context.go('/dashboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Continue to Trading', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );

    if (isWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Center(
                child: Container(
                  width: 520,
                  margin: const EdgeInsets.symmetric(vertical: 32),
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: content,
        ),
      ),
    );
  }
}
