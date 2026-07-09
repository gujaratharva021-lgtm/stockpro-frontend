import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class SetAlertScreen extends StatefulWidget {
  final Map<String, dynamic> stock;
  final double? currentPrice;
  const SetAlertScreen({super.key, required this.stock, this.currentPrice});

  @override
  State<SetAlertScreen> createState() => _SetAlertScreenState();
}

class _SetAlertScreenState extends State<SetAlertScreen> {
  late TextEditingController _priceController;
  String _direction = 'ABOVE';
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(text: widget.currentPrice?.toStringAsFixed(2) ?? '');
  }

  double get _percentDiff {
    final target = double.tryParse(_priceController.text);
    if (target == null || widget.currentPrice == null || widget.currentPrice == 0) return 0;
    return ((target - widget.currentPrice!) / widget.currentPrice!) * 100;
  }

  Future<void> _create() async {
    final target = double.tryParse(_priceController.text);
    if (target == null) {
      setState(() => _error = 'Enter a valid price');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      await ApiService.createAlert(widget.stock['id'], target, _direction);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert created')));
      }
    } catch (e) {
      setState(() { _submitting = false; _error = 'Could not create alert'; });
    }
  }

  Widget _fieldRow(String label, Widget content) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.border.withOpacity(0.3), borderRadius: const BorderRadius.horizontal(left: Radius.circular(10))),
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: content)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final symbol = widget.stock['symbol'] ?? '';
    final exchange = widget.stock['exchange'] ?? 'NSE';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(symbol, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Create alert', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 14),
                    _fieldRow('If', const Text('Last price')),
                    if (widget.currentPrice != null) ...[
                      const SizedBox(height: 4),
                      Padding(padding: const EdgeInsets.only(left: 4), child: Text('Last price ' + widget.currentPrice!.toStringAsFixed(2), style: const TextStyle(color: AppColors.textMuted, fontSize: 12))),
                    ],
                    const SizedBox(height: 14),
                    _fieldRow('of', Text(symbol + ' (' + exchange + ')')),
                    const SizedBox(height: 14),
                    _fieldRow('is', Row(children: [
                      Expanded(child: ChoiceChip(label: const Text('>= (Above)'), selected: _direction == 'ABOVE', onSelected: (_) => setState(() => _direction = 'ABOVE'))),
                      const SizedBox(width: 8),
                      Expanded(child: ChoiceChip(label: const Text('<= (Below)'), selected: _direction == 'BELOW', onSelected: (_) => setState(() => _direction = 'BELOW'))),
                    ])),
                    const SizedBox(height: 14),
                    _fieldRow('than', TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                    )),
                    const SizedBox(height: 8),
                    Text(_percentDiff.toStringAsFixed(2) + '% of Last price', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _create,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
                  child: _submitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('CREATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}