import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class GttScreen extends StatefulWidget {
  final Map<String, dynamic> stock;
  final double? currentPrice;
  final double? changePercent;
  const GttScreen({super.key, required this.stock, this.currentPrice, this.changePercent});

  @override
  State<GttScreen> createState() => _GttScreenState();
}

class _GttScreenState extends State<GttScreen> {
  String _buySell = 'BUY';
  late TextEditingController _triggerController;
  late TextEditingController _qtyController;
  bool _agree = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final defaultTrigger = widget.currentPrice != null ? (widget.currentPrice! * 1.05) : 0.0;
    _triggerController = TextEditingController(text: defaultTrigger.toStringAsFixed(2));
    _qtyController = TextEditingController(text: '1');
  }

  double get _triggerPercent {
    final t = double.tryParse(_triggerController.text);
    if (t == null || widget.currentPrice == null || widget.currentPrice == 0) return 0;
    return ((t - widget.currentPrice!) / widget.currentPrice!) * 100;
  }

  Future<void> _create() async {
    final trigger = double.tryParse(_triggerController.text);
    final qty = double.tryParse(_qtyController.text);
    if (trigger == null || qty == null || qty <= 0) {
      setState(() => _error = 'Enter valid price and quantity');
      return;
    }
    if (!_agree) {
      setState(() => _error = 'Please accept the terms to continue');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      await ApiService.createPendingOrder(widget.stock['id'], _buySell, 'LIMIT', qty, trigger, isGtt: true);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GTT order created')));
      }
    } catch (e) {
      setState(() { _submitting = false; _error = 'Could not create GTT order'; });
    }
  }

  Widget _pill(String label, bool selected, VoidCallback? onTap, {bool disabled = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
            borderRadius: BorderRadius.circular(8),
            color: disabled ? AppColors.border.withOpacity(0.15) : Colors.transparent,
          ),
          child: Text(label, style: TextStyle(color: disabled ? AppColors.textMuted : (selected ? AppColors.primary : AppColors.textPrimary), fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final symbol = widget.stock['symbol'] ?? '';
    final exchange = widget.stock['exchange'] ?? 'NSE';
    final isUp = (widget.changePercent ?? 0) >= 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Row(
          children: [
            Text(symbol, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            Text(exchange, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            if (widget.currentPrice != null) ...[
              const SizedBox(width: 8),
              Text(widget.currentPrice!.toStringAsFixed(2), style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                _pill('Buy', _buySell == 'BUY', () => setState(() => _buySell = 'BUY')),
                _pill('Sell', _buySell == 'SELL', () => setState(() => _buySell = 'SELL')),
              ]),
              const SizedBox(height: 18),
              const Text('Trigger type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Row(children: [
                _pill('Single', true, null),
                _pill('OCO', false, null, disabled: true),
              ]),
              const SizedBox(height: 18),
              const Text('Trigger price', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(children: [
                  Expanded(child: TextField(
                    controller: _triggerController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  )),
                  Text(_triggerPercent.toStringAsFixed(2) + '% of LTP', style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                ]),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Order', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: AppColors.primary), borderRadius: BorderRadius.circular(8)), child: const Text('LIMIT', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Product', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: AppColors.primary), borderRadius: BorderRadius.circular(8)), child: const Text('CNC', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600))),
                ])),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 14), child: TextField(controller: _qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(border: InputBorder.none, isDense: true))),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Price', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Text(_triggerController.text.isEmpty ? '-' : _triggerController.text, style: const TextStyle(color: AppColors.textPrimary)),
                  ),
                ])),
              ]),
              const SizedBox(height: 16),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Checkbox(value: _agree, onChanged: (v) => setState(() => _agree = v ?? false)),
                const Expanded(child: Text('I agree to the terms and accept that trigger executions are not guaranteed.', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
              ]),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _create,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
                  child: _submitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('CREATE GTT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}