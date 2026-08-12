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

/// Full-screen order ticket matching the Kite-style Buy/Sell layout.
/// All calculation and order-placement logic is passed in from the caller
/// (stock_detail_screen.dart) so the real backend behaviour is unchanged.
/// Itemized real-world Indian equity charges (SEBI turnover fee, NSE
/// transaction charge, stamp duty, STT, GST, brokerage) for display purposes.
/// The backend does not deduct these separately from balance today — this is
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
  String _productTab = 'REGULAR'; // REGULAR | MTF | ICEBERG
  String _orderType = 'MARKET'; // MARKET | LIMIT
  String _product = 'DELIVERY'; // DELIVERY (Longterm) | INTRADAY
  String _validity = 'DAY'; // DAY | IOC
  bool _useSecondaryExchange = false;

  // Advanced order options: stoploss (a trigger price that fires a market/
  // limit sell once the price falls to protect against loss), GTT (Good
  // Till Triggered -- stays pending indefinitely until the target price
  // is hit, unlike a regular order which expires same-day), and Market
  // Protection (caps the worst price a MARKET order can fill at, so a
  // sudden price gap doesn't execute far away from the quoted price).
  bool _stoplossEnabled = false;
  bool _gttEnabled = false;
  bool _marketProtectionEnabled = false;
  late TextEditingController _stoplossController;
  late TextEditingController _gttTargetController;
  double _marketProtectionPercent = 3.0;

  late TextEditingController _qtyController;
  late TextEditingController _priceController;

  bool _showMore = false;
  bool _submitting = false;
  String? _errorMsg;
  double _swipeProgress = 0.0;
  double? _availableBalance;

  late TextEditingController _legsController;

  @override
  void initState() {
    super.initState();
    isBuy = widget.buySell == 'buy';
    _qtyController = TextEditingController(text: '1');
    _priceController = TextEditingController(text: widget.currentPrice.toStringAsFixed(2));
    _legsController = TextEditingController(text: '2');
    _stoplossController = TextEditingController();
    _gttTargetController = TextEditingController();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await ApiService.getBalance();
      if (mounted) setState(() => _availableBalance = balance);
    } catch (_) {
      // Balance is a nice-to-have display; silently ignore failures.
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _priceController.dispose();
    _legsController.dispose();
    
    _stoplossController.dispose();
    _gttTargetController.dispose();
    super.dispose();
  }

  int get _numberOfLegs {
    final legs = int.tryParse(_legsController.text) ?? 1;
    return legs < 1 ? 1 : legs;
  }

  double get _qtyPerLeg => _numberOfLegs == 0 ? 0 : _qty / _numberOfLegs;

  // NOTE: There is no live feed for the second exchange in this app.
  // This value is a display-only estimate so the BSE/NSE toggle has
  // something to show. Real order execution always uses widget.currentPrice
  // or the entered Limit price below — never this estimate.
  double get _secondaryExchangePrice => widget.currentPrice - 0.15;

  // Buy screens use the app's primary blue; Sell screens switch every
  // interactive accent (radios, tabs, steppers, swipe button) to red.
  Color get _accentColor => isBuy ? AppColors.primary : AppColors.danger;

  String get _primaryExchangeLabel => (widget.stock['exchange'] ?? 'NSE').toString();
  String get _secondaryExchangeLabel => _primaryExchangeLabel == 'BSE' ? 'NSE' : 'BSE';

  void _adjustQty(int delta) {
    final current = int.tryParse(_qtyController.text) ?? 1;
    final updated = (current + delta).clamp(1, 999999);
    setState(() => _qtyController.text = updated.toString());
  }

  void _adjustPrice(double delta) {
    final current = double.tryParse(_priceController.text) ?? widget.currentPrice;
    final updated = (current + delta).clamp(0.05, double.infinity);
    setState(() {
      _priceController.text = updated.toStringAsFixed(2);
      _orderType = 'LIMIT';
    });
  }

  double get _qty => double.tryParse(_qtyController.text) ?? 0;
  double get _price => _orderType == 'MARKET'
      ? widget.currentPrice
      : (double.tryParse(_priceController.text) ?? widget.currentPrice);
  double get _stockValue => _qty * _price;
  // Real, publicly documented Indian equity charge formulas (SEBI/NSE/GST
  // rates as published on exchange/broker charges pages). This is a genuine
  // itemized calculation, not a fabricated split of an arbitrary total.
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

  bool get _canSubmit => (_productTab == 'REGULAR' || (_productTab == 'MTF' && isBuy)) && !_submitting;

  double get _marginRequired => _stockValue * 0.20;

  Future<void> _handleSubmit() async {
    if (_submitting) return; // guard against duplicate rapid-fire submissions
    if (_productTab == 'ICEBERG') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Iceberg orders are coming soon')),
      );
      setState(() => _swipeProgress = 0.0);
      return;
    }
    if (_productTab == 'MTF' && !isBuy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('MTF is only available for buy orders. Close positions from Portfolio.')),
      );
      setState(() => _swipeProgress = 0.0);
      return;
    }
    if (_qty <= 0) {
      setState(() {
        _errorMsg = 'Enter a valid quantity';
        _swipeProgress = 0.0;
      });
      return;
    }
    if (_productTab == 'REGULAR' && _price <= 0) {
      setState(() {
        _errorMsg = 'Enter a valid price';
        _swipeProgress = 0.0;
      });
      return;
    }
    setState(() {
      _submitting = true;
      _errorMsg = null;
    });

    if (_productTab == 'MTF') {
      try {
        final symbol = (widget.stock['symbol'] ?? '').toString();
        await ApiService.mtfOpenPosition(widget.stock['id'], symbol, _qty);
        if (mounted) {
          Navigator.pop(context, {
            'buySell': widget.buySell,
            'qty': _qty,
            'orderType': 'MTF',
            'status': 'Executed',
            'orderId': null,
          });
        }
      } catch (e) {
        setState(() {
          _submitting = false;
          _swipeProgress = 0.0;
          _errorMsg = e.toString().contains('insufficient')
              ? 'Insufficient balance for margin'
              : 'MTF order failed: ' + (e is DioException ? (e.response?.data?.toString() ?? e.toString()) : e.toString());
        });
      }
      return;
    }

    try {
      final submitResult = await widget.onSubmit(orderType: _orderType, qty: _qty, price: _price, marketProtectionPercent: (_orderType == 'MARKET' && _marketProtectionEnabled) ? _marketProtectionPercent : null, productType: _product == 'INTRADAY' ? 'INTRADAY' : 'REGULAR');
      // If the user enabled Stoploss and/or GTT alongside a Regular order,
      // place them as separate pending orders once the main order succeeds
      // -- these are protective/target orders that trigger independently,
      // not part of the immediate buy/sell itself.
      if (_productTab == 'REGULAR') {
        if (_stoplossEnabled) {
          final slPrice = double.tryParse(_stoplossController.text);
          if (slPrice != null && slPrice > 0) {
            try {
              await ApiService.createPendingOrder(
                widget.stock['id'],
                'SELL',
                'STOP_LOSS',
                _qty,
                slPrice,
              );
            } catch (_) {
              // Main order already succeeded -- surface a soft warning
              // rather than treating the whole submission as failed.
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
              await ApiService.createPendingOrder(
                widget.stock['id'],
                widget.buySell.toUpperCase(),
                'LIMIT',
                _qty,
                gttPrice,
                isGtt: true,
              );
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Order placed, but GTT could not be set. Add it from Orders.')),
                );
              }
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
        _swipeProgress = 0.0;
        _errorMsg = e.toString().contains('insufficient shares')
            ? 'You don\'t have enough shares to sell'
            : e.toString().contains('insufficient')
                ? 'Insufficient balance'
                : 'Order failed: ' + (e is DioException ? (e.response?.data?.toString() ?? e.toString()) : e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbol = widget.stock['symbol'] ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Text(symbol,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 18)),
        actions: [IconButton(icon: const Icon(Icons.more_vert), onPressed: () {})],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: AppColors.cardBackground,
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isBuy ? AppColors.success : AppColors.danger).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(isBuy ? 'BUY' : 'SELL',
                    style: TextStyle(
                        color: isBuy ? AppColors.success : AppColors.danger,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Text('${widget.changePercent >= 0 ? '+' : ''}${widget.changePercent.toStringAsFixed(2)}%',
                  style: TextStyle(
                      color: widget.changePercent >= 0 ? AppColors.success : AppColors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          Container(
            color: AppColors.cardBackground,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              Expanded(
                child: _exchangeTile(
                  label: _primaryExchangeLabel,
                  price: widget.currentPrice,
                  selected: !_useSecondaryExchange,
                  onTap: () => setState(() => _useSecondaryExchange = false),
                ),
              ),
              Expanded(
                child: _exchangeTile(
                  label: _secondaryExchangeLabel,
                  price: _secondaryExchangePrice,
                  selected: _useSecondaryExchange,
                  onTap: () => setState(() => _useSecondaryExchange = true),
                ),
              ),
            ]),
          ),
          Container(
            color: AppColors.cardBackground,
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: Row(children: [
              _productTabWidget('Regular', 'REGULAR'),
              const SizedBox(width: 24),
              _productTabWidget('MTF', 'MTF'),
              const SizedBox(width: 24),
              _productTabWidget('Iceberg', 'ICEBERG'),
            ]),
          ),
          if (_productTab == 'ICEBERG' || (_productTab == 'MTF' && !isBuy))
            Container(
              width: double.infinity,
              color: AppColors.primary.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _productTab == 'ICEBERG'
                    ? 'Iceberg orders are coming soon. Switch to Regular to place an order.'
                    : 'MTF is only available for buy orders. Close positions from your Portfolio.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          if (_productTab == 'MTF' && isBuy)
            Container(
              width: double.infinity,
              color: AppColors.success.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const Text(
                'You pay 20% margin upfront. The rest is funded by the broker at 18% p.a. interest.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isBuy && widget.holdingQty > 0) ...[
                    Text(
                        'Holding: ${widget.holdingQty.toStringAsFixed(0)} Shares • Avg ₹${widget.avgBuyPrice.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 16),
                  ],
                  const Text('Quantity',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  _stepperField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    onIncrement: () => _adjustQty(1),
                    onDecrement: () => _adjustQty(-1),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    const Text('Limit',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _priceController.text = widget.currentPrice.toStringAsFixed(2)),
                      child: Icon(Icons.colorize, size: 16, color: _accentColor),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _stepperField(
                    controller: _priceController,
                    enabled: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                    onIncrement: () => _adjustPrice(0.05),
                    onDecrement: () => _adjustPrice(-0.05),
                    onChanged: (_) {
                      if (_orderType != 'LIMIT') {
                        setState(() => _orderType = 'LIMIT');
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_productTab == 'REGULAR') ...[
                    _advancedOrderOptions(),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 16),
                  if (_productTab == 'ICEBERG') ...[
                    _icebergLegsSection(),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(10)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      _radioOption('Intraday', _product == 'INTRADAY', () => setState(() => _product = 'INTRADAY')),
                      _radioOption('Longterm', _product == 'DELIVERY', () => setState(() => _product = 'DELIVERY')),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () => setState(() => _showMore = !_showMore),
                      child: Column(children: [
                        const Text('More', style: TextStyle(color: AppColors.textPrimary)),
                        Icon(_showMore ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: AppColors.textMuted),
                      ]),
                    ),
                  ),
                  if (_showMore) ...[
                    const SizedBox(height: 16),
                    _moreSection(),
                  ],
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorMsg!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
          _bottomBar(),
        ],
      ),
    );
  }

  Widget _exchangeTile(
      {required String label, required double price, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Radio<bool>(
              value: true,
              groupValue: selected, // ignore: deprecated_member_use
              onChanged: (_) => onTap(), // ignore: deprecated_member_use
              activeColor: _accentColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
          Text(label,
              style: TextStyle(
                  color: selected ? AppColors.textPrimary : AppColors.textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          Text('₹${price.toStringAsFixed(2)}',
              style: TextStyle(
                  color: selected ? AppColors.textPrimary : AppColors.textMuted, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  void _handleProductTabTap(String tab) {
    if (tab == 'MTF') {
      _showMtfInfoDialog();
    } else {
      setState(() => _productTab = tab);
    }
  }

  void _showMtfInfoDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Margin Trading Facility (MTF)'),
        content: Text(
          'MTF lets you buy shares by paying only 20% of the total cost upfront. '
          'The remaining 80% is funded by the broker, and interest (18% p.a.) is '
          'charged on that borrowed amount until you close the position.'
          '${isBuy ? '' : '\n\nMTF is only available for buy orders. Existing positions are closed from your Portfolio.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() => _productTab = 'MTF');
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _productTabWidget(String label, String tab) {
    final selected = _productTab == tab;
    return GestureDetector(
      onTap: () => _handleProductTabTap(tab),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(
                color: selected ? _accentColor : AppColors.textMuted,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 15)),
        const SizedBox(height: 6),
        Container(height: 2, width: 40, color: selected ? _accentColor : Colors.transparent),
      ]),
    );
  }

  Widget _stepperField({
    required TextEditingController controller,
    required TextInputType keyboardType,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    bool enabled = true,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            onChanged: (v) {
              setState(() {});
              onChanged?.call(v);
            },
            style: const TextStyle(fontSize: 20, color: AppColors.textPrimary),
            decoration: const InputDecoration(
                border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
          ),
        ),
        Container(width: 1, height: 44, color: AppColors.border),
        Column(mainAxisSize: MainAxisSize.min, children: [
          InkWell(
              onTap: enabled ? onIncrement : null,
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Icon(Icons.arrow_forward, size: 18, color: enabled ? _accentColor : AppColors.textMuted))),
          InkWell(
              onTap: enabled ? onDecrement : null,
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Icon(Icons.arrow_back, size: 18, color: enabled ? _accentColor : AppColors.textMuted))),
        ]),
      ]),
    );
  }

  Widget _radioOption(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Radio<bool>(
            value: true,
            groupValue: selected, // ignore: deprecated_member_use
            onChanged: (_) => onTap(), // ignore: deprecated_member_use
            activeColor: _accentColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        Text(label,
            style: TextStyle(
                color: selected ? AppColors.textPrimary : AppColors.textMuted, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _moreSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Order Type', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: _chipOption(
                  'Market',
                  _orderType == 'MARKET',
                  () => setState(() {
                        _orderType = 'MARKET';
                        _priceController.text = widget.currentPrice.toStringAsFixed(2);
                      }))),
          const SizedBox(width: 10),
          Expanded(child: _chipOption('Limit', _orderType == 'LIMIT', () => setState(() => _orderType = 'LIMIT'))),
        ]),
        const SizedBox(height: 14),
        const Text('Validity', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _chipOption('Day', _validity == 'DAY', () => setState(() => _validity = 'DAY'))),
          const SizedBox(width: 10),
          Expanded(child: _chipOption('IOC', _validity == 'IOC', () => setState(() => _validity = 'IOC'))),
        ]),
      ]),
    );
  }

  Widget _chipOption(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _accentColor.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(color: selected ? _accentColor : AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style:
                TextStyle(color: selected ? _accentColor : AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  Widget _icebergLegsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Number of legs',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Iceberg orders'),
                      content: const Text(
                          'An iceberg order splits your total quantity into smaller, equal-sized legs so the full order size isn\'t visible in the market depth at once.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
                      ],
                    ),
                  );
                },
                child: Icon(Icons.info_outline, size: 18, color: _accentColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
            child: TextField(
              controller: _legsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 20, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                  border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
            ),
          ),
          const SizedBox(height: 6),
          Text('${_qtyPerLeg.toStringAsFixed(_qtyPerLeg == _qtyPerLeg.roundToDouble() ? 0 : 2)} qty. per leg',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
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
          Text(label,
              style: TextStyle(
                  color: bold ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text('₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: AppColors.background, border: Border(top: BorderSide(color: AppColors.border))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: RichText(
                text: TextSpan(style: const TextStyle(fontSize: 13, color: AppColors.textMuted), children: [
                  const TextSpan(text: 'Amount  '),
                  TextSpan(
                      text: '₹${_stockValue.toStringAsFixed(2)}',
                      style: TextStyle(color: _accentColor, fontWeight: FontWeight.w600)),
                  const TextSpan(text: '  +  '),
                  TextSpan(
                      text: '₹${(_brokerage + _taxes).toStringAsFixed(2)}',
                      style: TextStyle(color: _accentColor, fontWeight: FontWeight.w600)),
                  const TextSpan(text: '   Avail.  '),
                  TextSpan(
                      text: _availableBalance == null ? '…' : '₹${_availableBalance!.toStringAsFixed(2)}',
                      style: TextStyle(color: _accentColor, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            GestureDetector(
              onTap: _showChargesDialog,
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text(_productTab == 'MTF' ? 'Margin Required (20%)' : (isBuy ? 'Total Payable' : 'Net Receivable'),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const Spacer(),
            Text('₹${(_productTab == 'MTF' ? _marginRequired : _total).toStringAsFixed(2)}',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          _swipeButton(),
        ]),
      ),
    );
  }

  Widget _swipeButton() {
    final label = isBuy ? 'SWIPE TO BUY' : 'SWIPE TO SELL';
    final color = _accentColor;
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      const thumbSize = 48.0;
      final maxDrag = width - thumbSize - 4;
      return Container(
        height: 56,
        decoration: BoxDecoration(color: _canSubmit ? color : AppColors.border, borderRadius: BorderRadius.circular(28)),
        child: Stack(alignment: Alignment.center, children: [
          Center(
              child: Text(label,
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, letterSpacing: 1.2))),
          AnimatedPositioned(
            duration: _submitting ? Duration.zero : const Duration(milliseconds: 150),
            left: 2 + (_swipeProgress * maxDrag),
            top: 4,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (_submitting) return;
                setState(() {
                  _swipeProgress = (_swipeProgress + details.delta.dx / maxDrag).clamp(0.0, 1.0);
                });
              },
              onHorizontalDragEnd: (details) {
                if (_submitting) return;
                if (_swipeProgress > 0.85) {
                  setState(() => _swipeProgress = 1.0);
                  _handleSubmit();
                } else {
                  setState(() => _swipeProgress = 0.0);
                }
              },
              child: Container(
                width: thumbSize,
                height: thumbSize,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: _submitting
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(color)))
                    : Icon(Icons.chevron_right, color: color),
              ),
            ),
          ),
        ]),
      );
    });
  }

  Widget _advancedOrderOptions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Advanced Options', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          _advancedOptionRow(
            label: 'Stoploss',
            subtitle: 'Auto-sell if price falls to protect against loss',
            value: _stoplossEnabled,
            onChanged: (v) => setState(() => _stoplossEnabled = v),
          ),
          if (_stoplossEnabled) ...[
            const SizedBox(height: 8),
            _stepperField(
              controller: _stoplossController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\\d*\\.?\\d{0,2}'))],
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
            _stepperField(
              controller: _gttTargetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\\d*\\.?\\d{0,2}'))],
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

  Widget _advancedOptionRow({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
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
}
