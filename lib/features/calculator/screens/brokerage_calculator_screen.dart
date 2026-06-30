import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class BrokerageCalculatorScreen extends StatefulWidget {
  const BrokerageCalculatorScreen({super.key});
  @override
  State<BrokerageCalculatorScreen> createState() => _BrokerageCalculatorScreenState();
}

class _BrokerageCalculatorScreenState extends State<BrokerageCalculatorScreen> {
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  String _tradeType = 'DELIVERY'; // DELIVERY or INTRADAY

  Map<String, double>? _result;

  void _calculate() {
    final buyPrice = double.tryParse(_buyPriceController.text) ?? 0;
    final sellPrice = double.tryParse(_sellPriceController.text) ?? 0;
    final qty = double.tryParse(_qtyController.text) ?? 0;

    if (buyPrice <= 0 || sellPrice <= 0 || qty <= 0) {
      setState(() => _result = null);
      return;
    }

    final buyTurnover = buyPrice * qty;
    final sellTurnover = sellPrice * qty;
    final isDelivery = _tradeType == 'DELIVERY';

    // Brokerage: zero for delivery (standard discount-broker model), flat fee for intraday
    double brokerage;
    if (isDelivery) {
      brokerage = 0;
    } else {
      final buyBrokerage = (buyTurnover * 0.0003).clamp(0, 20.0).toDouble();
      final sellBrokerage = (sellTurnover * 0.0003).clamp(0, 20.0).toDouble();
      brokerage = buyBrokerage + sellBrokerage;
    }

    // STT: delivery charged both sides at 0.1%; intraday only sell side at 0.025%
    double stt;
    if (isDelivery) {
      stt = (buyTurnover * 0.001) + (sellTurnover * 0.001);
    } else {
      stt = sellTurnover * 0.00025;
    }

    // Exchange transaction charges (NSE): ~0.00345% on total turnover
    final exchangeCharges = (buyTurnover + sellTurnover) * 0.0000345;

    // SEBI charges: ₹10 per crore = 0.0001%
    final sebiCharges = (buyTurnover + sellTurnover) * 0.000001;

    // GST: 18% on (brokerage + exchange charges + SEBI charges)
    final gst = (brokerage + exchangeCharges + sebiCharges) * 0.18;

    // Stamp duty: 0.015% on buy side for delivery, 0.003% for intraday
    final stampDuty = isDelivery ? buyTurnover * 0.00015 : buyTurnover * 0.00003;

    final totalCharges = brokerage + stt + exchangeCharges + sebiCharges + gst + stampDuty;
    final grossPnl = sellTurnover - buyTurnover;
    final netPnl = grossPnl - totalCharges;

    setState(() {
      _result = {
        'brokerage': brokerage,
        'stt': stt,
        'exchangeCharges': exchangeCharges,
        'sebiCharges': sebiCharges,
        'gst': gst,
        'stampDuty': stampDuty,
        'totalCharges': totalCharges,
        'grossPnl': grossPnl,
        'netPnl': netPnl,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Brokerage Calculator',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(child: _typeChip('DELIVERY', 'Delivery')),
                      const SizedBox(width: 10),
                      Expanded(child: _typeChip('INTRADAY', 'Intraday')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _inputField('Buy Price', _buyPriceController, prefix: '₹ '),
                  const SizedBox(height: 12),
                  _inputField('Sell Price', _sellPriceController, prefix: '₹ '),
                  const SizedBox(height: 12),
                  _inputField('Quantity', _qtyController),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _calculate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Calculate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Net P&L (after charges)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            '₹${_result!['netPnl']!.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: _result!['netPnl']! >= 0 ? AppColors.success : AppColors.danger,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gross P&L: ₹${_result!['grossPnl']!.toStringAsFixed(2)} • Total charges: ₹${_result!['totalCharges']!.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Charges Breakdown', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    _chargeRow('Brokerage', _result!['brokerage']!),
                    _chargeRow('STT (Securities Transaction Tax)', _result!['stt']!),
                    _chargeRow('Exchange Transaction Charges', _result!['exchangeCharges']!),
                    _chargeRow('SEBI Charges', _result!['sebiCharges']!),
                    _chargeRow('GST (18%)', _result!['gst']!),
                    _chargeRow('Stamp Duty', _result!['stampDuty']!),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Charges are estimates based on standard discount-broker rates and may vary slightly by broker and exchange.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String type, String label) {
    final isActive = _tradeType == type;
    return GestureDetector(
      onTap: () => setState(() => _tradeType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: isActive ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController controller, {String? prefix}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textMuted),
          prefixText: prefix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _chargeRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Text('₹${value.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}