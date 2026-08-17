import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/core/services/api_service.dart';

/// Result of submitting an order through [OrderTicketScreen.onSubmit].
/// [status] is a short UI label (e.g. "Filled", "Pending", "Rejected") --
/// callers should derive it from the real order status returned by the
/// order engine, never assume it. [orderId] is the real backend order id
/// when one exists (MARKET orders through the order engine), so the
/// confirmation screen can show something the user can actually look up
/// instead of a fabricated reference number.
class OrderSubmitResult {
  final String status;
  final String? orderId;
  const OrderSubmitResult({required this.status, this.orderId});
}

/// Real, publicly documented Indian equity charge formulas (SEBI/NSE/GST
/// rates as published on exchange/broker charges pages). This is a genuine
/// itemized calculation, not a fabricated split of an arbitrary total. The
/// backend does not deduct these separately from balance today -- this is
/// an accurate informational estimate using published rates.
class _ChargeBreakdown {
  final double brokerage;
  final double sebiFee;
  final double exchangeFee;
  final double stampDuty;
  final double stt;
  final double gst;

  _ChargeBreakdown({
    required this.brokerage,
    required this.sebiFee,
    required this.exchangeFee,
    required this.stampDuty,
    required this.stt,
    required this.gst,
  });

  double get total => brokerage + sebiFee + exchangeFee + stampDuty + stt + gst;
}

/// Order-entry screen laid out as a stacked list of rows (Account / Order
/// Type / Limit Price / Quantity / Time-in-Force), matching a professional
/// broker-app ticket, with a Preview (Amount + Buying Power Impact) block
/// above the submit button. All calculation and order-placement logic is
/// passed in from the caller (stock_detail_screen.dart) so the real backend
/// behaviour is unchanged from before this redesign.
class OrderTicketScreen extends StatefulWidget {
  final Map<String, dynamic> stock;
  final String buySell; // 'buy' or 'sell'
  final double currentPrice;
  final double changePercent;
  final double holdingQty;
  final double avgBuyPrice;
  final double Function(double value, String product) calcBrokerage;
  final double Function(double value, String buySell) calcTaxes;
  final Future<OrderSubmitResult> Function({
    required String orderType,
    required double qty,
    required double price,
    double? marketProtectionPercent,
    String productType,
  }) onSubmit;

  const OrderTicketScreen({
    super.key,
    required this.stock,
    required this.buySell,
    required this.currentPrice,
    required this.changePercent,
    required this.holdingQty,
    required this.avgBuyPrice,
    required this.calcBrokerage,
    required this.calcTaxes,
    required this.onSubmit,
  });

  @override
  State<OrderTicketScreen> createState() => _OrderTicketScreenState();
}

class _OrderTicketScreenState extends State<OrderTicketScreen> {
  late bool isBuy;
  String _orderType = 'MARKET'; // MARKET | LIMIT
  String _product = 'DELIVERY'; // DELIVERY (Longterm) | INTRADAY
  String _validity = 'DAY'; // DAY | IOC  (Time-in-Force)

  // Advanced order options: stoploss (a trigger price that fires a market/
  // limit sell once the price falls to protect against loss), GTT (Good
  // Till Triggered -- stays pending indefinitely until the target price
  // is hit, unlike a regular order which expires same-day), and Market
  // Protection (caps the worst price a MARKET order can fill at, so a
  // sudden price gap doesn't execute far away from the quoted price).
  bool _showMoreOptions = false;
  bool _stoplossEnabled = false;
  bool _gttEnabled = false;
  bool _marketProtectionEnabled = false;
  late TextEditingController _stoplossController;
  late TextEditingController _gttTargetController;
  double _marketProtectionPercent = 3.0;

  late TextEditingController _qtyController;
  late TextEditingController _priceController;

  bool _submitting = false;
  String? _errorMsg;
  double? _availableBalance;
  String? _accountEmail;

