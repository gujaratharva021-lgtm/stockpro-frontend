import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class CodeLoginScreen extends StatefulWidget {
  const CodeLoginScreen({super.key});

  @override
  State<CodeLoginScreen> createState() => _CodeLoginScreenState();
}

class _CodeLoginScreenState extends State<CodeLoginScreen> {
  String? _code;
  String _status = 'loading';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _generateCode();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateCode() async {
    setState(() => _status = 'loading');
    try {
      final dio = Dio();
      final res = await dio.post('${ApiService.baseUrl}/auth/web-session/create');
      setState(() {
        _code = res.data['code'];
        _status = 'pending';
      });
      _startPolling();
    } catch (_) {
      setState(() => _status = 'error');
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_code == null) return;
      try {
        final dio = Dio();
        final res = await dio.get('${ApiService.baseUrl}/auth/web-session/status/$_code');
        final status = res.data['status'];
        if (status == 'linked') {
          _pollTimer?.cancel();
          const storage = FlutterSecureStorage();
          await storage.write(key: 'auth_token', value: res.data['token']);
          if (mounted) context.go('/watchlist');
        } else if (status == 'expired') {
          _pollTimer?.cancel();
          if (mounted) setState(() => _status = 'expired');
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    alignment: Alignment.centerLeft,
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.phonelink_lock_outlined, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Login with Mobile App',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter this code in your OneInvest mobile app under Profile ? Link Web Session',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  _buildCodeCard(),
                  const SizedBox(height: 20),
                  if (_status == 'pending') _buildWaitingRow(),
                  if (_status == 'expired') _buildExpiredRow(),
                  if (_status == 'error') _buildErrorRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: _status == 'loading'
          ? const SizedBox(
              height: 36,
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5)),
            )
          : Text(
              _code ?? '------',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 34,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
            ),
    );
  }

  Widget _buildWaitingRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(color: AppColors.textMuted, strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        const Text('Waiting for confirmation...', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ],
    );
  }

  Widget _buildExpiredRow() {
    return Column(
      children: [
        const Text('Code expired', style: TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        TextButton(onPressed: _generateCode, child: const Text('Get a new code')),
      ],
    );
  }

  Widget _buildErrorRow() {
    return Column(
      children: [
        const Text('Could not connect. Try again.', style: TextStyle(color: AppColors.danger, fontSize: 13)),
        const SizedBox(height: 10),
        TextButton(onPressed: _generateCode, child: const Text('Retry')),
      ],
    );
  }
}