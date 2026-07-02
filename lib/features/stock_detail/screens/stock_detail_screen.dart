import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/stock_detail/screens/price_chart.dart';
import 'package:stock_app/features/stock_detail/screens/basket_service.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:stock_app/features/stock_detail/screens/advanced_chart_screen.dart';
import 'package:stock_app/features/news/screens/news_detail_screen.dart';

class StockDetailScreen extends StatefulWidget {
  final Map<String, dynamic> stock;
  const StockDetailScreen({super.key, required this.stock});
  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> with SingleTickerProviderStateMixin {
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
  List<dynamic> _stockNews = [];
  bool _loadingNews = true;

  late TabController _tabController;
  final List<String> _tabs = ['Overview', 'Technicals', 'F&O', 'News', 'Events'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadQuote();
    _checkWatchlist();
    _loadHistory();
    _loadHolding();
    _loadAbout();
    _loadPeers();
    _loadStockNews();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update watchlist')));
    } finally { if (mounted) setState(() => _watchlistLoading = false); }
  }

  double _calcBrokerage(double value, String product) {
    if (product == 'INTRADAY') return (value * 0.0003).clamp(0, 20);
    return 0;
  }

  double _calcTaxes(double value, String buySell) {
    return value * (buySell == 'buy' ? 0.00127 : 0.00134);
  }

