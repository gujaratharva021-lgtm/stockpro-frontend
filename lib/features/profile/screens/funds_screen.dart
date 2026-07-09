import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class FundsScreen extends StatefulWidget {
  const FundsScreen({super.key});

  @override
  State<FundsScreen> createState() => _FundsScreenState();
}

class _FundsScreenState extends State<FundsScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  late Razorpay _razorpay;
  double _pendingAmount = 0;
  String _pendingOrderId = '';

  @override
  void initState() {
    super.initState();
    _load();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getMe();
      setState(() => _user = res['user']);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _balance => _user?['balance'] != null ? (_user!['balance'] as num).toDouble() : 0.0;

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    try {
      await ApiService.confirmPayment(
        response.orderId ?? _pendingOrderId,
        response.paymentId ?? '',
        response.signature ?? '',
        _pendingAmount,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('₹${_pendingAmount.toStringAsFixed(0)} added successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment received but balance update failed. Contact support.'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${response.message ?? 'Unknown error'}'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('External wallet selected: ${response.walletName}')),
      );
    }
  }

  Future<void> _startAddFunds(double amount) async {
    try {
      final order = await ApiService.createPaymentOrder(amount);
      _pendingAmount = amount;
      _pendingOrderId = order['order_id'];

      final options = {
        'key': order['key_id'],
        'amount': order['amount'],
        'currency': order['currency'],
        'name': 'StockPro',
        'description': 'Add funds to wallet',
        'order_id': order['order_id'],
        'prefill': {
          'contact': '',
          'email': _user?['email'] ?? '',
        },
        'theme': {'color': '#F5A623'},
      };

      _razorpay.open(options);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start payment. Please try again.'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showAddFundsDialog() {
    final amountController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: '₹ ', labelText: 'Amount', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Row(
              children: [100, 500, 1000, 5000].map((amt) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: OutlinedButton(
                      onPressed: () {
                        amountController.text = amt.toString();
                        setState(() {});
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('₹$amt', maxLines: 1, style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  final amt = double.tryParse(amountController.text);
                  if (amt == null || amt <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
                    return;
                  }
                  Navigator.pop(ctx);
                  _startAddFunds(amt);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Proceed to Pay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWithdrawDialog() {
    final amountController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Withdraw Funds', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text('Available balance: ₹${_balance.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(prefixText: '₹ ', labelText: 'Amount', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final amt = double.tryParse(amountController.text);
                  if (amt == null || amt <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
                    return;
                  }
                  if (amt > _balance) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Insufficient balance')));
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    await ApiService.withdrawFunds(amt);
                    await _load();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('₹${amt.toStringAsFixed(0)} withdrawn successfully'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Withdrawal failed'), backgroundColor: AppColors.danger),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                child: const Text('Withdraw', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Funds', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          const Text('Available margin (Cash + Collateral)', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          const SizedBox(height: 8),
                          Text('₹${_balance.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 30)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showAddFundsDialog,
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Add funds', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(vertical: 14)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showWithdrawDialog,
                            icon: const Icon(Icons.replay, color: Colors.white),
                            label: const Text('Withdraw', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Available cash', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(_balance.toStringAsFixed(2), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Used margin', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              const SizedBox(height: 4),
                              const Text('0.00', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32, color: AppColors.border),
                    _statRow('Opening balance', _balance.toStringAsFixed(2)),
                    _statRow('Payin', '0.00'),
                    _statRow('Payout', '0.00'),
                  ],
                ),
              ),
            ),
    );
  }
}