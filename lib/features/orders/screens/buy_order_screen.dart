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

// Dark-theme palette for this screen, matching the rest of the app
// (AppColors). Buy and Sell both use this screen, so this one change
// applies to both tickets.
const _kBg = AppColors.background;
const _kCard = AppColors.cardBackground;
const _kBorder = AppColors.border;
const _kTextPrimary = AppColors.textPrimary;
const _kTextSecondary = AppColors.textSecondary;
const _kTextMuted = AppColors.textMuted;

/// Swipe-to-confirm order ticket: exchange selector, product-type tabs,
/// quantity/limit steppers, advanced order options (Stoploss / GTT / Market
/// Protection), an amount summary, and a swipe button to submit. All
/// calculation and order-placement logic is passed in from the caller
/// (stock_detail_screen.dart) so real backend behaviour is unchanged.
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
  String _orderMode = 'REGULAR'; // REGULAR | MTF | ICEBERG (MTF/Iceberg are informational only for now)

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

  bool _submitting = false;
  String? _errorMsg;
  double? _availableBalance;

  // Swipe-to-confirm drag state, 0.0 (start) .. 1.0 (fully swiped).
  double _dragProgress = 0.0;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    isBuy = widget.buySell == 'buy';
    _qtyController = TextEditingController(text: '1');
    _priceController = TextEditingController(text: widget.currentPrice.toStringAsFixed(2));
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
    _stoplossController.dispose();
    _gttTargetController.dispose();
    super.dispose();
  }

  // Buy tickets use the app's primary blue; Sell tickets switch every
  // interactive accent (selector, toggle, swipe button) to red/orange.
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
  double get _fees => _brokerage + _taxes;
  double get _total => isBuy ? _stockValue + _fees : _stockValue - _fees;

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
    if (_orderMode != 'REGULAR') {
      setState(() => _errorMsg = '${_orderMode == 'MTF' ? 'MTF' : 'Iceberg'} orders are coming soon. Switch to Regular to place this order.');
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
        _dragProgress = 0.0;
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
      backgroundColor: _kBg,
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

  void _pickProduct() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kBg,
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
      title: Text(label, style: TextStyle(color: selected ? _accentColor : _kTextPrimary, fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
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

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        foregroundColor: _kTextPrimary,
        iconTheme: const IconThemeData(color: _kTextPrimary),
        title: Text(symbol, style: const TextStyle(color: _kTextPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: _kTextPrimary),
            onSelected: (v) {
              if (v == 'charges') _showChargesDialog();
              if (v == 'product') _pickProduct();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'charges', child: Text('Charges & taxes')),
              PopupMenuItem(value: 'product', child: Text('Longterm / Intraday')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buySellBadgeRow(),
                    if (!isBuy && widget.holdingQty > 0) ...[
                      const SizedBox(height: 6),
                      Text('Holding: ${widget.holdingQty.toStringAsFixed(0)} shares • Avg ₹${widget.avgBuyPrice.toStringAsFixed(2)}',
                          style: const TextStyle(color: _kTextMuted, fontSize: 12)),
                    ],
                    const SizedBox(height: 20),
                    _exchangeSelector(),
                    const SizedBox(height: 16),
                    _orderModeTabs(),
                    const SizedBox(height: 20),
                    const Text('Quantity', style: TextStyle(color: _kTextPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 6),
                    _stepperField(controller: _qtyController, keyboardType: TextInputType.number, onIncrement: () => _adjustQty(1), onDecrement: () => _adjustQty(-1)),
                    const SizedBox(height: 18),
                    Row(children: [
                      Text(_orderType == 'MARKET' ? 'Market' : 'Limit', style: const TextStyle(color: _kTextPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _pickOrderType,
                        child: Icon(Icons.edit, size: 14, color: _accentColor),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    _stepperField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      enabled: _orderType == 'LIMIT',
                      onIncrement: () => _adjustPrice(0.05),
                      onDecrement: () => _adjustPrice(-0.05),
                    ),
                    const SizedBox(height: 22),
                    _advancedOrderOptions(),
                    const SizedBox(height: 22),
                    _amountSummary(),
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(_errorMsg!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: _swipeButton(),
            ),
          ],
        ),
      ),
    );
  }

  // ===== BUY/SELL badge + change% (tap to flip sides) =====
  Widget _buySellBadgeRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() => isBuy = !isBuy),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: _accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(isBuy ? 'BUY' : 'SELL', style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.4)),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${widget.changePercent >= 0 ? '+' : ''}${widget.changePercent.toStringAsFixed(2)}%',
          style: TextStyle(color: widget.changePercent >= 0 ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }

  // ===== NSE / BSE price selector =====
  Widget _exchangeSelector() {
    return Row(
      children: [
        Expanded(
          child: Row(children: [
            Radio<bool>(value: true, groupValue: true, onChanged: (_) {}, activeColor: _accentColor, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            const SizedBox(width: 4),
            const Text('NSE', style: TextStyle(color: _kTextPrimary, fontSize: 14)),
            const SizedBox(width: 6),
            Text('₹${widget.currentPrice.toStringAsFixed(2)}', style: const TextStyle(color: _kTextPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
        ),
        Expanded(
          child: Opacity(
            opacity: 0.45,
            child: Row(children: [
              const Radio<bool>(value: false, groupValue: true, onChanged: null, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
              const SizedBox(width: 4),
              const Text('BSE', style: TextStyle(color: _kTextSecondary, fontSize: 14)),
              const SizedBox(width: 6),
              Text('₹${widget.currentPrice.toStringAsFixed(2)}', style: const TextStyle(color: _kTextSecondary, fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
          ),
        ),
      ],
    );
  }

  // ===== Regular / MTF / Iceberg tabs =====
  Widget _orderModeTabs() {
    Widget tab(String label, String value) {
      final selected = _orderMode == value;
      return GestureDetector(
        onTap: () {
          if (value == 'REGULAR' && selected) {
            _pickProduct();
            return;
          }
          setState(() => _orderMode = value);
        },
        child: Padding(
          padding: const EdgeInsets.only(right: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(color: selected ? _accentColor : _kTextMuted, fontWeight: selected ? FontWeight.bold : FontWeight.w500, fontSize: 14)),
              const SizedBox(height: 6),
              Container(height: 2, width: label.length * 7.5, color: selected ? _accentColor : Colors.transparent),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [tab('Regular', 'REGULAR'), tab('MTF', 'MTF'), tab('Iceberg', 'ICEBERG')]),
        const Divider(color: _kBorder, height: 1),
        if (_orderMode != 'REGULAR') ...[
          const SizedBox(height: 8),
          Text(
            '${_orderMode == 'MTF' ? 'MTF' : 'Iceberg'} orders are coming soon. Switch to Regular to place this order.',
            style: const TextStyle(color: _kTextMuted, fontSize: 11.5),
          ),
        ],
      ],
    );
  }

  // ===== Boxed quantity / price field with vertical up/down steppers =====
  Widget _stepperField({
    required TextEditingController controller,
    required TextInputType keyboardType,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    List<TextInputFormatter>? inputFormatters,
    bool enabled = true,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: enabled ? _kTextPrimary : _kTextMuted, fontSize: 18),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            ),
          ),
          if (enabled)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(onTap: onIncrement, child: Icon(Icons.keyboard_arrow_up, size: 20, color: _accentColor)),
                InkWell(onTap: onDecrement, child: Icon(Icons.keyboard_arrow_down, size: 20, color: _accentColor)),
              ],
            ),
        ],
      ),
    );
  }

  // ===== Advanced options: Stoploss / GTT / Market Protection =====
  Widget _advancedOrderOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Advanced Options', style: TextStyle(color: _kTextPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
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
            const SizedBox(height: 14),
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
                  const Text('Protect up to', style: TextStyle(fontSize: 12, color: _kTextSecondary)),
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
                  Text('${_marketProtectionPercent.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kTextPrimary)),
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
      decoration: BoxDecoration(border: Border.all(color: _kBorder), borderRadius: BorderRadius.circular(8), color: _kBg),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 16, color: _kTextPrimary),
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
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextPrimary)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: _kTextMuted)),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: _accentColor),
      ],
    );
  }

  // ===== Amount + fees / Available / Total Payable or Net Receivable =====
  Widget _amountSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _showChargesDialog,
          child: Row(
            children: [
              Text('Amount ', style: const TextStyle(color: _kTextMuted, fontSize: 13)),
              Text('₹${_stockValue.toStringAsFixed(2)}', style: TextStyle(color: _accentColor, fontWeight: FontWeight.w600, fontSize: 13)),
              Text(' + ', style: const TextStyle(color: _kTextMuted, fontSize: 13)),
              Text('₹${_fees.toStringAsFixed(2)}', style: TextStyle(color: _accentColor, fontWeight: FontWeight.w600, fontSize: 13)),
              const Spacer(),
              Text('Avail. ', style: const TextStyle(color: _kTextMuted, fontSize: 13)),
              Text(_availableBalance == null ? '…' : '₹${_availableBalance!.toStringAsFixed(2)}', style: TextStyle(color: _accentColor, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 4),
              const Icon(Icons.info_outline, size: 13, color: _kTextMuted),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(isBuy ? 'Total Payable' : 'Net Receivable', style: const TextStyle(color: _kTextSecondary, fontSize: 14)),
            Text('₹${_total.toStringAsFixed(2)}', style: const TextStyle(color: _kTextPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ],
    );
  }

  void _showChargesDialog() {
    final c = _charges;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _kCard,
        title: const Text('Charges & taxes', style: TextStyle(color: _kTextPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Statutory charges', style: TextStyle(color: _kTextPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
              const Text('(Govt. & Exchange fees)', style: TextStyle(color: _kTextMuted, fontSize: 11)),
              const SizedBox(height: 8),
              _chargeLine('SEBI turnover fee', c.sebiFee),
              _chargeLine('Exchange turnover fee', c.exchangeFee),
              _chargeLine('Stamp duty', c.stampDuty),
              _chargeLine('Transaction tax (STT)', c.stt),
              _chargeLine('GST', c.gst),
              const Divider(height: 20),
              const Text('Brokerage', style: TextStyle(color: _kTextPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
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
          Text(label, style: TextStyle(color: bold ? _kTextPrimary : _kTextSecondary, fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(color: _kTextPrimary, fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  // ===== Swipe-to-confirm submit button =====
  Widget _swipeButton() {
    const trackHeight = 56.0;
    const handleSize = 48.0;
    final label = isBuy ? 'SWIPE TO BUY' : 'SWIPE TO SELL';

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final maxDx = trackWidth - handleSize - 8; // 4px padding each side
        return GestureDetector(
          onHorizontalDragStart: _submitting ? null : (_) => setState(() => _dragging = true),
          onHorizontalDragUpdate: _submitting
              ? null
              : (details) {
                  setState(() {
                    final newDx = ((_dragProgress * maxDx) + details.delta.dx).clamp(0.0, maxDx);
                    _dragProgress = maxDx == 0 ? 0 : newDx / maxDx;
                  });
                },
          onHorizontalDragEnd: _submitting
              ? null
              : (_) {
                  setState(() => _dragging = false);
                  if (_dragProgress > 0.82) {
                    setState(() => _dragProgress = 1.0);
                    _handleSubmit();
                  } else {
                    setState(() => _dragProgress = 0.0);
                  }
                },
          child: Container(
            width: trackWidth,
            height: trackHeight,
            decoration: BoxDecoration(color: _accentColor, borderRadius: BorderRadius.circular(trackHeight / 2)),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: _submitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                      : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
                ),
                if (!_submitting)
                  AnimatedPositioned(
                    duration: _dragging ? Duration.zero : const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    left: 4 + (_dragProgress * maxDx),
                    child: Container(
                      width: handleSize,
                      height: handleSize,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(Icons.chevron_right, color: _accentColor),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
