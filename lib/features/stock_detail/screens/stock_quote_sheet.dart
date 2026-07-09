import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/stock_detail/screens/advanced_chart_screen.dart';
import 'package:stock_app/features/stock_detail/screens/technicals_screen.dart';
import 'package:stock_app/features/stock_detail/screens/fundamentals_screen.dart';
import 'package:stock_app/features/stock_detail/screens/stock_detail_screen.dart';
import 'package:stock_app/features/stock_detail/screens/option_chain_screen.dart';
import 'package:stock_app/features/stock_detail/screens/set_alert_screen.dart';
import 'package:stock_app/features/stock_detail/screens/gtt_screen.dart';
import 'package:stock_app/core/services/notes_service.dart';
import 'package:stock_app/features/orders/screens/buy_order_screen.dart';

/// Opens the Kite-style stock quote bottom sheet: BUY/SELL, view chart /
/// option chain, set alert / add notes / create GTT, bid-offer depth,
/// day's range, and the rest of the quote detail ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â matching the reference
/// screenshots. Call this instead of pushing StockDetailScreen when the
/// user taps a stock in the watchlist.
Future<void> showStockQuoteSheet(BuildContext context, Map<String, dynamic> stock) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StockQuoteSheet(stock: stock),
  );
}

class _StockQuoteSheet extends StatefulWidget {
  final Map<String, dynamic> stock;
  const _StockQuoteSheet({required this.stock});

  @override
  State<_StockQuoteSheet> createState() => _StockQuoteSheetState();
}

