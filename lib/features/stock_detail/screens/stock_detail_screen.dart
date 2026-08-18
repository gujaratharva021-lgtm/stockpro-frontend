import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/stock_detail/screens/price_chart.dart';
import 'package:stock_app/features/stock_detail/screens/basket_service.dart';
import 'package:intl/intl.dart';
import 'package:stock_app/features/stock_detail/screens/advanced_chart_screen.dart';
import 'package:stock_app/features/stock_detail/screens/technicals_screen.dart';
import 'package:stock_app/shared/widgets/stock_logo.dart';
import 'package:stock_app/features/orders/screens/buy_order_screen.dart';
import 'package:stock_app/features/orders/order_submit_helper.dart';
import 'package:stock_app/core/theme/app_typography.dart';
import 'package:stock_app/features/stock_detail/screens/option_chain_screen.dart';
import 'package:stock_app/features/assistant/screens/assistant_screen.dart';
import 'package:stock_app/shared/widgets/empty_state.dart';

class StockDetailScreen extends StatefulWidget {
  final Map<String, dynamic> stock;
  final int initialTabIndex;
  const StockDetailScreen({super.key, required this.stock, this.initialTabIndex = 0});
  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _optionChain = [];
  bool _loadingOptionChain = false;
  String? _optionChainError;
  String _selectedExpiry = '2026-07-28';
  final List<String> _expiryOptions = ['2026-07-28', '2026-08-25', '2026-09-29'];
  Map<String, dynamic>? _quote;
  bool _loadingQuote = true;
  String? _quoteError;
  List<dynamic> _history = [];
  bool _loadingHistory = true;
  bool _inWatchlist = false;
  bool _watchlistLoading = false;
  double _holdingQty = 0;
  double _avgBuyPrice = 0;
  String? _aboutText;
  List<dynamic> _peers = [];
  final Map<String, dynamic> _peerQuotes = {};
  // ignore: unused_field
  List<dynamic> _stockNews = [];
  // ignore: unused_field
  bool _loadingNews = true;

