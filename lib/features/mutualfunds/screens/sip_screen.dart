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
        title: const Text('Cancel SIP'),
        content: Text('Cancel SIP for $fundName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel SIP', style: TextStyle(color: Colors.white)),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                      const Text('My SIPs', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
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
                        Icon(Icons.savings_outlined, color: AppColors.textMuted, size: 48),
                        const SizedBox(height: 12),
                        const Text('No active SIPs', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                        const SizedBox(height: 6),
                        const Text('Start a SIP from any Mutual Fund', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else ...[
                  if (activeSips.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text('Active SIPs (${activeSips.length})', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
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
                  if (cancelledSips.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text('Cancelled SIPs (${cancelledSips.length})', style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 14)),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? AppColors.border : AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.savings_outlined, color: AppColors.primaryDark, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fundName, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.success.withOpacity(0.12) : AppColors.textMuted.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(isActive ? 'ACTIVE' : 'CANCELLED', style: TextStyle(color: isActive ? AppColors.success : AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _statCol('Amount', '₹${amount.toStringAsFixed(0)}')),
              Expanded(child: _statCol('Frequency', frequency.capitalize())),
              Expanded(child: _statCol('Next Date', nextDate)),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _cancelSIP(sip['id'], fundName),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                child: const Text('Cancel SIP'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}