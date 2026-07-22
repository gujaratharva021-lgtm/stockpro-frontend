import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class LinkWebSessionScreen extends StatefulWidget {
  const LinkWebSessionScreen({super.key});

  @override
  State<LinkWebSessionScreen> createState() => _LinkWebSessionScreenState();
}

class _LinkWebSessionScreenState extends State<LinkWebSessionScreen> {
  final _codeController = TextEditingController();
  bool _submitting = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code shown on your web screen');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final dio = Dio();
      final token = await ApiService.getToken();
      await dio.post(
        '${ApiService.baseUrl}/auth/web-session/link',
        data: {'code': code},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() => _success = true);
    } on DioException catch (e) {
      final msg = e.response?.data?['error']?.toString() ?? 'Could not link session';
      setState(() => _error = msg);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                  const Expanded(child: Text('Link Web Session', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18))),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _success ? _buildSuccess() : _buildForm(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.desktop_windows_outlined, color: AppColors.primary, size: 28),
        ),
        const SizedBox(height: 18),
        const Text('Enter the code from your browser', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text(
          'Open OneInvest on your computer, tap "Login with Code", and type the 6-character code shown there.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.cardBackground,
            hintText: 'CODE',
            hintStyle: const TextStyle(color: AppColors.textMuted, letterSpacing: 6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Link Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 34),
          ),
          const SizedBox(height: 18),
          const Text('Web session linked!', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Your browser will log in automatically.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }
}