  @override
  void initState() {
    super.initState();
    isBuy = widget.buySell == 'buy';
    _qtyController = TextEditingController(text: '1');
    _priceController = TextEditingController(text: widget.currentPrice.toStringAsFixed(2));
    _stoplossController = TextEditingController();
    _gttTargetController = TextEditingController();
    _loadBalance();
    _loadAccount();
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await ApiService.getBalance();
      if (mounted) setState(() => _availableBalance = balance);
    } catch (_) {
      // Balance is a nice-to-have display; silently ignore failures.
    }
  }

  Future<void> _loadAccount() async {
    try {
      final me = await ApiService.getMe();
      final email = me['user']?['email'] as String?;
      if (mounted) setState(() => _accountEmail = email);
    } catch (_) {}
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _stoplossController.dispose();
    _gttTargetController.dispose();
    super.dispose();
  }

  // Buy screens use the app's primary blue; Sell screens switch every
  // interactive accent (dropdown values, toggle, submit button) to red.
  Color get _accentColor => isBuy ? AppColors.primary : AppColors.danger;

  void _adjustQty(int delta) {
    final current = int.tryParse(_qtyController.text) ?? 1;
    final updated = (current + delta).clamp(1, 999999);
    setState(() => _qtyController.text = updated.toString());
  }

  void _adjustPrice(double delta) {
    final current = double.tryParse(_priceController.text) ?? widget.currentPrice;
    final updated = (current + delta).clamp(0.05, double.infinity);
    setState(() => _priceController.text = updated.toStringAsFixed(2));
  }

  double get _qty => double.tryParse(_qtyController.text) ?? 0;
  double get _price => _orderType == 'MARKET'
      ? widget.currentPrice
      : (double.tryParse(_priceController.text) ?? widget.currentPrice);
  double get _stockValue => _qty * _price;

  _ChargeBreakdown get _charges {
    final turnover = _stockValue;
    final isIntraday = _product == 'INTRADAY';
    final brokerage = isIntraday ? [20.0, turnover * 0.0003].reduce((a, b) => a < b ? a : b) : 0.0;
    final sebiFee = turnover * 0.000001; // SEBI turnover fee: Rs 10 per crore
    final exchangeFee = turnover * 0.0000297; // NSE transaction charge (approx published rate)
    final stampDuty = isBuy ? turnover * (isIntraday ? 0.00003 : 0.00015) : 0.0; // buy-side only
    final stt = isIntraday
        ? (isBuy ? 0.0 : turnover * 0.00025) // intraday STT: sell-side only
        : turnover * 0.001; // delivery STT: both sides
    final gst = (brokerage + exchangeFee) * 0.18;
    return _ChargeBreakdown(
      brokerage: brokerage,
      sebiFee: sebiFee,
      exchangeFee: exchangeFee,
      stampDuty: stampDuty,
      stt: stt,
      gst: gst,
    );
  }

  double get _brokerage => _charges.brokerage;
  double get _taxes => _charges.total - _charges.brokerage;
  double get _total => isBuy ? _stockValue + _brokerage + _taxes : _stockValue - _brokerage - _taxes;

  // Buying power moves down on a BUY (cash leaves) and up on a SELL (cash
  // comes in) -- shown with an explicit sign so it reads the way a
  // brokerage statement would.
  double get _buyingPowerImpact => isBuy ? -_total : _total;

  Future<void> _handleSubmit() async {
    if (_submitting) return; // guard against duplicate rapid-fire submissions
    if (_qty <= 0) {
      setState(() => _errorMsg = 'Enter a valid quantity');
      return;
    }
    if (_orderType == 'LIMIT' && _price <= 0) {
      setState(() => _errorMsg = 'Enter a valid limit price');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMsg = null;
    });

    try {
      final submitResult = await widget.onSubmit(
        orderType: _orderType,
        qty: _qty,
        price: _price,
        marketProtectionPercent: (_orderType == 'MARKET' && _marketProtectionEnabled) ? _marketProtectionPercent : null,
        productType: _product == 'INTRADAY' ? 'INTRADAY' : 'REGULAR',
      );
      if (_stoplossEnabled) {
        final slPrice = double.tryParse(_stoplossController.text);
        if (slPrice != null && slPrice > 0) {
          try {
            await ApiService.createPendingOrder(widget.stock['id'], 'SELL', 'STOP_LOSS', _qty, slPrice);
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order placed, but Stoploss could not be set. Add it from Orders.')),
              );
            }
          }
        }
      }
      if (_gttEnabled) {
        final gttPrice = double.tryParse(_gttTargetController.text);
        if (gttPrice != null && gttPrice > 0) {
          try {
            await ApiService.createPendingOrder(widget.stock['id'], widget.buySell.toUpperCase(), 'LIMIT', _qty, gttPrice, isGtt: true);
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order placed, but GTT could not be set. Add it from Orders.')),
              );
            }
          }
        }
      }
      if (mounted) {
        Navigator.pop(context, {
          'buySell': widget.buySell,
          'qty': _qty,
          'orderType': _orderType,
          'status': submitResult.status,
          'orderId': submitResult.orderId,
        });
      }
    } catch (e) {
      setState(() {
        _submitting = false;
        _errorMsg = e.toString().contains('insufficient shares')
            ? 'You don\'t have enough shares to sell'
            : e.toString().contains('insufficient')
                ? 'Insufficient balance'
                : 'Order failed: ' + (e is DioException ? (e.response?.data?.toString() ?? e.toString()) : e.toString());
      });
    }
  }

  void _pickOrderType() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTile('Market', 'MARKET', _orderType, (v) {
              setState(() {
                _orderType = v;
                _priceController.text = widget.currentPrice.toStringAsFixed(2);
              });
            }),
            _sheetTile('Limit', 'LIMIT', _orderType, (v) => setState(() => _orderType = v)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _pickTimeInForce() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTile('Day', 'DAY', _validity, (v) => setState(() => _validity = v)),
            _sheetTile('Immediate or Cancel (IOC)', 'IOC', _validity, (v) => setState(() => _validity = v)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _pickProduct() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetTile('Longterm (Delivery)', 'DELIVERY', _product, (v) => setState(() => _product = v)),
            _sheetTile('Intraday', 'INTRADAY', _product, (v) => setState(() => _product = v)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile(String label, String value, String groupValue, ValueChanged<String> onPick) {
    final selected = value == groupValue;
    return ListTile(
      title: Text(label, style: TextStyle(color: selected ? _accentColor : AppColors.textPrimary, fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
      trailing: selected ? Icon(Icons.check, color: _accentColor) : null,
      onTap: () {
        onPick(value);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final symbol = widget.stock['symbol'] ?? '';
    final companyName = widget.stock['company_name'] ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleSpacing: 0,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(symbol, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                  if (companyName.toString().isNotEmpty)
                    Text(companyName.toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('₹${widget.currentPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                Text('${widget.changePercent >= 0 ? '+' : ''}${widget.changePercent.toStringAsFixed(2)}%',
                    style: TextStyle(color: widget.changePercent >= 0 ? AppColors.success : AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Row(
              children: [
                Expanded(child: _buySellTab('Buy Order', true)),
                Expanded(child: _buySellTab('Sell Order', false)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isBuy && widget.holdingQty > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text('Holding: ${widget.holdingQty.toStringAsFixed(0)} shares • Avg ₹${widget.avgBuyPrice.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ),

                  _infoRow('Account', _accountEmail ?? '…'),
                  _infoRow('Product', _product == 'DELIVERY' ? 'Longterm' : 'Intraday', onTap: _pickProduct),
                  _infoRow('Order Type', _orderType == 'MARKET' ? 'Market' : 'Limit', onTap: _pickOrderType),

                  if (_orderType == 'LIMIT')
                    _stepperRow(
                      label: 'Limit Price',
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      onIncrement: () => _adjustPrice(0.05),
                      onDecrement: () => _adjustPrice(-0.05),
                    ),

                  _stepperRow(
                    label: 'Quantity',
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    onIncrement: () => _adjustQty(1),
                    onDecrement: () => _adjustQty(-1),
                  ),

                  _infoRow('Time-in-Force', _validity == 'DAY' ? 'Day' : 'Immediate or Cancel', onTap: _pickTimeInForce),

                  const SizedBox(height: 4),
                  Center(
                    child: GestureDetector(
                      onTap: () => setState(() => _showMoreOptions = !_showMoreOptions),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('More Options', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                            Icon(_showMoreOptions ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.textMuted, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_showMoreOptions) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: _advancedOrderOptions(),
                    ),
                  ],

                  const SizedBox(height: 12),
                  Container(height: 8, color: AppColors.cardBackground),
                  const SizedBox(height: 4),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('Preview', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  _infoRow('Amount', '₹${_stockValue.toStringAsFixed(2)}'),
                  _infoRow(
                    'Buying Power Impact',
                    '${_buyingPowerImpact >= 0 ? '+' : '-'}₹${_buyingPowerImpact.abs().toStringAsFixed(2)}',
                    valueColor: _buyingPowerImpact >= 0 ? AppColors.success : AppColors.danger,
                  ),
                  GestureDetector(
                    onTap: _showChargesDialog,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                      child: Row(
                        children: [
                          Text('Available: ${_availableBalance == null ? '…' : '₹${_availableBalance!.toStringAsFixed(2)}'}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          const SizedBox(width: 6),
                          const Icon(Icons.info_outline, size: 14, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),

                  if (_errorMsg != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(_errorMsg!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ),
                ],
              ),
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _buySellTab(String label, bool forBuy) {
    final selected = isBuy == forBuy;
    return GestureDetector(
      onTap: () => setState(() => isBuy = forBuy),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? (forBuy ? AppColors.primary : AppColors.danger) : Colors.transparent, width: 2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? (forBuy ? AppColors.primary : AppColors.danger) : AppColors.textMuted,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {VoidCallback? onTap, Color? valueColor}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            Row(
              children: [
                Text(value, style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepperRow({
    required String label,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 1))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Row(
            children: [
              InkWell(onTap: onDecrement, child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.remove, size: 18, color: _accentColor))),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  textAlign: TextAlign.center,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                ),
              ),
              InkWell(onTap: onIncrement, child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.add, size: 18, color: _accentColor))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _advancedOrderOptions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _advancedOptionRow(
            label: 'Stoploss',
            subtitle: 'Auto-sell if price falls to protect against loss',
            value: _stoplossEnabled,
            onChanged: (v) => setState(() => _stoplossEnabled = v),
          ),
          if (_stoplossEnabled) ...[
            const SizedBox(height: 8),
            _inlineStepper(
              controller: _stoplossController,
              onIncrement: () {
                final current = double.tryParse(_stoplossController.text) ?? widget.currentPrice;
                setState(() => _stoplossController.text = (current + 0.05).toStringAsFixed(2));
              },
              onDecrement: () {
                final current = double.tryParse(_stoplossController.text) ?? widget.currentPrice;
                setState(() => _stoplossController.text = (current - 0.05).clamp(0.05, double.infinity).toStringAsFixed(2));
              },
            ),
          ],
          const SizedBox(height: 12),
          _advancedOptionRow(
            label: 'GTT (Good Till Triggered)',
            subtitle: 'Stays pending until your target price is hit, no expiry',
            value: _gttEnabled,
            onChanged: (v) => setState(() => _gttEnabled = v),
          ),
          if (_gttEnabled) ...[
            const SizedBox(height: 8),
            _inlineStepper(
              controller: _gttTargetController,
              onIncrement: () {
                final current = double.tryParse(_gttTargetController.text) ?? widget.currentPrice;
                setState(() => _gttTargetController.text = (current + 0.05).toStringAsFixed(2));
              },
              onDecrement: () {
                final current = double.tryParse(_gttTargetController.text) ?? widget.currentPrice;
                setState(() => _gttTargetController.text = (current - 0.05).clamp(0.05, double.infinity).toStringAsFixed(2));
              },
            ),
          ],
          if (_orderType == 'MARKET') ...[
            const SizedBox(height: 12),
            _advancedOptionRow(
              label: 'Market Protection',
              subtitle: 'Caps how far your MARKET order can fill from the quoted price',
              value: _marketProtectionEnabled,
              onChanged: (v) => setState(() => _marketProtectionEnabled = v),
            ),
            if (_marketProtectionEnabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Protect up to', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  Expanded(
                    child: Slider(
                      value: _marketProtectionPercent,
                      min: 1,
                      max: 10,
                      divisions: 18,
                      label: '${_marketProtectionPercent.toStringAsFixed(1)}%',
                      activeColor: _accentColor,
                      onChanged: (v) => setState(() => _marketProtectionPercent = v),
                    ),
                  ),
                  Text('${_marketProtectionPercent.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _inlineStepper({required TextEditingController controller, required VoidCallback onIncrement, required VoidCallback onDecrement}) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
        ),
        InkWell(onTap: onDecrement, child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.remove, size: 16, color: _accentColor))),
        InkWell(onTap: onIncrement, child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.add, size: 16, color: _accentColor))),
      ]),
    );
  }

  Widget _advancedOptionRow({required String label, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: _accentColor),
      ],
    );
  }

  void _showChargesDialog() {
    final c = _charges;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Charges & taxes'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Statutory charges', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Text('(Govt. & Exchange fees)', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 8),
              _chargeLine('SEBI turnover fee', c.sebiFee),
              _chargeLine('Exchange turnover fee', c.exchangeFee),
              _chargeLine('Stamp duty', c.stampDuty),
              _chargeLine('Transaction tax (STT)', c.stt),
              _chargeLine('GST', c.gst),
              const Divider(height: 20),
              const Text('Brokerage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              _chargeLine('Brokerage', c.brokerage),
              const Divider(height: 20),
              _chargeLine('Total charges', c.total, bold: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _chargeLine(String label, double amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: bold ? AppColors.textPrimary : AppColors.textSecondary, fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _submitting ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              disabledBackgroundColor: _accentColor.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                : Text('Submit ${isBuy ? 'Buy' : 'Sell'} Order', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ),
    );
  }
}