  String _generateOrderId() {
    final now = DateTime.now();
    return 'TRD${DateFormat('yyyyMMdd').format(now)}${now.millisecondsSinceEpoch % 100000}';
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
      backgroundColor: Colors.white,
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
              const Text('Add to Basket', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
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

  void _showOrderTicket(String buySell) {
    final isBuy = buySell == 'buy';
    final currentPrice = _quote != null ? (_quote!['price'] as num).toDouble() : 0.0;
    final changePercent = _quote != null ? (_quote!['change_percent'] as num).toDouble() : 0.0;

    String orderType = 'MARKET';
    String product = 'DELIVERY';
    String validity = 'DAY';
    final priceController = TextEditingController(text: currentPrice.toStringAsFixed(2));
    final qtyController = TextEditingController(text: '1');
    bool submitting = false;
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(builder: (sheetContext, setSheetState) {
          final price = double.tryParse(priceController.text) ?? currentPrice;
          final qty = double.tryParse(qtyController.text) ?? 0;
          final stockValue = price * qty;
          final brokerage = _calcBrokerage(stockValue, product);
          final taxes = _calcTaxes(stockValue, buySell);
          final total = isBuy ? stockValue + brokerage + taxes : stockValue - brokerage - taxes;

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: (isBuy ? AppColors.success : AppColors.danger).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                      child: Text(isBuy ? 'BUY' : 'SELL', style: TextStyle(color: isBuy ? AppColors.success : AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    Text(widget.stock['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 17)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('${widget.stock['exchange'] ?? 'NSE'}: ₹${currentPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(width: 6),
                    Text('${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%', style: TextStyle(color: changePercent >= 0 ? AppColors.success : AppColors.danger, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                  if (!isBuy && _holdingQty > 0) ...[
                    const SizedBox(height: 6),
                    Text('Holding: ${_holdingQty.toStringAsFixed(0)} Shares • Avg ₹${_avgBuyPrice.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                  const SizedBox(height: 18),
                  const Text('Order Type', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _radioChip('Market', orderType == 'MARKET', () { setSheetState(() { orderType = 'MARKET'; priceController.text = currentPrice.toStringAsFixed(2); }); })),
                    const SizedBox(width: 10),
                    Expanded(child: _radioChip('Limit', orderType == 'LIMIT', () { setSheetState(() => orderType = 'LIMIT'); })),
                  ]),
                  const SizedBox(height: 14),
                  const Text('Price', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(color: orderType == 'MARKET' ? AppColors.border.withOpacity(0.3) : AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: TextField(
                      controller: priceController,
                      enabled: orderType == 'LIMIT',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setSheetState(() {}),
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(prefixText: '₹ ', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Quantity', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setSheetState(() {}),
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(isBuy ? 'Investment Amount' : 'Expected Value', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('₹${stockValue.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Product', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _radioChip('Delivery (CNC)', product == 'DELIVERY', () => setSheetState(() => product = 'DELIVERY'))),
                    const SizedBox(width: 10),
                    Expanded(child: _radioChip('Intraday (MIS)', product == 'INTRADAY', () => setSheetState(() => product = 'INTRADAY'))),
                  ]),
                  const SizedBox(height: 14),
                  const Text('Order Validity', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _radioChip('Day', validity == 'DAY', () => setSheetState(() => validity = 'DAY'))),
                    const SizedBox(width: 10),
                    Expanded(child: _radioChip('IOC', validity == 'IOC', () => setSheetState(() => validity = 'IOC'))),
                  ]),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Column(children: [
                      const Align(alignment: Alignment.centerLeft, child: Text('Estimated Charges', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600))),
                      const SizedBox(height: 10),
                      _chargeRow('Stock Value', stockValue),
                      _chargeRow('Brokerage', brokerage),
                      _chargeRow('Taxes & Charges', taxes),
                      const Divider(color: AppColors.border, height: 16),
                      _chargeRow(isBuy ? 'Total' : 'Net Receivable', total, bold: true),
                    ]),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(errorMsg!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: submitting ? null : () async {
                        if (qty <= 0) { setSheetState(() => errorMsg = 'Enter a valid quantity'); return; }
                        if (price <= 0) { setSheetState(() => errorMsg = 'Enter a valid price'); return; }
                        setSheetState(() { submitting = true; errorMsg = null; });
                        try {
                          String status;
                          if (orderType == 'MARKET') {
                            await ApiService.placeOrder(widget.stock['id'], buySell.toUpperCase(), qty.toInt(), currentPrice);
                            status = 'Executed';
                          } else {
                            await ApiService.createPendingOrder(widget.stock['id'], buySell.toUpperCase(), 'LIMIT', qty, price);
                            status = 'Pending';
                          }
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          _loadQuote();
                          _loadHolding();
                          if (mounted) {
                            setState(() {});
                            _showOrderConfirmation(buySell: buySell, qty: qty, orderType: orderType, status: status);
                          }
                        } catch (e) {
                          setSheetState(() {
                            submitting = false;
                            errorMsg = e.toString().contains('insufficient shares') ? 'You don\'t have enough shares to sell' : e.toString().contains('insufficient') ? 'Insufficient balance' : 'Order failed: ' + (e is DioException ? (e.response?.data?.toString() ?? e.toString()) : e.toString());
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: isBuy ? AppColors.success : AppColors.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: submitting
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isBuy ? 'BUY NOW' : 'SELL NOW', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  void _showOrderConfirmation({required String buySell, required double qty, required String orderType, required String status}) {
    final isBuy = buySell == 'buy';
    final orderId = _generateOrderId();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.success.withOpacity(0.12)), child: const Icon(Icons.check_circle, color: AppColors.success, size: 38)),
            const SizedBox(height: 16),
            const Text('Order Placed Successfully', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
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
                _confirmRow('Status', status, valueColor: status == 'Executed' ? AppColors.success : AppColors.primary),
                _confirmRow('Order ID', orderId),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Done', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
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

  Widget _radioChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(color: active ? AppColors.primary.withOpacity(0.1) : AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? AppColors.primary : AppColors.border)),
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

  Color _avatarColor(String symbol) {
    final colors = [
      const Color(0xFF5E35B1), const Color(0xFF00897B), const Color(0xFFD81B60),
      const Color(0xFF1E88E5), const Color(0xFFF4511E), const Color(0xFF43A047),
      const Color(0xFF6D4C41), const Color(0xFF3949AB),
    ];
    final idx = symbol.isEmpty ? 0 : symbol.codeUnitAt(0) % colors.length;
    return colors[idx];
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
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(stock['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(stock['company_name'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  if (!_loadingQuote && _quoteError == null && price != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('₹${price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${isUp ? '+' : ''}${changePercent?.toStringAsFixed(2) ?? '0.00'}%', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  // Basket button
                  IconButton(
                    icon: const Icon(Icons.add_shopping_cart_outlined, color: AppColors.textPrimary),
                    tooltip: 'Add to Basket',
                    onPressed: price == null ? null : _showAddToBasket,
                  ),
                  // Watchlist button
                  IconButton(
                    icon: _watchlistLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                        : Icon(_inWatchlist ? Icons.star : Icons.star_outline, color: _inWatchlist ? AppColors.primary : AppColors.textMuted),
                    onPressed: _watchlistLoading ? null : _toggleWatchlist,
                  ),
                ],
              ),
            ),

            // Tab bar
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(price, changePercent, change, isUp, holdingValue, holdingPnl),
                  _buildComingSoon('Technical indicators (RSI, MACD, Moving Averages) coming soon'),
                  _buildComingSoon('F&O data (Futures & Options chain) for this stock coming soon'),
                  _buildComingSoon('Stock-specific news filtering coming soon'),
                  _buildComingSoon('Corporate events, earnings dates and announcements coming soon'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab(double? price, double? changePercent, double? change, bool isUp, double holdingValue, double holdingPnl) {
    final stock = widget.stock;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price section
          if (_loadingQuote)
            const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else if (_quoteError != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.info_outline, color: AppColors.textMuted, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(_quoteError!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                TextButton(onPressed: _loadQuote, child: const Text('Retry', style: TextStyle(color: AppColors.primaryDark))),
              ]),
            )
          else ...[
              Text('₹${price?.toStringAsFixed(2) ?? '--'}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, color: isUp ? AppColors.success : AppColors.danger, size: 14),
                const SizedBox(width: 4),
                Text('${change != null ? (isUp ? '+' : '') + change.toStringAsFixed(2) : '--'}', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontSize: 13)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: (isUp ? AppColors.success : AppColors.danger).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text('${isUp ? '+' : ''}${changePercent?.toStringAsFixed(2) ?? '0.00'}%', style: TextStyle(color: isUp ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ]),
            ],

          const SizedBox(height: 16),

          // Chart
          if (_loadingHistory)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))))
          else if (_history.isNotEmpty) ...[
            Container(
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
                  PriceChart(history: _history),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // OHLC
          if (_ohlc != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ohlcStat('Open', _ohlc!['open']!),
                  _ohlcStat('High', _ohlc!['high']!),
                  _ohlcStat('Low', _ohlc!['low']!),
                  _ohlcStat('Prev. Close', _ohlc!['prev_close'] ?? (price ?? 0)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 52W Range
          if (_recentRange != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Recent Low', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const Text('Recent High', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('₹${_recentRange!['low']!.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('₹${_recentRange!['high']!.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: price != null && _recentRange!['high']! > _recentRange!['low']!
                          ? ((price - _recentRange!['low']!) / (_recentRange!['high']! - _recentRange!['low']!)).clamp(0.0, 1.0)
                          : 0.5,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Based on last ${_history.length} trading days', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Stock details card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(children: [
              _infoRow('Exchange', stock['exchange'] ?? '-'),
              const Divider(color: AppColors.border, height: 20),
              _infoRow('Sector', stock['sector'] ?? '-'),
              if (_quote?['volume'] != null) ...[
                const Divider(color: AppColors.border, height: 20),
                _infoRow('Volume', _formatVolume((_quote!['volume'] as num).toDouble())),
              ],
              if (_avgVolume != null) ...[
                const Divider(color: AppColors.border, height: 20),
                _infoRow('Avg Volume', _formatVolume(_avgVolume!)),
              ],
              if (_recentRange != null) ...[
                const Divider(color: AppColors.border, height: 20),
                _infoRow('52W High', '₹${_recentRange!['high']!.toStringAsFixed(2)}', valueColor: AppColors.success),
                const Divider(color: AppColors.border, height: 20),
                _infoRow('52W Low', '₹${_recentRange!['low']!.toStringAsFixed(2)}', valueColor: AppColors.danger),
              ],
            ]),
          ),

          // My Holdings card
          if (_holdingQty > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: holdingPnl >= 0 ? AppColors.success.withOpacity(0.05) : AppColors.danger.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: holdingPnl >= 0 ? AppColors.success.withOpacity(0.3) : AppColors.danger.withOpacity(0.3)),
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
            ),
          ],

          // About section
          if (_aboutText != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('About', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(_aboutText!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5), maxLines: 5, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],

          // Financials - placeholder (no data source yet)
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Financials', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.border.withOpacity(0.5), borderRadius: BorderRadius.circular(6)),
                    child: const Text('Coming Soon', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 8),
                const Text('Quarterly revenue, profit and growth data will appear here once a financial data source is connected.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),

          // Mutual funds - placeholder
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Top Mutual Funds Invested', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.border.withOpacity(0.5), borderRadius: BorderRadius.circular(6)),
                    child: const Text('Coming Soon', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 8),
                const Text('Fund holdings data will appear here once connected to a fund-tracking data source.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),

          // Similar Stocks (Peer Comparison, upgraded style)
          if (_peers.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
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
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: _avatarColor(symbol).withOpacity(0.15)),
                            child: Center(
                              child: Text(
                                symbol.isNotEmpty ? symbol[0] : '?',
                                style: TextStyle(color: _avatarColor(symbol), fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
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
            ),
          ],
          const SizedBox(height: 24),

          // BUY / SELL buttons
          Row(children: [
            Expanded(child: SizedBox(height: 52, child: ElevatedButton(
              onPressed: price == null ? null : () => _showOrderTicket('buy'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('BUY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ))),
            const SizedBox(width: 12),
            Expanded(child: SizedBox(height: 52, child: ElevatedButton(
              onPressed: price == null ? null : () => _showOrderTicket('sell'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('SELL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ))),
          ]),
        ],
      ),
    );
  }
}





