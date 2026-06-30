import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class EtfDetailScreen extends StatefulWidget {
  final String etfId;
  const EtfDetailScreen({super.key, required this.etfId});

  @override
  State<EtfDetailScreen> createState() => _EtfDetailScreenState();
}

class _EtfDetailScreenState extends State<EtfDetailScreen> {
  Map<String, dynamic>? _etf;
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
      final etf = await ApiService.getETFDetail(widget.etfId);
      setState(() => _etf = etf);
    } catch (e) {
      setState(() => _error = 'Could not load ETF details');
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
      await ApiService.placeETFOrder(widget.etfId, buySell.toUpperCase(), amount);
      setState(() => _orderMessage = '${buySell == 'buy' ? 'Bought' : 'Sold'} ₹${amount.toStringAsFixed(2)} worth successfully');
      _load();
    } catch (e) {
      String message = 'Order failed. Please try again';
      String serverMsg = '';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['error'] != null) {
          serverMsg = data['error'].toString();
        }
      }
      if (serverMsg.isEmpty) serverMsg = e.toString();

      if (serverMsg.contains('insufficient')) {
        message = 'Order failed. Insufficient balance/units';
      } else if (serverMsg.isNotEmpty) {
        message = 'Order failed. $serverMsg';
      }
      setState(() => _orderMessage = message);
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = _etf != null ? (_etf!['price'] as num?)?.toDouble() ?? 0.0 : 0.0;

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
                      _etf?['name'] ?? 'ETF',
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
                              Row(
                                children: [
                                  Text(
                                    _etf?['symbol'] ?? '',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _etf?['category'] ?? 'Other',
                                      style: const TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '₹${price.toStringAsFixed(2)}',
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Expense Ratio: ${(_etf?['expense_ratio'] as num?)?.toStringAsFixed(2) ?? '-'}%',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _etf?['description'] ?? '',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                              ),
                              const SizedBox(height: 28),
                              const Text('Buy / Sell', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
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
                                            : const Text('BUY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                                        child: const Text('SELL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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