  @override
  void initState() {
    super.initState();
    _loadQuote();
    _checkWatchlist();
    _loadHistory();
    _loadHolding();
    _loadAbout();
    _loadPeers();
    _loadStockNews();
    _loadOptionChain();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Map<String, double>? get _ohlc {
    if (_history.isEmpty) return null;
    final today = _history.last;
    final open = (today['open'] as num?)?.toDouble();
    final high = (today['high'] as num?)?.toDouble();
    final low = (today['low'] as num?)?.toDouble();
    final prevClose = _history.length > 1 ? (_history[_history.length - 2]['close'] as num?)?.toDouble() : null;
    if (open == null || high == null || low == null) return null;
    return {'open': open, 'high': high, 'low': low, if (prevClose != null) 'prev_close': prevClose};
  }

  Map<String, double>? get _recentRange {
    if (_history.isEmpty) return null;
    double high = double.negativeInfinity;
    double low = double.infinity;
    for (final h in _history) {
      final hi = (h['high'] as num?)?.toDouble();
      final lo = (h['low'] as num?)?.toDouble();
      if (hi != null && hi > high) high = hi;
      if (lo != null && lo < low) low = lo;
    }
    if (high == double.negativeInfinity || low == double.infinity) return null;
    return {'high': high, 'low': low};
  }

  double? get _avgVolume {
    if (_history.isEmpty) return null;
    final volumes = _history.map((h) => (h['volume'] as num?)?.toDouble()).whereType<double>().toList();
    if (volumes.isEmpty) return null;
    return volumes.reduce((a, b) => a + b) / volumes.length;
  }

  double? get _maxVolume {
    if (_history.isEmpty) return null;
    final volumes = _history.map((h) => (h['volume'] as num?)?.toDouble()).whereType<double>().toList();
    if (volumes.isEmpty) return null;
    return volumes.reduce((a, b) => a > b ? a : b);
  }

  Future<void> _loadOptionChain() async {
    setState(() { _loadingOptionChain = true; _optionChainError = null; });
    try {
      final chain = await ApiService.getOptionChain(widget.stock['symbol'], _selectedExpiry);
      setState(() => _optionChain = chain);
    } catch (e) {
      setState(() => _optionChainError = 'Option chain unavailable right now');
    } finally {
      if (mounted) setState(() => _loadingOptionChain = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final history = await ApiService.getHistory(widget.stock['symbol']);
      setState(() => _history = history);
    } catch (_) {}
    finally { if (mounted) setState(() => _loadingHistory = false); }
  }

  Future<void> _loadQuote() async {
    setState(() { _loadingQuote = true; _quoteError = null; });
    try {
      final quote = await ApiService.getQuote(widget.stock['symbol']);
      setState(() => _quote = quote);
    } catch (e) {
      setState(() => _quoteError = 'Live price unavailable right now');
    } finally { if (mounted) setState(() => _loadingQuote = false); }
  }

  Future<void> _loadHolding() async {
    try {
      final holdings = await ApiService.getHoldings();
      final found = holdings.firstWhere(
              (h) => h['symbol'] == widget.stock['symbol'], orElse: () => null);
      if (found != null && mounted) {
        setState(() {
          _holdingQty = (found['quantity'] as num).toDouble();
          _avgBuyPrice = (found['avg_price'] as num?)?.toDouble() ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPeers() async {
    try {
      final allStocks = await ApiService.getStocks();
      final sector = widget.stock['sector'];
      final symbol = widget.stock['symbol'];
      if (sector == null) return;
      final sameSector = allStocks.where((s) => s['sector'] == sector && s['symbol'] != symbol).take(6).toList();
      if (mounted) setState(() => _peers = sameSector);
      for (final p in sameSector) {
        try {
          final q = await ApiService.getQuote(p['symbol']);
          if (mounted) setState(() => _peerQuotes[p['symbol']] = q);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _loadStockNews() async {
    setState(() => _loadingNews = true);
    try {
      final allNews = await ApiService.getNews();
      final symbol = (widget.stock['symbol'] ?? '').toString().toLowerCase();
      final companyName = (widget.stock['company_name'] ?? '').toString().toLowerCase();
      final companyFirstWord = companyName.split(' ').first;
      final filtered = allNews.where((n) {
        final title = (n['title'] ?? '').toString().toLowerCase();
        final content = (n['content'] ?? '').toString().toLowerCase();
        final text = '$title $content';
        if (symbol.isNotEmpty && text.contains(symbol.toLowerCase())) return true;
        if (companyFirstWord.isNotEmpty && companyFirstWord.length > 2 && text.contains(companyFirstWord)) return true;
        return false;
      }).toList();
      if (mounted) setState(() => _stockNews = filtered);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingNews = false);
    }
  }
  Future<void> _loadAbout() async {
    try {
      final quote = await ApiService.getAbout(widget.stock['symbol']);
      if (mounted) setState(() => _aboutText = quote);
    } catch (_) {}
  }

  Future<void> _checkWatchlist() async {
    try {
      final list = await ApiService.getWatchlist();
      final found = list.any((item) => item['stock_id'] == widget.stock['id'] || item['symbol'] == widget.stock['symbol']);
      if (mounted) setState(() => _inWatchlist = found);
    } catch (_) {}
  }

  Future<void> _toggleWatchlist() async {
    setState(() => _watchlistLoading = true);
    try {
      if (_inWatchlist) {
        await ApiService.removeFromWatchlist(widget.stock['id']);
      } else {
        await ApiService.addToWatchlist(widget.stock['id']);
      }
      setState(() => _inWatchlist = !_inWatchlist);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update watchlist')));
      }
    } finally { if (mounted) setState(() => _watchlistLoading = false); }
  }

  double _calcBrokerage(double value, String product) {
    if (product == 'INTRADAY') return (value * 0.0003).clamp(0, 20);
    return 0;
  }

  double _calcTaxes(double value, String buySell) {
    return value * (buySell == 'buy' ? 0.00127 : 0.00134);
  }

  String _formatVolume(double vol) {
    if (vol >= 10000000) return '${(vol / 10000000).toStringAsFixed(2)} Cr';
    if (vol >= 100000) return '${(vol / 100000).toStringAsFixed(2)} L';
    if (vol >= 1000) return '${(vol / 1000).toStringAsFixed(2)} K';
    return vol.toStringAsFixed(0);
  }

  void _showAddToBasket() {
    final basketService = BasketService();
    final currentPrice = _quote != null ? (_quote!['price'] as num).toDouble() : 0.0;
    int qty = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Add to Basket', style: AppTypography.titleMedium),
              const SizedBox(height: 4),
              Text('${widget.stock['symbol']} • ₹${currentPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Qty: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  IconButton(onPressed: () { if (qty > 1) setS(() => qty--); }, icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary)),
                  Text('$qty', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(onPressed: () => setS(() => qty++), icon: const Icon(Icons.add_circle_outline, color: AppColors.primary)),
                  const Spacer(),
                  Text('₹${(qty * currentPrice).toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 16),
              if (basketService.baskets.isEmpty) ...[
                const Text('No baskets yet. Create one:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                _createBasketButton(ctx, basketService, setS),
              ] else ...[
                const Text('Select basket:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                ...basketService.baskets.map((b) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(b.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  subtitle: Text('${b.items.length} stocks • ₹${b.totalValue.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: ElevatedButton(
                    onPressed: () {
                      basketService.addToBasket(b.id, BasketItem(
                        stockId: widget.stock['id'] ?? '',
                        symbol: widget.stock['symbol'] ?? '',
                        companyName: widget.stock['company_name'] ?? '',
                        quantity: qty,
                        price: currentPrice,
                      ));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to ${b.name}')));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 12)),
                    child: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                )),
                const SizedBox(height: 8),
                _createBasketButton(ctx, basketService, setS),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _createBasketButton(BuildContext ctx, BasketService basketService, StateSetter setS) {
    return OutlinedButton.icon(
      onPressed: () {
        final controller = TextEditingController();
        showDialog(
          context: ctx,
          builder: (d) => AlertDialog(
            title: const Text('New Basket'),
            content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'e.g. Tech Stocks'), autofocus: true),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    basketService.createBasket(controller.text.trim());
                    Navigator.pop(d);
                    setS(() {});
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
        );
      },
      icon: const Icon(Icons.add, size: 16),
      label: const Text('New Basket'),
      style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
    );
  }

  void _showOrderTicket(String buySell) async {
    final currentPrice = _quote != null ? (_quote!['price'] as num).toDouble() : 0.0;
    final changePercent = _quote != null ? (_quote!['change_percent'] as num).toDouble() : 0.0;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTicketScreen(
          stock: widget.stock,
          buySell: buySell,
          currentPrice: currentPrice,
          changePercent: changePercent,
          holdingQty: _holdingQty,
          avgBuyPrice: _avgBuyPrice,
          calcBrokerage: _calcBrokerage,
          calcTaxes: _calcTaxes,
          onSubmit: ({required String orderType, required double qty, required double price, double? marketProtectionPercent, String productType = 'REGULAR'}) async {
            if (orderType == 'MARKET') {
              // Re-fetch the price right before submitting -- the price
              // captured when the order sheet opened may be stale by the
              // time the user actually confirms the trade.
              final freshQuote = await ApiService.getQuote(widget.stock['symbol']);
              final rawPrice = freshQuote['price'];
              if (rawPrice is! num) throw Exception('Could not get a live price for this order');
              final freshPrice = rawPrice.toDouble();
              if (marketProtectionPercent != null && currentPrice > 0) {
                final deviation = ((freshPrice - currentPrice).abs() / currentPrice) * 100;
                if (deviation > marketProtectionPercent) {
                  throw Exception('Price moved ${deviation.toStringAsFixed(1)}% since you opened this order, beyond your ${marketProtectionPercent.toStringAsFixed(1)}% protection limit. Order not placed.');
                }
              }
              return await submitMarketOrderAndTrack(stockId: widget.stock['id'], side: buySell.toUpperCase(), quantity: qty, productType: productType);
            } else {
              await ApiService.createPendingOrder(widget.stock['id'], buySell.toUpperCase(), 'LIMIT', qty, price);
              return const OrderSubmitResult(status: 'Pending');
            }
          },
        ),
      ),
    );

    if (result != null && mounted) {
      _loadQuote();
      _loadHolding();
      _showOrderConfirmation(
        buySell: result['buySell'] as String,
        qty: result['qty'] as double,
        orderType: result['orderType'] as String,
        status: result['status'] as String,
        orderId: result['orderId'] as String?,
      );
    }
  }

  void _showOrderConfirmation({required String buySell, required double qty, required String orderType, required String status, String? orderId}) {
    final isBuy = buySell == 'buy';
    final isSuccess = status == 'Executed';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, color: (isSuccess ? AppColors.success : AppColors.primary).withValues(alpha: 0.12)), child: Icon(isSuccess ? Icons.check_circle : Icons.access_time_filled, color: isSuccess ? AppColors.success : AppColors.primary, size: 38)),
              const SizedBox(height: 16),
              Text(isSuccess ? 'Order Placed Successfully' : 'Order Submitted', style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('${isBuy ? 'BUY' : 'SELL'} Order', style: TextStyle(color: isBuy ? AppColors.success : AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                child: Column(children: [
                  _confirmRow('Stock', widget.stock['symbol'] ?? ''),
                  _confirmRow('Qty', qty.toStringAsFixed(0)),
                  _confirmRow('Price', orderType == 'MARKET' ? 'Market' : 'Limit'),
                  _confirmRow('Status', status, valueColor: isSuccess ? AppColors.success : AppColors.primary),
                  if (orderId != null) _confirmRow('Order ID', orderId),
                ]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Done', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _confirmRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Text(value, style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _chargeRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: bold ? AppColors.textPrimary : AppColors.textMuted, fontSize: bold ? 14 : 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text('₹${value.toStringAsFixed(2)}', style: TextStyle(color: AppColors.textPrimary, fontSize: bold ? 14 : 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _radioChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(color: active ? AppColors.primary.withValues(alpha: 0.1) : AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? AppColors.primary : AppColors.border)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 16, color: active ? AppColors.primary : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: active ? AppColors.primary : AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _ohlcStat(String label, double value) {
    return Column(children: [
      Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      const SizedBox(height: 4),
      Text('₹${value.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
    ]);
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Text(value, style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // Market-data range slider: a track from low to high with a marker dot
  // at the current price's position. Used for both the intraday (Today)
  // range and the 52-week range, so both share one implementation.
  Widget _rangeSliderCard({required String centerLabel, required double low, required double high, required double? current}) {
    final ratio = (current != null && high > low) ? ((current - low) / (high - low)).clamp(0.0, 1.0) : 0.5;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Low', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            Text(centerLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const Text('High', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('₹${low.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            Text('₹${high.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              const dotSize = 12.0;
              final trackWidth = constraints.maxWidth;
              final dotLeft = (ratio * trackWidth) - (dotSize / 2);
              return SizedBox(
                height: dotSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: (dotSize - 6) / 2,
                      child: Container(
                        width: trackWidth,
                        height: 6,
                        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    if (current != null)
                      Positioned(
                        left: dotLeft.clamp(0.0, trackWidth - dotSize),
                        child: Container(
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.background, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Color _avatarColor(String symbol) {
    final colors = [
      const Color(0xFF5E35B1), const Color(0xFF00897B), const Color(0xFFD81B60),
      const Color(0xFF1E88E5), const Color(0xFFF4511E), const Color(0xFF43A047),
      const Color(0xFF6D4C41), const Color(0xFF3949AB),
    ];
    final idx = symbol.isEmpty ? 0 : symbol.codeUnitAt(0) % colors.length;
    return colors[idx];
  }

  String _expiryLabel(String expiry) {
    try {
      final date = DateTime.parse(expiry);
      final now = DateTime.now();
      final days = date.difference(now).inDays;
      final dd = DateFormat('d MMM').format(date);
      if (days <= 0) return dd;
      if (days < 45) {
        final weeks = (days / 7).round();
        return '$dd (${weeks <= 1 ? '1 Week' : '$weeks Weeks'})';
      }
      final months = (days / 30).round();
      return '$dd (${months <= 1 ? '1 Month' : '$months Months'})';
    } catch (_) {
      return expiry;
    }
  }

  double? get _pcr {
    if (_optionChain.isEmpty) return null;
    double callOi = 0;
    double putOi = 0;
    for (final row in _optionChain) {
      final call = row['call_option'];
      final put = row['put_option'];
      callOi += ((call?['oi'] as num?) ?? 0).toDouble();
      putOi += ((put?['oi'] as num?) ?? 0).toDouble();
    }
    if (callOi == 0) return null;
    return putOi / callOi;
  }

  double? get _maxPain {
    if (_optionChain.isEmpty) return null;
    double? best;
    double bestLoss = double.infinity;
    for (final row in _optionChain) {
      final strike = (row['strike_price'] as num?)?.toDouble();
      if (strike == null) continue;
      double loss = 0;
      for (final r in _optionChain) {
        final s = (r['strike_price'] as num?)?.toDouble();
        if (s == null) continue;
        final callOi = ((r['call_option']?['oi'] as num?) ?? 0).toDouble();
        final putOi = ((r['put_option']?['oi'] as num?) ?? 0).toDouble();
        if (strike > s) loss += (strike - s) * callOi;
        if (strike < s) loss += (s - strike) * putOi;
      }
      if (loss < bestLoss) {
        bestLoss = loss;
        best = strike;
      }
    }
    return best;
  }

  Widget _statBox(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildOptionChainTab() {
    final price = _quote != null ? (_quote!['price'] as num?)?.toDouble() : null;
    final changePercent = _quote != null ? (_quote!['change_percent'] as num?)?.toDouble() : null;
    final isUp = (changePercent ?? 0) >= 0;

    return Column(
      children: [
        // Search-style price header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                const SizedBox(width: 10),
                Text(widget.stock['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                if (price != null) ...[
                  Text(price.toStringAsFixed(2), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 6),
                  Text('${isUp ? '+' : ''}${changePercent?.toStringAsFixed(2) ?? '0.00'}%', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
        ),
        // Expiry chips
        Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _expiryOptions.map((exp) {
                final selected = exp == _selectedExpiry;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_expiryLabel(exp)),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedExpiry = exp);
                      _loadOptionChain();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        // Column headers
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(child: Text('Call LTP', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
              SizedBox(width: 70, child: Text('Strike', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
              Expanded(child: Text('Put LTP', textAlign: TextAlign.right, style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        const Divider(color: AppColors.border, height: 12),
        if (_loadingOptionChain)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_optionChainError != null)
          Expanded(child: Center(child: Text(_optionChainError!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))))
        else if (_optionChain.isEmpty)
          const Expanded(child: Center(child: Text('No option chain data available', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _optionChain.length,
              separatorBuilder: (_, _) => const Divider(color: AppColors.border, height: 1),
              itemBuilder: (context, index) {
                final row = _optionChain[index];
                final call = row['call_option'];
                final put = row['put_option'];
                final strike = row['strike_price'];
                final atm = price != null && strike != null && ((strike as num).toDouble() - price).abs() < 2.5;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${call?['ltp'] ?? '-'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('OI: ${call?['oi'] ?? '-'}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: atm ? AppColors.textPrimary : AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('$strike', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: atm ? Colors.white : AppColors.textPrimary)),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${put?['ltp'] ?? '-'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('OI: ${put?['oi'] ?? '-'}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        // PCR / Max Pain footer
        if (_optionChain.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                _statBox('PCR', _pcr != null ? _pcr!.toStringAsFixed(2) : '-'),
                _statBox('Max Pain', _maxPain != null ? _maxPain!.toStringAsFixed(0) : '-'),
              ],
            ),
          ),
      ],
    );
  }
  Widget _buildComingSoon(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction_outlined, color: AppColors.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = widget.stock;
    final price = _quote != null ? (_quote!['price'] as num).toDouble() : null;
    final changePercent = _quote != null ? (_quote!['change_percent'] as num).toDouble() : null;
    final change = _quote != null ? (_quote!['change'] as num?)?.toDouble() : null;
    final isUp = (changePercent ?? 0) >= 0;
    final holdingValue = _holdingQty > 0 && price != null ? _holdingQty * price : 0.0;
    final holdingPnl = _holdingQty > 0 && price != null ? (_holdingQty * price) - (_holdingQty * _avgBuyPrice) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildFixedHeader(stock, price, changePercent, isUp),
            Expanded(
              child: _loadingQuote && _quote == null
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPriceHero(stock, price, change, changePercent, isUp),
                          const SizedBox(height: 16),
                          _buildChartCard(stock, price, changePercent),
                          const SizedBox(height: 16),
                          _buildCalendarEventsCard(),
                          const SizedBox(height: 20),
                          _buildMarketDataSection(price),
                          const SizedBox(height: 20),
                          _buildCompanyProfileSection(),
                          if (_holdingQty > 0) ...[
                            const SizedBox(height: 14),
                            _buildHoldingsCard(holdingValue, holdingPnl),
                          ],
                          if (_peers.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _buildSimilarStocksCard(),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _buildTradingBar(price),
      ),
    );
  }

  // ===== Fixed header: back, symbol, chat, favorite, overflow menu =====
  Widget _buildFixedHeader(Map<String, dynamic> stock, double? price, double? changePercent, bool isUp) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 4),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
          Expanded(
            child: Text(stock['symbol'] ?? '', style: AppTypography.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: AppColors.textPrimary),
            tooltip: 'Ask AI Assistant',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantScreen())),
          ),
          IconButton(
            icon: _watchlistLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : Icon(_inWatchlist ? Icons.favorite : Icons.favorite_border, color: _inWatchlist ? AppColors.primary : AppColors.textMuted),
            onPressed: _watchlistLoading ? null : _toggleWatchlist,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onSelected: (v) {
              if (v == 'basket') _showAddToBasket();
              if (v == 'technicals') Navigator.push(context, MaterialPageRoute(builder: (_) => TechnicalsScreen(stock: widget.stock)));
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'basket', child: Text('Add to Basket')),
              PopupMenuItem(value: 'technicals', child: Text('View Technicals')),
            ],
          ),
        ],
      ),
    );
  }

  // ===== Price hero: company name, big price, change, logo =====
  Widget _buildPriceHero(Map<String, dynamic> stock, double? price, double? change, double? changePercent, bool isUp) {
    if (_quoteError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          const Icon(Icons.info_outline, color: AppColors.textMuted, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(_quoteError!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          TextButton(onPressed: _loadQuote, child: const Text('Retry', style: TextStyle(color: AppColors.primaryDark))),
        ]),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((stock['company_name'] ?? '').toString().toUpperCase(), style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('₹${price?.toStringAsFixed(2) ?? '--'}', style: AppTypography.priceHero),
                ],
              ),
              const SizedBox(height: 4),
              Row(children: [
                Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, color: isUp ? AppColors.success : AppColors.danger, size: 14),
                const SizedBox(width: 4),
                Text(
                  '${change != null ? (isUp ? '+' : '') + change.toStringAsFixed(2) : '--'} (${isUp ? '+' : ''}${changePercent?.toStringAsFixed(2) ?? '0.00'}%) today',
                  style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ]),
            ],
          ),
        ),
        StockLogo(symbol: stock['symbol'], companyName: stock['company_name'], size: 44, borderRadiusFactor: 0.35),
      ],
    );
  }

  // ===== Chart card: timeframes + line/candlestick chart =====
  Widget _buildChartCard(Map<String, dynamic> stock, double? price, double? changePercent) {
    if (_loadingHistory) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))));
    }
    if (_history.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => AdvancedChartScreen(
                  symbol: stock['symbol'] ?? '',
                  companyName: stock['company_name'] ?? '',
                  history: _history,
                  currentPrice: price,
                  changePercent: changePercent,
                )));
              },
              icon: const Icon(Icons.candlestick_chart, size: 16, color: AppColors.primary),
              label: const Text('Advanced Chart', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          PriceChart(history: _history, symbol: widget.stock['symbol'] ?? ''),
        ],
      ),
    );
  }

  // ===== Calendar Events card (Dividend etc.) =====
  Widget _buildCalendarEventsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Calendar Events', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.calendar_month_outlined, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'No upcoming corporate actions to show for this stock right now.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== Market Data section =====
  Widget _buildMarketDataSection(double? price) {
    final ohlc = _ohlc;
    final recentRange = _recentRange;
    final volume = _quote?['volume'] != null ? (_quote!['volume'] as num).toDouble() : null;
    final maxVolume = _maxVolume;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Market Data', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 12),
        if (ohlc != null) ...[
          _rangeSliderCard(centerLabel: 'Today', low: ohlc['low']!, high: ohlc['high']!, current: price),
          const SizedBox(height: 12),
        ],
        if (recentRange != null) ...[
          _rangeSliderCard(centerLabel: '52 Weeks', low: recentRange['low']!, high: recentRange['high']!, current: price),
          const SizedBox(height: 12),
        ],
        if (volume != null && maxVolume != null && maxVolume > 0) ...[
          _volumeSliderCard(volume, maxVolume),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Column(
            children: [
              Row(children: [
                Expanded(child: _marketDataStat('Mkt. Cap', '--')),
                Expanded(child: _marketDataStat('Hist. Volat.', '--')),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _marketDataStat('EPS', '--')),
                Expanded(child: _marketDataStat('Imp. Vol.', '--')),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _marketDataStat('P/E', '--')),
                const Expanded(child: SizedBox.shrink()),
              ]),
              const Divider(color: AppColors.border, height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'Dividend Amount/Yield: ', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                        TextSpan(text: '-- / --', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                      ]),
                    ),
                  ),
                  Text('History', style: TextStyle(color: AppColors.primary.withValues(alpha: 0.5), fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 16),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _marketDataStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    );
  }

  Widget _volumeSliderCard(double volume, double maxVolume) {
    final ratio = (volume / maxVolume).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Min', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            Text('Volume: ${_formatVolume(volume)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            const Text('Max', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('0', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            Text(_formatVolume(maxVolume), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              const dotSize = 12.0;
              final trackWidth = constraints.maxWidth;
              final dotLeft = (ratio * trackWidth) - (dotSize / 2);
              return SizedBox(
                height: dotSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: (dotSize - 6) / 2,
                      child: Container(width: trackWidth, height: 6, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
                    ),
                    Positioned(
                      left: dotLeft.clamp(0.0, trackWidth - dotSize),
                      child: Container(
                        width: dotSize,
                        height: dotSize,
                        decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.background, width: 2)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ===== Company Profile section =====
  Widget _buildCompanyProfileSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Company Profile', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: _aboutText != null && _aboutText!.trim().isNotEmpty
              ? Text(_aboutText!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5))
              : const EmptyState(icon: Icons.search_off, message: 'No data to show'),
        ),
      ],
    );
  }

  Widget _buildHoldingsCard(double holdingValue, double holdingPnl) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: holdingPnl >= 0 ? AppColors.success.withValues(alpha: 0.05) : AppColors.danger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: holdingPnl >= 0 ? AppColors.success.withValues(alpha: 0.3) : AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Holdings', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Qty', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              Text('${_holdingQty.toStringAsFixed(0)} shares', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            ])),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Avg Price', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              Text('₹${_avgBuyPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            ])),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Current Value', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              Text('₹${holdingValue.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
            ])),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('P&L', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              Text('${holdingPnl >= 0 ? '+' : ''}₹${holdingPnl.toStringAsFixed(2)}', style: TextStyle(color: holdingPnl >= 0 ? AppColors.success : AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13)),
            ])),
          ]),
        ],
      ),
    );
  }

  Widget _buildSimilarStocksCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Similar Stocks', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          const Row(
            children: [
              Expanded(child: Text('Stock', style: TextStyle(color: AppColors.textMuted, fontSize: 11))),
              Text('Market price', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
          const Divider(color: AppColors.border, height: 18),
          ..._peers.map((p) {
            final symbol = (p['symbol'] ?? '').toString();
            final q = _peerQuotes[symbol];
            final price = q != null ? (q['price'] as num?)?.toDouble() : null;
            final changePct = q != null ? (q['change_percent'] as num?)?.toDouble() : null;
            final change = q != null ? (q['change'] as num?)?.toDouble() : null;
            final isUp = (changePct ?? 0) >= 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  StockLogo(symbol: symbol, companyName: p['company_name']?.toString(), size: 34, borderRadiusFactor: 0.5),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['company_name'] ?? symbol, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(symbol, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (price != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(
                          '${isUp ? '+' : ''}${change?.toStringAsFixed(2) ?? '0.00'} (${changePct?.toStringAsFixed(2) ?? '0.00'}%)',
                          style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  else
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===== Fixed bottom Buy / Sell / Options bar (outside the scroll area) =====
  Widget _buildTradingBar(double? price) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.navBackground,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: price == null ? null : () => _showOrderTicket('buy'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                child: const Text('Buy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: price == null ? null : () => _showOrderTicket('sell'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                child: const Text('Sell', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OptionChainScreen(stock: widget.stock))),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                child: const Text('Options', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
