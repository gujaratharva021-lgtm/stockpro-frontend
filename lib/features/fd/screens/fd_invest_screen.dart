import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class FdInvestScreen extends StatefulWidget {
  final Map<String, dynamic>? product;
  final Map<String, dynamic>? investment;
  const FdInvestScreen({super.key, this.product, this.investment});

  @override
  State<FdInvestScreen> createState() => _FdInvestScreenState();
}

class _FdInvestScreenState extends State<FdInvestScreen> {
  final _amountController = TextEditingController();
  bool _loading = false;
  String? _message;

  bool get _isWithdraw => widget.investment != null;

  double get _rate => _isWithdraw
      ? (widget.investment!['interest_rate'] as num).toDouble()
      : (widget.product!['interest_rate'] as num).toDouble();

  int get _tenure => _isWithdraw
      ? widget.investment!['tenure_months'] as int
      : widget.product!['tenure_months'] as int;

  double get _previewMaturity {
    final amount = double.tryParse(_amountController.text) ?? 0;
    return amount + (amount * (_rate / 100) * (_tenure / 12));
  }

  Future<void> _invest() async {
    final amount = double.tryParse(_amountController.text);
    final minInv = (widget.product!['min_investment'] as num).toDouble();
    final maxInv = (widget.product!['max_investment'] as num).toDouble();

    if (amount == null || amount <= 0) {
      setState(() => _message = 'Enter a valid amount');
      return;
    }
    if (amount < minInv) {
      setState(() => _message = 'Minimum investment is ₹${minInv.toStringAsFixed(0)}');
      return;
    }
    if (amount > maxInv) {
      setState(() => _message = 'Maximum investment is ₹${maxInv.toStringAsFixed(0)}');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await ApiService.investFD(widget.product!['id'], amount);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invested ₹${amount.toStringAsFixed(2)} successfully')),
        );
      }
    } catch (e) {
      setState(() => _message = _extractError(e, 'Investment failed'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _withdraw() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final payout = await ApiService.withdrawFD(widget.investment!['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Withdrawn successfully: ₹${payout.toStringAsFixed(2)} credited')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _message = _extractError(e, 'Withdrawal failed'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _extractError(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) return data['error'].toString();
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
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
                      _isWithdraw ? widget.investment!['bank_name'] ?? 'FD' : widget.product!['bank_name'] ?? 'FD',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isWithdraw) ...[
                      _infoRow('Principal', '₹${(widget.investment!['principal'] as num).toStringAsFixed(2)}'),
                      _infoRow('Interest Rate', '${_rate.toStringAsFixed(2)}% p.a.'),
                      _infoRow('Tenure', '${(_tenure / 12).toStringAsFixed(_tenure % 12 == 0 ? 0 : 1)} yr'),
                      _infoRow('Maturity Value', '₹${(widget.investment!['maturity_amount'] as num).toStringAsFixed(2)}'),
                      const SizedBox(height: 24),
                      const Text(
                        'Withdrawing before maturity applies a small early-withdrawal penalty and reduces accrued interest. Withdrawing at or after maturity pays the full maturity value.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
                      ),
                    ] else ...[
                      const Text('Invest Amount', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
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
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            labelStyle: TextStyle(color: AppColors.textMuted),
                            prefixText: '₹ ',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _infoRow('Interest Rate', '${_rate.toStringAsFixed(2)}% p.a.'),
                      _infoRow('Tenure', '${(_tenure / 12).toStringAsFixed(_tenure % 12 == 0 ? 0 : 1)} yr'),
                      _infoRow('Min Investment', '₹${(widget.product!['min_investment'] as num).toStringAsFixed(0)}'),
                      _infoRow('Estimated Maturity Value', '₹${_previewMaturity.toStringAsFixed(2)}'),
                    ],

                    if (_message != null) ...[
                      const SizedBox(height: 14),
                      Text(_message!, style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _loading ? null : (_isWithdraw ? _withdraw : _invest),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isWithdraw ? AppColors.danger : AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(_isWithdraw ? 'WITHDRAW' : 'INVEST NOW',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}