class _StockQuoteSheetState extends State<_StockQuoteSheet> {
  Map<String, dynamic>? _quote;
  bool _loading = true;
  String? _error;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final symbol = widget.stock['symbol'];
      final results = await Future.wait([
        ApiService.getQuote(symbol),
        ApiService.getHistory(symbol).catchError((_) => []),
      ]);
      if (!mounted) return;
      setState(() {
        _quote = results[0] as Map<String, dynamic>;
        _history = results[1] as List<dynamic>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Live price unavailable right now');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatVolume(num vol) {
    final v = vol.toDouble();
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(2)} Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(2)} L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(2)} K';
    return v.toStringAsFixed(0);
  }

  String? _formatTradeTime(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString();
    if (s.isEmpty) return null;

    final millis = int.tryParse(s);
    if (millis != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
      return DateFormat('dd MMM, hh:mm:ss a').format(dt);
    }

    final parsed = DateTime.tryParse(s);
    if (parsed == null) return null;
    return DateFormat('dd MMM, hh:mm:ss a').format(parsed.toLocal());
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon')),
    );
  }

  void _showAddNotesDialog() {
    final symbol = widget.stock['symbol'] ?? '';
    final controller = TextEditingController(text: NotesService().getNote(symbol) ?? "");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [const Text('Notes'), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))],
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'eg: buy later', border: OutlineInputBorder()),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                NotesService().setNote(symbol, controller.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved for this session')));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSetAlertDialog() {
    final controller = TextEditingController();
    String direction = 'ABOVE';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Set Alert'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Target price', prefixText: '₹ '),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Above'),
                      selected: direction == 'ABOVE',
                      onSelected: (_) => setS(() => direction = 'ABOVE'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Below'),
                      selected: direction == 'BELOW',
                      onSelected: (_) => setS(() => direction = 'BELOW'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final price = double.tryParse(controller.text);
                if (price == null) return;
                try {
                  await ApiService.createAlert(widget.stock['id'], price, direction);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert created')));
                } catch (_) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create alert')));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGTTDialog() {
    final priceController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    String buySell = 'BUY';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Create GTT'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Triggers a pending order once the price hits your target.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: ChoiceChip(label: const Text('Buy'), selected: buySell == 'BUY', onSelected: (_) => setS(() => buySell = 'BUY'))),
                  const SizedBox(width: 8),
                  Expanded(child: ChoiceChip(label: const Text('Sell'), selected: buySell == 'SELL', onSelected: (_) => setS(() => buySell = 'SELL'))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: priceController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Trigger price', prefixText: '₹ ')),
              const SizedBox(height: 8),
              TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final price = double.tryParse(priceController.text);
                final qty = double.tryParse(qtyController.text);
                if (price == null || qty == null) return;
                try {
                  await ApiService.createPendingOrder(widget.stock['id'], buySell, 'LIMIT', qty, price);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GTT order created')));
                } catch (_) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create GTT order')));
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderTicket(String buySell) async {
    final currentPrice = _quote != null ? (_quote!['price'] as num).toDouble() : 0.0;
    final changePercent = _quote != null ? ((_quote!['change_percent'] as num?)?.toDouble() ?? 0.0) : 0.0;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTicketScreen(
          stock: widget.stock,
          buySell: buySell,
          currentPrice: currentPrice,
          changePercent: changePercent,
          holdingQty: 0,
          avgBuyPrice: 0,
          calcBrokerage: (value, product) => 0,
          calcTaxes: (value, buySell) => 0,
          onSubmit: ({required String orderType, required double qty, required double price}) async {
            if (orderType == 'MARKET') {
              await ApiService.placeOrder(widget.stock['id'], buySell.toUpperCase(), qty.toInt(), currentPrice);
              return 'Executed';
            } else {
              await ApiService.createPendingOrder(widget.stock['id'], buySell.toUpperCase(), 'LIMIT', qty, price);
              return 'Pending';
            }
          },
        ),
      ),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result['buySell'] == 'buy' ? 'Buy' : 'Sell'} order placed')),
      );
      _load();
    }
  }

  Widget _actionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _depthRow({required String bidPrice, required String bidOrders, required String bidQty, required String offerPrice, required String offerOrders, required String offerQty, required double bidFrac, required double offerFrac}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: FractionallySizedBox(alignment: Alignment.centerRight, widthFactor: bidFrac.clamp(0.0, 1.0), child: Container(color: AppColors.primary.withOpacity(0.08)))),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text(bidPrice, style: const TextStyle(color: AppColors.primary, fontSize: 13))),
                    SizedBox(width: 28, child: Text(bidOrders, textAlign: TextAlign.end, style: const TextStyle(color: AppColors.textMuted, fontSize: 12))),
                    SizedBox(width: 56, child: Text(bidQty, textAlign: TextAlign.end, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: offerFrac.clamp(0.0, 1.0), child: Container(color: AppColors.danger.withOpacity(0.08)))),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    SizedBox(width: 56, child: Text(offerPrice, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                    SizedBox(width: 28, child: Text(offerOrders, textAlign: TextAlign.end, style: const TextStyle(color: AppColors.textMuted, fontSize: 12))),
                    Expanded(child: Text(offerQty, textAlign: TextAlign.end, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13))),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Text(value, style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _appRow({required IconData icon, required Color iconColor, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = widget.stock;
    final price = _quote != null ? (_quote!['price'] as num?)?.toDouble() : null;
    final changePercent = _quote != null ? (_quote!['change_percent'] as num?)?.toDouble() : null;
    final change = _quote != null ? (_quote!['change'] as num?)?.toDouble() : null;
    final isUp = (changePercent ?? 0) >= 0;

    final open = _quote?['open'] != null ? (_quote!['open'] as num).toDouble() : null;
    final high = _quote?['high'] != null ? (_quote!['high'] as num).toDouble() : null;
    final low = _quote?['low'] != null ? (_quote!['low'] as num).toDouble() : null;
    final prevClose = _quote?['prev_close'] != null ? (_quote!['prev_close'] as num).toDouble() : null;
    final volume = _quote?['volume'] != null ? (_quote!['volume'] as num) : null;
    final avgPrice = _quote?['avg_price'] != null ? (_quote!['avg_price'] as num).toDouble() : null;
    final ltq = _quote?['last_traded_quantity'] != null ? (_quote!['last_traded_quantity'] as num) : null;
    final ltt = _formatTradeTime(_quote?['last_trade_time'] ?? _quote?['updated_at']);
    final lowerCircuit = _quote?['lower_circuit_limit'] != null ? (_quote!['lower_circuit_limit'] as num).toDouble() : null;
    final upperCircuit = _quote?['upper_circuit_limit'] != null ? (_quote!['upper_circuit_limit'] as num).toDouble() : null;
    final depth = _quote?['depth'] as Map<String, dynamic>?;
    final depthBuy = (depth?['buy'] as List<dynamic>?) ?? [];
    final depthSell = (depth?['sell'] as List<dynamic>?) ?? [];

    double maxDepthQty = 1;
    for (final l in [...depthBuy, ...depthSell]) {
      final q = ((l['quantity'] as num?)?.toDouble() ?? 0);
      if (q > maxDepthQty) maxDepthQty = q;
    }
    num totalBuyQty = 0, totalSellQty = 0;
    for (final l in depthBuy) { totalBuyQty += (l['quantity'] as num?) ?? 0; }
    for (final l in depthSell) { totalSellQty += (l['quantity'] as num?) ?? 0; }

    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
                children: [
                  const SizedBox(height: 10),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.of(context).padding.bottom + 16),
                      children: [
                        // Header: symbol + price
                        Text(stock['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 19, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        if (_error != null)
                          Row(children: [
                            Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                            TextButton(onPressed: _load, child: const Text('Retry')),
                          ])
                        else
                          Row(children: [
                            Text(stock['exchange'] ?? 'NSE', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            const SizedBox(width: 8),
                            Text(price != null ? price.toStringAsFixed(2) : '--', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Text(
                              change != null ? '${isUp ? '+' : ''}${change.toStringAsFixed(2)} (${isUp ? '+' : ''}${changePercent?.toStringAsFixed(2) ?? '0.00'}%)' : '--',
                              style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 12),
                            ),
                          ]),
                        const Divider(height: 28, color: AppColors.border),

                        // BUY / SELL
                        Row(children: [
                          Expanded(child: SizedBox(height: 48, child: ElevatedButton(
                            onPressed: price == null ? null : () => _showOrderTicket('buy'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            child: const Text('BUY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ))),
                          const SizedBox(width: 14),
                          Expanded(child: SizedBox(height: 48, child: ElevatedButton(
                            onPressed: price == null ? null : () => _showOrderTicket('sell'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            child: const Text('SELL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ))),
                        ]),
                        const SizedBox(height: 16),

                        // View chart / Option chain
                        Row(children: [
                          _actionButton(icon: Icons.bar_chart, label: 'View chart', onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => AdvancedChartScreen(
                              symbol: stock['symbol'] ?? '',
                              companyName: stock['company_name'] ?? '',
                              history: _history,
                              currentPrice: price,
                              changePercent: changePercent,
                              exchange: stock['exchange'] ?? 'NSE',
                            )));
                          }),
                          _actionButton(icon: Icons.tune, label: 'Option chain', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OptionChainScreen(stock: widget.stock)))),
                        ]),
                        const Divider(height: 20, color: AppColors.border),
                        Row(children: [
                          _actionButton(icon: Icons.notifications_none, label: 'Set alert', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SetAlertScreen(stock: widget.stock, currentPrice: price)))),
                          _actionButton(icon: Icons.description_outlined, label: 'Add notes', onTap: _showAddNotesDialog),
                          _actionButton(icon: Icons.shortcut, label: 'Create GTT', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GttScreen(stock: widget.stock, currentPrice: price, changePercent: changePercent)))),
                        ]),
                        const Divider(height: 24, color: AppColors.border),

                        // Bid/Offer depth
                        if (depthBuy.isNotEmpty || depthSell.isNotEmpty) ...[
                          const Row(children: [
                            Expanded(child: Row(children: [
                              Expanded(child: Text('Bid', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                              SizedBox(width: 28, child: Text('Orders', textAlign: TextAlign.end, style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                              SizedBox(width: 56, child: Text('Qty', textAlign: TextAlign.end, style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                            ])),
                            SizedBox(width: 8),
                            Expanded(child: Row(children: [
                              SizedBox(width: 56, child: Text('Offer', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                              SizedBox(width: 28, child: Text('Orders', textAlign: TextAlign.end, style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
                              Expanded(child: Text('Qty', textAlign: TextAlign.end, style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
                            ])),
                          ]),
                          const SizedBox(height: 4),
                          for (int i = 0; i < (depthBuy.length > depthSell.length ? depthBuy.length : depthSell.length); i++)
                            _depthRow(
                              bidPrice: i < depthBuy.length ? (depthBuy[i]['price'] as num).toStringAsFixed(2) : '',
                              bidOrders: i < depthBuy.length ? '${depthBuy[i]['orders']}' : '',
                              bidQty: i < depthBuy.length ? '${depthBuy[i]['quantity']}' : '',
                              offerPrice: i < depthSell.length ? (depthSell[i]['price'] as num).toStringAsFixed(2) : '',
                              offerOrders: i < depthSell.length ? '${depthSell[i]['orders']}' : '',
                              offerQty: i < depthSell.length ? '${depthSell[i]['quantity']}' : '',
                              bidFrac: i < depthBuy.length ? ((depthBuy[i]['quantity'] as num).toDouble() / maxDepthQty) : 0,
                              offerFrac: i < depthSell.length ? ((depthSell[i]['quantity'] as num).toDouble() / maxDepthQty) : 0,
                            ),
                          const Divider(height: 12, color: AppColors.border),
                          Row(children: [
                            Expanded(child: Row(children: [
                              const Expanded(child: Text('Total', style: TextStyle(color: AppColors.primary, fontSize: 13))),
                              Text(NumberFormat('#,##,###').format(totalBuyQty), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                            ])),
                            const SizedBox(width: 8),
                            Expanded(child: Row(children: [
                              const Expanded(child: Text('Total', style: TextStyle(color: AppColors.danger, fontSize: 13))),
                              Text(NumberFormat('#,##,###').format(totalSellQty), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 13)),
                            ])),
                          ]),
                        ] else
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Order book depth not available for this stock', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ),
                        const Divider(height: 28, color: AppColors.border),

                        // Day's range
                        if (low != null && high != null) ...[
                          const Text("Day's range", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 12),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            const Text('Low', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            const Text('High', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          ]),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(low.toStringAsFixed(2), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                            Text(high.toStringAsFixed(2), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                          ]),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: price != null && high > low ? ((price - low) / (high - low)).clamp(0.0, 1.0) : 0.5,
                              minHeight: 5,
                              backgroundColor: AppColors.border,
                              valueColor: const AlwaysStoppedAnimation(AppColors.danger),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (open != null) _kvRow('Open', open.toStringAsFixed(2)),
                        if (prevClose != null) _kvRow('Prev. close', prevClose.toStringAsFixed(2)),
                        if (volume != null) _kvRow('Volume', _formatVolume(volume)),
                        if (avgPrice != null) _kvRow('Avg. trade price', avgPrice.toStringAsFixed(2)),
                        if (ltq != null) _kvRow('Last traded quantity', '$ltq'),
                        if (ltt != null) _kvRow('Last traded at', ltt),
                        if (lowerCircuit != null) _kvRow('Lower circuit', lowerCircuit.toStringAsFixed(2)),
                        if (upperCircuit != null) _kvRow('Upper circuit', upperCircuit.toStringAsFixed(2)),

                        const Divider(height: 28, color: AppColors.border),
                        const Text('Apps', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        _appRow(icon: Icons.arrow_upward, iconColor: Colors.orange, label: 'Fundamentals', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FundamentalsScreen(stock: widget.stock)))),
                        const Divider(height: 1, color: AppColors.border),
                        _appRow(icon: Icons.bolt, iconColor: AppColors.primary, label: 'Technicals', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TechnicalsScreen(stock: widget.stock)))),

                        const SizedBox(height: 20),
                        const Text('Pin to overview', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: OutlinedButton(onPressed: () => _showComingSoon('Pin to overview'), style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.border)), child: const Text('Spot 1', style: TextStyle(color: AppColors.textPrimary)))),
                          const SizedBox(width: 12),
                          Expanded(child: OutlinedButton(onPressed: () => _showComingSoon('Pin to overview'), style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.border)), child: const Text('Spot 2', style: TextStyle(color: AppColors.textPrimary)))),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}


