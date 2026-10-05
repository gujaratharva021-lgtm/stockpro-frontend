import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:lottie/lottie.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/services/websocket_service.dart';

// Scoped "investor" palette for this screen only -- the rest of the
// app uses the blue OneInvest palette from AppColors, so these constants
// are kept local rather than touching the shared theme file.
class _LoginPalette {
  static const bg = Colors.black;
  static const green = Color(0xFF4C8DFF);
  static const ink = Colors.white;
  static const field = Color(0xFF171C15);
  static const border = Color(0xFF262E23);
  static const textMuted = Color(0xFF8C978C);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  bool _rememberMe = true;
  String? _error;
  AnimationController? _lottieController;

  @override
  void dispose() {
    _lottieController?.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.login(_emailController.text.trim(), _passwordController.text);
      const storage = FlutterSecureStorage();
      await storage.write(key: 'auth_token', value: res['token']);
      WebSocketService.connect();
      if (mounted) context.go('/dashboard');
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
    return Scaffold(
      backgroundColor: _LoginPalette.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAnimation(),
                    const SizedBox(height: 4),
                    _buildHeading(),
                    const SizedBox(height: 24),
                    _buildForm(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimation() {
    return SizedBox(
      height: 210,
      child: Lottie.asset(
        'assets/animations/splash_animation.json',
        fit: BoxFit.contain,
        controller: _lottieController,
        onLoaded: (composition) {
          _lottieController = AnimationController(vsync: this, duration: composition.duration * 2)
            ..repeat();
          setState(() {});
        },
      ),
    );
  }

  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.2),
            children: [
              TextSpan(text: 'Welcome Back, ', style: TextStyle(color: _LoginPalette.ink)),
              TextSpan(text: 'Investor!', style: TextStyle(color: _LoginPalette.green)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(width: 32, height: 3, color: _LoginPalette.green),
        const SizedBox(height: 10),
        const Text(
          'Login to access your investments and markets',
          style: TextStyle(color: _LoginPalette.textMuted, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        _buildField(controller: _emailController, hint: 'Enter your email', icon: Icons.mail_outline),
        const SizedBox(height: 12),
        _buildField(
          controller: _passwordController,
          hint: 'Enter your password',
          icon: Icons.lock_outline,
          obscure: !_showPassword,
          suffix: IconButton(
            icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: _LoginPalette.textMuted, size: 20),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _rememberMe ? _LoginPalette.green : Colors.transparent,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: _rememberMe ? _LoginPalette.green : _LoginPalette.border, width: 1.5),
                    ),
                    child: _rememberMe ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 8),
                  const Text('Remember me', style: TextStyle(color: _LoginPalette.ink, fontSize: 13.5)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => context.go('/forgot-password'),
              child: const Text('Forgot Password?',
                  style: TextStyle(color: _LoginPalette.green, fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
            ),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _loading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: _LoginPalette.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Login', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 17),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: () => context.go('/signup'),
            child: RichText(
              text: TextSpan(
                text: 'New to StockPro? ',
                style: const TextStyle(color: _LoginPalette.textMuted, fontSize: 14),
                children: const [
                  TextSpan(text: 'Sign Up', style: TextStyle(color: _LoginPalette.green, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _LoginPalette.field,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _LoginPalette.border),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: _LoginPalette.ink, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _LoginPalette.textMuted, fontSize: 14),
          prefixIcon: Icon(icon, color: _LoginPalette.green, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}


