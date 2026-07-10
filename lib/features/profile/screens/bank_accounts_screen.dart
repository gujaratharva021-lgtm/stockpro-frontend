import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key});
  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  List<dynamic> _accounts = [];
  bool _loading = true;
  bool _saving = false;

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
        '$_baseUrl/auth/bank-accounts',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() => _accounts = res.data['bank_accounts'] ?? []);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load bank accounts')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addAccount(String bankName, String accountNumber, String ifsc, String holderName) async {
    setState(() => _saving = true);
    try {
      final dio = Dio();
      final token = await ApiService.getToken();
      await dio.post(
        '$_baseUrl/auth/bank-accounts',
        data: {
          'bank_name': bankName,
          'account_number': accountNumber,
          'ifsc_code': ifsc,
          'holder_name': holderName,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (mounted) Navigator.pop(context);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank account added'), backgroundColor: AppColors.success),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add bank account')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount(String id) async {
    try {
      final dio = Dio();
      final token = await ApiService.getToken();
      await dio.delete(
        '$_baseUrl/auth/bank-accounts/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank account removed'), backgroundColor: AppColors.success),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove bank account')),
        );
      }
    }
  }

  void _showAddSheet() {
    final bankNameCtrl = TextEditingController();
    final accNumberCtrl = TextEditingController();
    final ifscCtrl = TextEditingController();
    final holderCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Bank Account', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                _input('Bank Name', bankNameCtrl),
                const SizedBox(height: 12),
                _input('Account Holder Name', holderCtrl),
                const SizedBox(height: 12),
                _input('Account Number', accNumberCtrl, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _input('IFSC Code', ifscCtrl, textCapitalization: TextCapitalization.characters),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saving
                        ? null
                        : () {
                      if (bankNameCtrl.text.trim().isEmpty ||
                          accNumberCtrl.text.trim().isEmpty ||
                          ifscCtrl.text.trim().isEmpty ||
                          holderCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please fill all fields')),
                        );
                        return;
                      }
                      _addAccount(
                        bankNameCtrl.text.trim(),
                        accNumberCtrl.text.trim(),
                        ifscCtrl.text.trim(),
                        holderCtrl.text.trim(),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: _saving
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Add Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _input(String label, TextEditingController controller, {TextInputType? keyboardType, TextCapitalization textCapitalization = TextCapitalization.none}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary)),
      ),
    );
  }

  void _confirmDelete(String id, String bankName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Remove Account', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Remove $bankName account?', style: const TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAccount(id);
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
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
                  const Expanded(child: Text('Bank Accounts', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18))),
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: AppColors.primary), onPressed: _showAddSheet),
                ],
              ),
            ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_accounts.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_balance_outlined, color: AppColors.textMuted, size: 48),
                      const SizedBox(height: 12),
                      const Text('No bank accounts added', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _showAddSheet,
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: const Text('Add Bank Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
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
                    itemCount: _accounts.length,
                    itemBuilder: (ctx, i) {
                      final acc = _accounts[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.account_balance, color: AppColors.primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(acc['bank_name'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                      if (acc['is_primary'] == true) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                          child: const Text('Primary', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(acc['account_number'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                  Text(acc['ifsc_code'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                              onPressed: () => _confirmDelete(acc['id'], acc['bank_name'] ?? ''),
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