import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/mutualfunds/screens/sip_screen.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

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
  late Razorpay _razorpay;
  double _pendingSIPAmount = 0;
  String _pendingSIPFrequency = 'monthly';
  String _pendingSIPDate = '';

  @override
  void initState() {
    super.initState();
    _load();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSIPPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onSIPPaymentError);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _onSIPPaymentSuccess(PaymentSuccessResponse response) async {
    try {
      await ApiService.createSIP(widget.fundId, _pendingSIPAmount, _pendingSIPFrequency, _pendingSIPDate);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('SIP of ₹${_pendingSIPAmount.toStringAsFixed(0)} started successfully!'),
            ]),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment done but SIP setup failed. Contact support.')));
    }
  }

  void _onSIPPaymentError(PaymentFailureResponse response) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message ?? 'Unknown error'}'), backgroundColor: AppColors.danger),
    );
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
    final quickAmounts = [500, 1000, 2000, 5000];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)))),

              // Header
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.repeat, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start SIP', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(_fund?['name'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Quick amount chips
              const Text('Select Amount', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                children: quickAmounts.map((amt) => Expanded(
                  child: GestureDetector(
                    onTap: () { setS(() {}); amountController.text = amt.toString(); },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: amountController.text == amt.toString() ? AppColors.primary.withOpacity(0.1) : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: amountController.text == amt.toString() ? AppColors.primary : AppColors.border),
                      ),
                      child: Center(
                        child: Text('₹$amt', style: TextStyle(
                          color: amountController.text == amt.toString() ? AppColors.primary : AppColors.textSecondary,
                          fontSize: 12, fontWeight: FontWeight.w600,
                        )),
                      ),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 12),

              // Custom amount input
              Container(
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setS(() {}),
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
                    hintText: 'Enter custom amount',
                    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Frequency
              const Text('Frequency', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _freqChip('monthly', 'Monthly', Icons.calendar_month_outlined, frequency, (f) => setS(() => frequency = f)),
                  const SizedBox(width: 8),
                  _freqChip('weekly', 'Weekly', Icons.view_week_outlined, frequency, (f) => setS(() => frequency = f)),
                  const SizedBox(width: 8),
                  _freqChip('daily', 'Daily', Icons.today_outlined, frequency, (f) => setS(() => frequency = f)),
                ],
              ),
              const SizedBox(height: 16),

              // Date
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: nextDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setS(() => nextDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      const Text('First SIP Date', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const Spacer(),
                      Text('${nextDate.day} ${_monthName(nextDate.month)} ${nextDate.year}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Start button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount')));
                      return;
                    }
                    try {
                      _pendingSIPAmount = amount;
                      _pendingSIPFrequency = frequency;
                      _pendingSIPDate = '${nextDate.year}-${nextDate.month.toString().padLeft(2, '0')}-${nextDate.day.toString().padLeft(2, '0')}';

                      final order = await ApiService.createPaymentOrder(amount);
                      Navigator.pop(ctx);

                      final options = {
                        'key': order['key_id'],
                        'amount': order['amount'],
                        'currency': order['currency'],
                        'name': 'StockPro SIP',
                        'description': 'First SIP installment - ${_fund?['name'] ?? ''}',
                        'order_id': order['order_id'],
                        'prefill': {'contact': '', 'email': ''},
                        'theme': {'color': '#F5A623'},
                      };
                      _razorpay.open(options);
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to start SIP. Please try again.')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.repeat, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        amountController.text.isNotEmpty && double.tryParse(amountController.text) != null
                            ? 'Start SIP • ₹${amountController.text}/${frequency == 'monthly' ? 'mo' : frequency == 'weekly' ? 'wk' : 'day'}'
                            : 'Start SIP',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _freqChip(String value, String label, IconData icon, String selected, Function(String) onTap) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppColors.primary : AppColors.textMuted, size: 16),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
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