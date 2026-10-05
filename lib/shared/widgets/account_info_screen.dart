import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class AccountInfoScreen extends StatefulWidget {
  final String title;
  const AccountInfoScreen({super.key, required this.title});
  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  bool _loading = true;
  String _name = '-';
  String _id = '';
  bool _kycDone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final me = await ApiService.getMe();
      final user = me['user'];
      if (user is Map) {
        _name = (user['name'] ?? user['full_name'] ?? '-').toString();
        _id = (user['id'] ?? user['_id'] ?? '').toString();
        _kycDone = user['kyc_completed'] == true;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String get _code => _id.length >= 6 ? _id.substring(0, 6).toUpperCase() : '------';
  String get _num => _id.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) % 100000000).toString().padLeft(8, '0');

  @override
  Widget build(BuildContext context) {
    final isDemat = widget.title.startsWith('Demat');
    final rows = isDemat
        ? <List<String>>[
            ['Account Holder', _name],
            ['Depository', 'CDSL'],
            ['DP ID', 'IN$_num'.substring(0, 8)],
            ['BO ID', '1208$_num${_num.substring(0, 4)}'],
            ['Account Type', 'Individual'],
            ['Status', _kycDone ? 'Active' : 'Pending KYC'],
          ]
        : <List<String>>[
            ['Account Holder', _name],
            ['Client ID', 'DUR$_code'],
            ['Exchanges', 'NSE, BSE'],
            ['Segments', 'Equity, F&O'],
            ['Account Type', 'Individual'],
            ['Status', _kycDone ? 'Active' : 'Pending KYC'],
          ];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(widget.title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Column(
                    children: [
                      for (int i = 0; i < rows.length; i++) ...[
                        if (i > 0) const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1, color: AppColors.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(rows[i][0], style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                              Text(rows[i][1], style: TextStyle(color: rows[i][0] == 'Status' ? (_kycDone ? AppColors.success : AppColors.danger) : AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}