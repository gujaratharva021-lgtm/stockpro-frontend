import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class ConnectedAppsScreen extends StatefulWidget {
  const ConnectedAppsScreen({super.key});
  @override
  State<ConnectedAppsScreen> createState() => _ConnectedAppsScreenState();
}

class _ConnectedAppsScreenState extends State<ConnectedAppsScreen> {
  List<dynamic> _apps = [];
  bool _loading = true;

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
        '$_baseUrl/auth/connected-apps',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() => _apps = res.data['connected_apps'] ?? []);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load connected apps')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revoke(String id) async {
    try {
      final dio = Dio();
      final token = await ApiService.getToken();
      await dio.delete(
        '$_baseUrl/auth/connected-apps/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access revoked'), backgroundColor: AppColors.success),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not revoke access')),
        );
      }
    }
  }

  void _confirmRevoke(String id, String appName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Revoke Access', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Revoke access for $appName? This app will no longer be able to access your account.', style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _revoke(id);
            },
            child: const Text('Revoke', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'Never';
    try {
      final d = DateTime.parse(dateStr.toString());
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return '-';
    }
  }

  IconData _iconFor(String? icon) {
    switch (icon) {
      case 'language':
        return Icons.language;
      case 'phone_android':
        return Icons.phone_android;
      case 'code':
        return Icons.code;
      default:
        return Icons.apps;
    }
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
                  const Expanded(child: Text('Connected Apps', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18))),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_apps.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.apps_outlined, color: AppColors.textMuted, size: 48),
                      SizedBox(height: 12),
                      Text('No connected apps', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _apps.length,
                    itemBuilder: (ctx, i) {
                      final app = _apps[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                  child: Icon(_iconFor(app['app_icon']), color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(app['app_name'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                                TextButton(
                                  onPressed: () => _confirmRevoke(app['id'], app['app_name'] ?? ''),
                                  child: const Text('Revoke', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(color: AppColors.border, height: 1),
                            const SizedBox(height: 10),
                            Text('Permissions', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(app['permissions'] ?? '-', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Connected: ${_formatDate(app['connected_at'])}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                Text('Last used: ${_formatDate(app['last_used_at'])}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}