import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';

class AppCodeScreen extends StatefulWidget {
  const AppCodeScreen({super.key});
  @override
  State<AppCodeScreen> createState() => _AppCodeScreenState();
}

class _AppCodeScreenState extends State<AppCodeScreen> {
  String? _code;
  bool _isActive = true;
  bool _loading = true;
  bool _regenerating = false;
  DateTime? _createdAt;
  DateTime? _regeneratedAt;

  static const _baseUrl = 'https://adjimrxt3y.ap-south-1.awsapprunner.com/api/v1';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = Dio();
      final token = await ApiService.getToken();
      final res = await dio.get(
        '$_baseUrl/auth/app-code',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _code = res.data['code'];
        _isActive = res.data['is_active'] ?? true;
        _createdAt = res.data['created_at'] != null ? DateTime.tryParse(res.data['created_at'].toString()) : null;
        _regeneratedAt = res.data['regenerated_at'] != null ? DateTime.tryParse(res.data['regenerated_at'].toString()) : null;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load app code')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _regenerate() async {
    setState(() => _regenerating = true);
    try {
      final dio = Dio();
      final token = await ApiService.getToken();
      final res = await dio.post(
        '$_baseUrl/auth/app-code/regenerate',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() {
        _code = res.data['code'];
        _regeneratedAt = DateTime.now();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App code regenerated'), backgroundColor: AppColors.success),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not regenerate app code')),
        );
      }
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  Future<void> _toggleActive(bool value) async {
    final prev = _isActive;
    setState(() => _isActive = value);
    try {
      final dio = Dio();
      final token = await ApiService.getToken();
      await dio.post(
        '$_baseUrl/auth/app-code/toggle',
        data: {'is_active': value},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(value ? 'App code enabled' : 'App code disabled'), backgroundColor: AppColors.success),
        );
      }
    } catch (_) {
      setState(() => _isActive = prev);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update status')),
        );
      }
    }
  }

  void _confirmRegenerate() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Regenerate App Code', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'This will invalidate your current app code. Any third-party apps using the old code will stop working.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _regenerate();
            },
            child: const Text('Regenerate', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  void _copyCode() {
    if (_code == null) return;
    Clipboard.setData(ClipboardData(text: _code!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App code copied to clipboard'), backgroundColor: AppColors.success),
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '-';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 16, 0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                  const Expanded(child: Text('App Code', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18))),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Use this code to connect third-party apps to your trading account.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Your App Code', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (_isActive ? AppColors.success : AppColors.danger).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _isActive ? 'Active' : 'Disabled',
                                    style: TextStyle(color: _isActive ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _code ?? '-',
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy_outlined, color: AppColors.primary, size: 20),
                                  onPressed: _copyCode,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Created: ${_formatDate(_createdAt)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            if (_regeneratedAt != null)
                              Text('Last regenerated: ${_formatDate(_regeneratedAt)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Enable App Code', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                  SizedBox(height: 3),
                                  Text('Turn off to block all third-party access', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            Switch(value: _isActive, activeThumbColor: AppColors.primary, onChanged: _toggleActive),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _regenerating ? null : _confirmRegenerate,
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                          icon: _regenerating
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.danger, strokeWidth: 2))
                              : const Icon(Icons.refresh, color: AppColors.danger, size: 18),
                          label: const Text('Regenerate Code', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      if (kIsWeb) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => context.go('/watchlist'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            child: const Text('Continue to App', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}