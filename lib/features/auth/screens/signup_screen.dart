import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/services/websocket_service.dart';
import 'package:stock_app/core/theme/app_typography.dart';

// Scoped light palette for the auth flow (login/signup/forgot-password),
// distinct from the app-wide dark AppColors used everywhere else post-login.
class _AuthPalette {
  static const bg = Color(0xFF0B0E14);
  static const card = Color(0xFF151A23);
  static const border = Color(0xFF232935);
  static const primary = Color(0xFF4C8DFF);
  static const primaryDark = Color(0xFF2A5F9E);
  static const textPrimary = Color(0xFFF5F6F8);
  static const textSecondary = Color(0xFFAEB4C0);
  static const textMuted = Color(0xFF7A8091);
  static const danger = Color(0xFFFF5C4D);
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  Future<void> _signup() async {
    setState(() { _loading = true; _error = null; });
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (_nameController.text.trim().isEmpty || email.isEmpty || password.isEmpty) {
        setState(() => _error = 'Please fill in all the fields.');
        return;
      }
      if (password.length < 12 || !RegExp(r'[A-Za-z]').hasMatch(password) || !RegExp(r'[0-9]').hasMatch(password) || !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
        setState(() => _error = 'Password must be at least 12 characters long and strong (use letters, numbers and symbols).');
        return;
      }
      await ApiService.signup(email, password, _nameController.text.trim());
      final res = await ApiService.login(email, password);
      const storage = FlutterSecureStorage();
      await storage.write(key: 'auth_token', value: res['token']);
      WebSocketService.connect();
      if (mounted) context.go('/onboarding');
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['error']?.toString() ?? 'Signup failed');
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
                  gradient: const LinearGradient(colors: [_AuthPalette.primary, _AuthPalette.primaryDark]),
                ),
                child: const Icon(Icons.trending_up, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Text('OneInvest', style: AppTypography.screenTitle),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Create account', style: TextStyle(color: _AuthPalette.textPrimary, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Start your trading journey today', style: TextStyle(color: _AuthPalette.textMuted, fontSize: 14)),
          const SizedBox(height: 32),
          _buildLabel('Full Name'),
          const SizedBox(height: 8),
          _buildField(controller: _nameController, hint: 'Your name', icon: Icons.person_outline),
          const SizedBox(height: 18),
          _buildLabel('Email'),
          const SizedBox(height: 8),
          _buildField(controller: _emailController, hint: 'you@example.com', icon: Icons.mail_outline),
          const SizedBox(height: 18),
          _buildLabel('Password'),
          const SizedBox(height: 8),
          _buildField(
            controller: _passwordController,
            hint: 'Min 12 characters',
            icon: Icons.lock_outline,
            obscure: !_showPassword,
            suffix: IconButton(
              icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _AuthPalette.textMuted, size: 20),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _AuthPalette.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _AuthPalette.danger.withValues(alpha: 0.25)),
              ),
              child: Text(_error!, style: const TextStyle(color: _AuthPalette.danger, fontSize: 13)),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _signup,
              style: ElevatedButton.styleFrom(
                backgroundColor: _AuthPalette.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: () => context.go('/login'),
              child: RichText(
                text: TextSpan(
                  text: 'Already have an account? ',
                  style: const TextStyle(color: _AuthPalette.textMuted, fontSize: 14),
                  children: const [TextSpan(text: 'Sign in', style: TextStyle(color: _AuthPalette.primaryDark, fontWeight: FontWeight.w600))],
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
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_AuthPalette.primary, _AuthPalette.primaryDark],
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
      backgroundColor: _AuthPalette.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: formContent,
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text, style: const TextStyle(color: _AuthPalette.textSecondary, fontSize: 13));

  Widget _buildField({required TextEditingController controller, required String hint, required IconData icon, bool obscure = false, Widget? suffix}) {
    return Container(
      decoration: BoxDecoration(color: _AuthPalette.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _AuthPalette.border)),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: _AuthPalette.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _AuthPalette.textMuted, fontSize: 14),
          prefixIcon: Icon(icon, color: _AuthPalette.textMuted, size: 20),
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