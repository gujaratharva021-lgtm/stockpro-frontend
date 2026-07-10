import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/profile/screens/bank_accounts_screen.dart';
import 'package:stock_app/features/profile/screens/kyc_documents_screen.dart';
import 'package:dio/dio.dart';

class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});
  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;

  late TextEditingController _nameController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getMe();
      final user = res['user'];
      setState(() {
        _user = user;
        _nameController.text = user['name'] ?? '';
        _emailController.text = user['email'] ?? '';
      });
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final dio = Dio();
      final token = await ApiService.getToken();
      await dio.patch(
        'https://adjimrxt3y.ap-south-1.awsapprunner.com/api/v1/auth/profile',
        data: {'name': _nameController.text.trim()},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      setState(() => _editing = false);
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully'), backgroundColor: AppColors.success));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update profile')));
    }
    finally { if (mounted) setState(() => _saving = false); }
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
                  const Expanded(child: Text('Personal Details', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18))),
                  if (!_editing)
                    TextButton(
                      onPressed: () => setState(() => _editing = true),
                      child: const Text('Edit', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    )
                  else
                    TextButton(
                      onPressed: () => setState(() { _editing = false; _nameController.text = _user?['name'] ?? ''; }),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                    ),
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
                      // Avatar
                      Center(
                        child: Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                            image: _user?['avatar_url'] != null
                                ? DecorationImage(image: NetworkImage('https://adjimrxt3y.ap-south-1.awsapprunner.com${_user!['avatar_url']}'), fit: BoxFit.cover)
                                : null,
                          ),
                          child: _user?['avatar_url'] == null
                              ? Center(child: Text((_user?['name'] ?? 'T')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32)))
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Details
                      _detailCard([
                        _fieldRow('Full Name', _nameController, _editing, Icons.person_outline),
                        const Divider(color: AppColors.border, height: 1),
                        _fieldRow('Email', _emailController, false, Icons.email_outlined, readOnly: true),
                        const Divider(color: AppColors.border, height: 1),
                        _infoRow(Icons.verified_outlined, 'KYC Status', _user?['kyc_completed'] == true ? 'Verified' : 'Pending', _user?['kyc_completed'] == true ? AppColors.success : AppColors.danger),
                        const Divider(color: AppColors.border, height: 1),
                        _infoRow(Icons.calendar_today_outlined, 'Member Since', _formatDate(_user?['created_at']), null),
                      ]),

                      if (_editing) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            child: _saving
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Bank Accounts & KYC section
                      const Text('Bank & Verification', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      _detailCard([
                        _navRow(Icons.account_balance_outlined, 'Bank Accounts', 'Manage your linked bank accounts', () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const BankAccountsScreen()));
                        }),
                        const Divider(color: AppColors.border, height: 1),
                        _navRow(Icons.badge_outlined, 'KYC & Documents', 'PAN, Aadhaar and verification status', () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const KycDocumentsScreen()));
                        }),
                      ]),

                      const SizedBox(height: 24),
                      // Account ID
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                        child: Row(
                          children: [
                            const Icon(Icons.tag, color: AppColors.textMuted, size: 18),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Account ID', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                Text(_user?['id']?.toString().substring(0, 8).toUpperCase() ?? '-', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(children: children),
    );
  }

  Widget _fieldRow(String label, TextEditingController controller, bool editable, IconData icon, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(height: 4),
                editable && !readOnly
                    ? TextField(
                  controller: controller,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                )
                    : Text(controller.text, style: TextStyle(color: readOnly ? AppColors.textMuted : AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (readOnly) const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 14),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color? valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navRow(IconData icon, String label, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final d = DateTime.parse(dateStr.toString());
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) { return '-'; }
  }
}