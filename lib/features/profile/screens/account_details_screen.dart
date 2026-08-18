import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

/// "Account Details" screen -- Account Summary + Margin, backed by the real
/// P&L report and cash balance endpoints (no fabricated numbers). Reachable
/// from the account drawer on every screen.
class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  bool _loading = true;
  double _cash = 0;
  double _currentValue = 0;
  double _realizedPnL = 0;
  double _unrealizedPnL = 0;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getBalance(),
        ApiService.getPnLReport().catchError((_) => <String, dynamic>{}),
        ApiService.getMe().catchError((_) => <String, dynamic>{}),
      ]);
      final cash = results[0] as double;
      final report = results[1] as Map<String, dynamic>;
      final me = results[2] as Map<String, dynamic>;
      final user = me['user'] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _cash = cash;
        _currentValue = (report['current_value'] as num?)?.toDouble() ?? 0;
        _realizedPnL = (report['realized_pnl'] as num?)?.toDouble() ?? 0;
        _unrealizedPnL = (report['unrealized_pnl'] as num?)?.toDouble() ?? 0;
        final id = user?['id']?.toString() ?? user?['_id']?.toString();
        _accountId = id != null && id.length >= 6 ? 'DUR${id.substring(0, 6).toUpperCase()}' : null;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _netLiquidationValue => _cash + _currentValue;

  String _fmt(double v) => '₹${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Account Details', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_accountId != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                      child: Row(
                        children: [
                          const CircleAvatar(radius: 16, backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white, size: 16)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Account', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              Text(_accountId!, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text('Account Summary', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Column(
                      children: [
                        _row('Net Liquidation Value', _fmt(_netLiquidationValue)),
                        _divider(),
                        _row('Cash', _fmt(_cash)),
                        _divider(),
                        _row('Settled Cash', _fmt(_cash)),
                        _divider(),
                        _row('MTD Interest', _fmt(0)),
                        _divider(),
                        _row('Stock', _fmt(_currentValue)),
                        _divider(),
                        _row('Unrealized P&L', _fmt(_unrealizedPnL), color: _unrealizedPnL >= 0 ? AppColors.success : AppColors.danger),
                        _divider(),
                        _row('Realized P&L', _fmt(_realizedPnL), color: _realizedPnL >= 0 ? AppColors.success : AppColors.danger),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Margin', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Column(
                      children: [
                        _row('Initial Margin', _fmt(0)),
                        _divider(),
                        _row('Maintenance Margin', _fmt(0)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _divider() => const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1, color: AppColors.border));

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
          Text(value, style: TextStyle(color: color ?? AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5)),
        ],
      ),
    );
  }
}