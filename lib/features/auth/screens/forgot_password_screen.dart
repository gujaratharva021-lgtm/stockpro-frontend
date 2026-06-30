import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _otpSent = false;
  bool _showPassword = false;
  String? _error;
  String? _success;

  Future<void> _sendOTP() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiService.forgotPassword(email);
    } on DioException catch (e) {
      debugPrint('DIO ERROR: ${e.response?.data} type: ${e.response?.data?.runtimeType}');
      String errMsg = 'Failed to send OTP';
      final data = e.response?.data;
      if (data is Map) {
        errMsg = data['error']?.toString() ?? data['message']?.toString() ?? errMsg;
      } else if (data is String) {
        errMsg = data;
      }
      if (mounted) {
        setState(() {
          _error = errMsg;
          _loading = false;
        });
      }
      return;
    } catch (e, st) {
      debugPrint('FORGOT PASSWORD ERROR: $e');
      debugPrint('STACK: $st');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _otpSent = true;
        _success = 'OTP sent to your email';
        _error = null;
        _loading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    debugPrint('RESET PASSWORD TAPPED');
    final otp = _otpController.text.trim();
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (otp.isEmpty || newPass.isEmpty) {
      setState(() => _error = 'Please fill all fields');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (newPass.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiService.resetPassword(_emailController.text.trim(), otp, newPass);
    } on DioException catch (e) {
      debugPrint('RESET DIO ERROR: ${e.response?.data} type: ${e.response?.data?.runtimeType}');
      String errMsg = 'Reset failed';
      final data = e.response?.data;
      if (data is Map) {
        errMsg = data['error']?.toString() ?? data['message']?.toString() ?? errMsg;
      } else if (data is String) {
        errMsg = data;
      }
      if (mounted) {
        setState(() {
          _error = errMsg;
          _loading = false;
        });
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successful! Please login.'), backgroundColor: Colors.green),
      );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text('Forgot Password', style: TextStyle(color: AppColors.textPrimary, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Enter your email to receive an OTP', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
              const SizedBox(height: 32),
              _buildLabel('Email'),
              const SizedBox(height: 8),
              _buildField(
                controller: _emailController,
                hint: 'you@example.com',
                icon: Icons.mail_outline,
                enabled: !_otpSent,
              ),
              if (_otpSent) ...[
                const SizedBox(height: 18),
                _buildLabel('OTP'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _otpController,
                  hint: '6-digit OTP',
                  icon: Icons.lock_clock_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 18),
                _buildLabel('New Password'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _newPasswordController,
                  hint: 'Min 8 characters',
                  icon: Icons.lock_outline,
                  obscure: !_showPassword,
                  suffix: IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textMuted, size: 20),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                const SizedBox(height: 18),
                _buildLabel('Confirm Password'),
                const SizedBox(height: 8),
                _buildField(
                  controller: _confirmPasswordController,
                  hint: 'Re-enter password',
                  icon: Icons.lock_outline,
                  obscure: !_showPassword,
                ),
              ],
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
              if (_success != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withOpacity(0.25)),
                  ),
                  child: Text(_success!, style: const TextStyle(color: Colors.green, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : (_otpSent ? _resetPassword : _sendOTP),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _otpSent ? 'Reset Password' : 'Send OTP',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: _loading ? null : _sendOTP,
                    child: const Text('Resend OTP', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13));

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    bool enabled = true,
    Widget? suffix,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? AppColors.cardBackground : AppColors.cardBackground.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        keyboardType: keyboardType,
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
