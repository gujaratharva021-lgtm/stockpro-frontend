import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/services/biometric_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  String? _error;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    print('🔐 Biometric available: $available, enabled: $enabled');
    if (mounted) setState(() => _biometricAvailable = available && enabled);
  }

  Future<void> _loginWithBiometric() async {
    print('🔐 Attempting biometric auth...');
    final success = await BiometricService.authenticate();
    print('🔐 Biometric result: $success');
    if (!success) return;
    setState(() { _loading = true; _error = null; });
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');
      if (token != null && mounted) {
        context.go('/watchlist');
      } else {
        setState(() => _error = 'No saved session. Please login with password first.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.login(_emailController.text.trim(), _passwordController.text);
      const storage = FlutterSecureStorage();
      await storage.write(key: 'auth_token', value: res['token']);
      if (mounted) context.go(kIsWeb ? '/dashboard' : '/watchlist');
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['error']?.toString() ?? 'Login failed');
    } catch (e) {
      setState(() => _error = 'Something went wrong');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 768;

    final formContent = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                ),
                child: const Icon(Icons.trending_up, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('OneInvest', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Welcome back', style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Sign in to continue trading', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 32),
          _buildLabel('Email'),
          const SizedBox(height: 8),
          _buildField(controller: _emailController, hint: 'you@example.com', icon: Icons.mail_outline),
          const SizedBox(height: 18),
          _buildLabel('Password'),
          const SizedBox(height: 8),
          _buildField(
            controller: _passwordController,
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscure: !_showPassword,
            suffix: IconButton(
              icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMuted, size: 20),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => context.go('/forgot-password'),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(color: AppColors.primaryDark, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withOpacity(0.25)),
              ),
              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/code-login'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.phonelink_lock_outlined, color: AppColors.primaryDark, size: 19),
                label: const Text('Login with Code', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
              ),
            ),
          ],
          if (_biometricAvailable) ...[
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _loginWithBiometric,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fingerprint, color: AppColors.primary, size: 24),
                      SizedBox(width: 8),
                      Text('Login with Biometric', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: () => context.go('/signup'),
              child: RichText(
                text: TextSpan(
                  text: "Don't have an account? ",
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                  children: const [TextSpan(text: 'Sign up', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600))],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (isWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: Row(
          children: [
            // Left branding panel
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.trending_up, color: Colors.white, size: 64),
                      SizedBox(height: 24),
                      Text('OneInvest', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                      SizedBox(height: 12),
                      Text('Trade smarter, grow faster', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      SizedBox(height: 40),
                      _FeatureRow(icon: Icons.bolt, text: 'Real-time stock prices'),
                      SizedBox(height: 16),
                      _FeatureRow(icon: Icons.pie_chart, text: 'Portfolio analytics'),
                      SizedBox(height: 16),
                      _FeatureRow(icon: Icons.shield, text: 'Secure & reliable'),
                    ],
                  ),
                ),
              ),
            ),
            // Right form panel
            Container(
              width: 460,
              color: Colors.white,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: formContent,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: formContent,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13));

  Widget _buildField({required TextEditingController controller, required String hint, required IconData icon, bool obscure = false, Widget? suffix}) {
    return Container(
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ],
    );
  }
}