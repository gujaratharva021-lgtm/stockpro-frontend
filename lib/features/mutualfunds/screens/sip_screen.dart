import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class SipScreen extends StatefulWidget {
  const SipScreen({super.key});
  @override
  State<SipScreen> createState() => _SipScreenState();
}

class _SipScreenState extends State<SipScreen> {
  List<dynamic> _sips = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sips = await ApiService.getSIPs();
      if (mounted) setState(() => _sips = sips);
    } catch (_) {}
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _cancelSIP(String sipId, String fundName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel SIP', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to cancel SIP for $fundName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.cancelSIP(sipId);
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SIP cancelled successfully')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to cancel SIP')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSips = _sips.where((s) => s['status'] == 'active').toList();
    final cancelledSips = _sips.where((s) => s['status'] == 'cancelled').toList();
    final totalMonthly = activeSips.fold(0.0, (sum, s) => sum + ((s['amount'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 16, 0),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                      const Text('My SIPs', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
                    ],
                  ),
                ),
              ),

              if (_loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              else if (_sips.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.savings_outlined, color: AppColors.primary, size: 40),
                        ),
                        const SizedBox(height: 16),
                        const Text('No SIPs yet', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        const Text('Start a SIP from any Mutual Fund\nto grow your wealth systematically', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.5)),
                      ],
                    ),
                  ),
                )
              else ...[
                  // Summary card
                  if (activeSips.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Total Monthly SIP', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    Text('₹${totalMonthly.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('${activeSips.length} active SIP${activeSips.length > 1 ? 's' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                                child: const Icon(Icons.repeat, color: Colors.white, size: 28),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Active SIPs
                  if (activeSips.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Row(
                          children: [
                            Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 8),
                            Text('Active SIPs (${activeSips.length})', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) => _sipCard(activeSips[index], true),
                          childCount: activeSips.length,
                        ),
                      ),
                    ),
                  ],

                  // Cancelled SIPs
                  if (cancelledSips.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Row(
                          children: [
                            Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 8),
                            Text('Cancelled SIPs (${cancelledSips.length})', style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 15)),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) => _sipCard(cancelledSips[index], false),
                          childCount: cancelledSips.length,
                        ),
                      ),
                    ),
                  ],

                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sipCard(dynamic sip, bool isActive) {
    final fundName = sip['fund_name'] ?? 'Mutual Fund';
    final amount = (sip['amount'] as num?)?.toDouble() ?? 0;
    final frequency = (sip['frequency'] ?? 'monthly').toString();
    final nextDate = sip['next_date'] ?? '-';
    final initial = fundName.isNotEmpty ? fundName[0].toUpperCase() : 'F';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? AppColors.success.withOpacity(0.3) : AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.success.withOpacity(0.1) : AppColors.border,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text(initial, style: TextStyle(color: isActive ? AppColors.success : AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 18))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fundName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.success.withOpacity(0.12) : AppColors.border,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isActive ? '● ACTIVE' : '✕ CANCELLED',
                              style: TextStyle(color: isActive ? AppColors.success : AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(child: _statItem(Icons.currency_rupee, 'Amount', '₹${amount.toStringAsFixed(0)}')),
                      Container(width: 1, height: 32, color: AppColors.border),
                      Expanded(child: _statItem(Icons.repeat, 'Frequency', _capitalize(frequency))),
                      Container(width: 1, height: 32, color: AppColors.border),
                      Expanded(child: _statItem(Icons.calendar_today_outlined, 'Next Date', _formatDate(nextDate))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            InkWell(
              onTap: () => _cancelSIP(sip['id'], fundName),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: const Border(top: BorderSide(color: AppColors.border)),
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                ),
                child: const Center(
                  child: Text('Cancel SIP', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }

  String _formatDate(String date) {
    try {
      final parts = date.split('-');
      if (parts.length == 3) {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '${parts[2]} ${months[int.parse(parts[1]) - 1]}';
      }
    } catch (_) {}
    return date;
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}