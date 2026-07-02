import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/mutualfunds/screens/sip_screen.dart';

class FundDetailScreen extends StatefulWidget {
  final String fundId;
  const FundDetailScreen({super.key, required this.fundId});

  @override
  State<FundDetailScreen> createState() => _FundDetailScreenState();
}

class _FundDetailScreenState extends State<FundDetailScreen> {
  Map<String, dynamic>? _fund;
  bool _loading = true;
  String? _error;

  final _amountController = TextEditingController();
  bool _placingOrder = false;
  String? _orderMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fund = await ApiService.getMutualFundDetail(widget.fundId);
      setState(() => _fund = fund);
    } catch (e) {
      setState(() => _error = 'Could not load fund details');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _placeOrder(String buySell) async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _orderMessage = 'Enter a valid amount');
      return;
    }
    setState(() {
      _placingOrder = true;
      _orderMessage = null;
    });
    try {
      await ApiService.placeFundOrder(widget.fundId, buySell.toUpperCase(), amount);
      setState(() => _orderMessage = '${buySell == 'buy' ? 'Invested' : 'Redeemed'} ₹${amount.toStringAsFixed(2)} successfully');
      _load();
    } catch (e) {
      setState(() => _orderMessage = 'Order failed. ${e.toString().contains('insufficient') ? 'Insufficient balance/units' : 'Please try again'}');
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  void _showSIPSetup() {
    final amountController = TextEditingController();
    String frequency = 'monthly';
    DateTime nextDate = DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Start SIP', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              Text(_fund?['name'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              const Text('Monthly Amount', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(prefixText: '₹ ', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Frequency', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: ['monthly', 'weekly', 'daily'].map((f) => Expanded(
                  child: GestureDetector(
                    onTap: () => setS(() => frequency = f),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: frequency == f ? AppColors.primary.withOpacity(0.1) : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: frequency == f ? AppColors.primary : AppColors.border),
                      ),
                      child: Center(child: Text(f[0].toUpperCase() + f.substring(1), style: TextStyle(color: frequency == f ? AppColors.primary : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('First SIP Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(context: ctx, initialDate: nextDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (picked != null) setS(() => nextDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('${nextDate.day}/${nextDate.month}/${nextDate.year}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
                      return;
                    }
                    try {
                      await ApiService.createSIP(widget.fundId, amount, frequency, '${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}');
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SIP started successfully!')));
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to start SIP')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Start SIP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = _fund != null ? (_fund!['nav'] as num).toDouble() : 0.0;
    final holdings = _fund?['holdings'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      _fund?['name'] ?? 'Fund',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary)))
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NAV: ₹${nav.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _fund?['description'] ?? '',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    const Text('Holdings', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: holdings.map<Widget>((h) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${h['symbol']} — ${h['company_name']}',
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                ),
                                Text(
                                  '${(h['weight_percent'] as num).toStringAsFixed(0)}%',
                                  style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text('Invest / Redeem', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          labelStyle: TextStyle(color: AppColors.textMuted),
                          prefixText: '₹ ',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    if (_orderMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _orderMessage!,
                        style: TextStyle(
                          color: _orderMessage!.toLowerCase().contains('success') ? AppColors.success : AppColors.danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _showSIPSetup(),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(Icons.repeat, size: 18),
                        label: const Text('Start SIP', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _showSIPSetup(),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(Icons.repeat, size: 18),
                        label: const Text('Start SIP', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _placingOrder ? null : () => _placeOrder('buy'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _placingOrder
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('INVEST', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _placingOrder ? null : () => _placeOrder('sell'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('REDEEM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
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
}