import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class MtfOpenScreen extends StatefulWidget {
  final Map<String, dynamic> stock;
  final Map<String, dynamic>? position;
  const MtfOpenScreen({super.key, required this.stock, this.position});

  @override
  State<MtfOpenScreen> createState() => _MtfOpenScreenState();
}

class _MtfOpenScreenState extends State<MtfOpenScreen> {
  final _qtyController = TextEditingController();
  bool _loading = false;
  String? _message;
  Map<String, dynamic>? _quote;
  bool _quoteLoading = true;

  bool get _isExisting => widget.position != null;

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    setState(() => _quoteLoading = true);
    try {
      final q = await ApiService.getQuote(widget.stock['symbol']);
      setState(() => _quote = q);
    } catch (e) {
      setState(() => _message = 'Could not load live price');
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
  }

  double get _price => (_quote?['price'] as num?)?.toDouble() ?? 0.0;

  Future<void> _open() async {
    final qty = double.tryParse(_qtyController.text);
    if (qty == null || qty <= 0) {
      setState(() => _message = 'Enter a valid quantity');
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await ApiService.openMTFPosition(widget.stock['id'], widget.stock['symbol'], qty);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _message = _extractError(e, 'Could not open position'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _close() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await ApiService.closeMTFPosition(widget.position!['id'], widget.stock['symbol']);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _message = _extractError(e, 'Could not close position'));
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
    final qty = double.tryParse(_qtyController.text) ?? 0;
    final orderValue = qty * _price;
    final marginRequired = orderValue * 0.20;
    final borrowed = orderValue - marginRequired;

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
                      widget.stock['symbol'] ?? '',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _quoteLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('₹${_price.toStringAsFixed(2)}',
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(widget.stock['company_name'] ?? '',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          const SizedBox(height: 24),

                          if (_isExisting) ...[
                            _infoRow('Quantity', (widget.position!['quantity'] as num).toStringAsFixed(2)),
                            _infoRow('Entry Price', '₹${(widget.position!['entry_price'] as num).toStringAsFixed(2)}'),
                            _infoRow('Margin Paid', '₹${(widget.position!['margin_paid'] as num).toStringAsFixed(2)}'),
                            _infoRow('Borrowed Amount', '₹${(widget.position!['borrowed_amount'] as num).toStringAsFixed(2)}'),
                            _infoRow('Interest Rate', '${(widget.position!['interest_rate'] as num).toStringAsFixed(2)}% p.a.'),
                            const SizedBox(height: 24),
                            const Text('Closing will sell your full position at the current market price, deduct accrued interest and repay the borrowed amount, crediting the remainder to your wallet.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
                          ] else ...[
                            const Text('Open Margin Position', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 14),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: TextField(
                                controller: _qtyController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(color: AppColors.textPrimary),
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                  labelStyle: TextStyle(color: AppColors.textMuted),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _infoRow('Order Value', '₹${orderValue.toStringAsFixed(2)}'),
                            _infoRow('Margin Required (20%)', '₹${marginRequired.toStringAsFixed(2)}'),
                            _infoRow('Broker Funds (80%)', '₹${borrowed.toStringAsFixed(2)}'),
                            _infoRow('Interest Rate', '18.00% p.a. on borrowed amount'),
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
                              onPressed: _loading ? null : (_isExisting ? _close : _open),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isExisting ? AppColors.danger : AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _loading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(_isExisting ? 'CLOSE POSITION' : 'OPEN POSITION',
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