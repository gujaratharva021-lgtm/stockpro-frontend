import 'package:flutter/material.dart';
import 'package:stock_app/shared/widgets/overview_sheet.dart';
import 'package:intl/intl.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/stock_detail/screens/basket_service.dart';
import 'package:stock_app/features/profile/screens/tradebook_screen.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/features/orders/screens/buy_order_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Open', 'Executed', 'GTT', 'Baskets', 'SIPs', 'Alerts'];

  bool _loading = true;
  List<dynamic> _pendingOrders = [];
  List<dynamic> _transactions = [];
  List<dynamic> _sips = [];
  List<dynamic> _alerts = [];
  Map<String, String> _symbolByStockId = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getPendingOrders(),
        ApiService.getSIPs(),
        ApiService.getAlerts(),
        ApiService.getStocks(),
        ApiService.getTransactions(),
      ]);
      final stocks = results[3];
      final map = <String, String>{};
      for (final s in stocks) {
        if (s['id'] != null && s['symbol'] != null) map[s['id']] = s['symbol'];
      }
      if (mounted) {
        setState(() {
          _pendingOrders = results[0];
          _transactions = results[4];
          _sips = results[1];
          _alerts = results[2];
          _symbolByStockId = map;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    try {
      await ApiService.cancelPendingOrder(orderId);
      _loadAll();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not cancel order')));
    }
  }

  Future<void> _modifyOrder(String orderId, double price, int quantity) async {
    try {
      await ApiService.modifyPendingOrder(orderId, price: price, quantity: quantity);
      if (mounted) Navigator.pop(context);
      _loadAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order modified')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not modify order')));
    }
  }

  void _showModifyOrder(Map<String, dynamic> order) {
    final priceController = TextEditingController(text: (order['trigger_price'] ?? '0').toString());
    final qtyController = TextEditingController(text: (order['quantity'] ?? '0').toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Modify Order - ' + (order['symbol'] ?? ''), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 20),
            const Text('Quantity', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
            const SizedBox(height: 16),
            const Text('Price', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final price = double.tryParse(priceController.text) ?? 0;
                  final qty = int.tryParse(qtyController.text) ?? 0;
                  _modifyOrder(order['id'], price, qty);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('MODIFY ORDER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showOrderDetail(Map<String, dynamic> order) {
    final isBuy = order['buy_sell'] == 'BUY';
    final status = order['status'] ?? '';
    final statusColor = status == 'REJECTED'
        ? AppColors.danger
        : status == 'EXECUTED'
            ? AppColors.success
            : AppColors.textMuted;
    final qty = order['quantity'] ?? 0;
    final filledQty = status == 'EXECUTED' ? qty : 0;
    final createdAt = order['created_at'] != null ? DateTime.tryParse(order['created_at']) : null;
    final timeStr = createdAt != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt.toLocal()) : '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(order['symbol'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: (isBuy ? AppColors.success : AppColors.danger).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(order['buy_sell'] ?? '', style: TextStyle(color: isBuy ? AppColors.success : AppColors.danger, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ]),
              if (status == 'REJECTED') ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: const Text(
                    'Order rejected: insufficient funds or shares at the time of execution.',
                    style: TextStyle(color: AppColors.danger, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _repeatOrder(order);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text('REPEAT ORDER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _detailRow('Filled qty.', '$filledQty/${qty.toString()}'),
              _detailRow('Type', (order['order_type'] ?? '-').toString()),
              _detailRow('Status', status),
              _detailRow('Price', (order['trigger_price'] ?? '-').toString()),
              _detailRow('Time', timeStr),
              _detailRow('Order ID', (order['id'] ?? '-').toString()),
              _detailRow('Exchange Time', '-'),
              _detailRow('Exchange ID', '-'),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _repeatOrder(Map<String, dynamic> order) async {
    try {
      final symbol = order['symbol'] ?? '';
      final quoteMap = await ApiService.getQuote(symbol);
      final currentPrice = (quoteMap['price'] as num?)?.toDouble() ?? 0.0;
      final changePercent = (quoteMap['change_percent'] as num?)?.toDouble() ?? 0.0;
      final stock = {
        'id': order['stock_id'],
        'symbol': symbol,
        'exchange': quoteMap['exchange'] ?? 'NSE',
      };
      final buySell = (order['buy_sell'] ?? 'BUY').toString().toLowerCase();

      if (!mounted) return;
      final result = await Navigator.push(context, MaterialPageRoute(
        builder: (_) => OrderTicketScreen(
          stock: stock,
          buySell: buySell,
          currentPrice: currentPrice,
          changePercent: changePercent,
          holdingQty: 0,
          avgBuyPrice: 0,
          calcBrokerage: (value, product) => product == 'INTRADAY' ? (value * 0.0003).clamp(0, 20) : 0,
          calcTaxes: (value, bs) => value * (bs == 'buy' ? 0.00127 : 0.00134),
          onSubmit: ({required String orderType, required double qty, required double price}) async {
            if (orderType == 'MARKET') {
              await ApiService.placeOrder(stock['id'], buySell.toUpperCase(), qty.toInt(), currentPrice);
              return 'Executed';
            } else {
              await ApiService.createPendingOrder(stock['id'], buySell.toUpperCase(), 'LIMIT', qty, price);
              return 'Pending';
            }
          },
        ),
      ));

      if (result != null) _loadAll();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not repeat order')));
    }
  }

  Future<void> _cancelSip(String sipId) async {
    try {
      await ApiService.cancelSIP(sipId);
      _loadAll();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not cancel SIP')));
    }
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, color: AppColors.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final isBuy = order['buy_sell'] == 'BUY';
    final status = order['status'] ?? '';
    final statusColor = status == 'REJECTED'
        ? AppColors.danger
        : status == 'EXECUTED'
            ? AppColors.success
            : AppColors.textMuted;
    return GestureDetector(
      onTap: () => _showOrderDetail(order),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: (isBuy ? AppColors.success : AppColors.danger).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                  child: Text(order['buy_sell'] ?? '', style: TextStyle(color: isBuy ? AppColors.success : AppColors.danger, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
                const SizedBox(width: 8),
                Text(order['symbol'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                Text(status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Qty: ' + (order['quantity'] ?? '-').toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                Text('Trigger: ' + (order['trigger_price'] ?? '-').toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
            if (status == 'PENDING') ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _showModifyOrder(order),
                    child: const Text('Modify', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                    onPressed: () => _cancelOrder(order['id']),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(String filterStatus) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final List<dynamic> filtered;
    if (filterStatus == 'GTT') {
      filtered = _pendingOrders.where((o) => o['is_gtt'] == true).toList();
    } else if (filterStatus == 'EXECUTED') {
      final executedPending = _pendingOrders.where((o) => o['status'] == 'EXECUTED' && o['is_gtt'] != true).toList();
      final marketExecuted = _transactions.map((t) => {
        'id': t['id'],
        'stock_id': t['stock_id'],
        'symbol': _symbolByStockId[t['stock_id']] ?? '',
        'buy_sell': t['buy_sell'],
        'order_type': 'MARKET',
        'quantity': t['quantity'],
        'price': t['price'],
        'status': 'EXECUTED',
        'created_at': t['created_at'],
        'is_gtt': false,
      }).toList();
      filtered = [...marketExecuted, ...executedPending];
    } else if (filterStatus.isEmpty) {
      filtered = _pendingOrders.where((o) => o['is_gtt'] != true).toList();
    } else {
      filtered = _pendingOrders.where((o) => o['status'] == filterStatus && o['is_gtt'] != true).toList();
    }
    if (filtered.isEmpty) return _emptyState('No ' + (filterStatus.isEmpty ? 'orders' : filterStatus.toLowerCase() + ' orders') + '.\nPlace an order from your watchlist');
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: filtered.length,
        itemBuilder: (context, i) => _orderCard(filtered[i]),
      ),
    );
  }

  Widget _buildBaskets() {
    final baskets = BasketService().baskets;
    if (baskets.isEmpty) return _emptyState('No baskets yet.\nAdd stocks to a basket from a stock screen');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: baskets.length,
      itemBuilder: (context, i) {
        final b = baskets[i];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(b.items.length.toString() + ' stocks - ' + b.totalValue.toStringAsFixed(2), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSips() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_sips.isEmpty) return _emptyState('No active SIPs.\nStart a SIP from a mutual fund screen');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _sips.length,
      itemBuilder: (context, i) {
        final s = _sips[i];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text((s['fund_id'] ?? 'SIP').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  TextButton(
                    onPressed: () => _cancelSip(s['id']),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                  ),
                ],
              ),
              Text('Amount: ' + (s['amount'] ?? '-').toString() + ' - ' + (s['frequency'] ?? '-').toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              Text('Next: ' + (s['next_date'] ?? '-').toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlerts() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_alerts.isEmpty) return _emptyState('No alerts set.\nCreate one from a stock screen');
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _alerts.length,
      itemBuilder: (context, i) {
        final a = _alerts[i];
        final symbol = _symbolByStockId[a['stock_id']] ?? 'Stock';
        final triggered = a['triggered'] == true;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(symbol, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text((a['direction'] ?? '-').toString() + ' ' + (a['target_price'] ?? '-').toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: (triggered ? AppColors.success : AppColors.primary).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(triggered ? 'Triggered' : 'Active', style: TextStyle(color: triggered ? AppColors.success : AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MainShell(
      currentIndex: 1,
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Orders', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 24)),
                  GestureDetector(onTap: () => showOverviewSheet(context), child: const Icon(Icons.keyboard_arrow_down, color: AppColors.textPrimary)),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              indicatorColor: AppColors.primary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                    const SizedBox(width: 16),
                    const Icon(Icons.tune, color: AppColors.textMuted, size: 20),
                  ]),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TradebookScreen())),
                    child: const Row(children: [
                      Icon(Icons.circle, color: AppColors.primary, size: 18),
                      SizedBox(width: 6),
                      Text('Tradebook', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrdersList('PENDING'),
                  _buildOrdersList('EXECUTED'),
                  _buildOrdersList('GTT'),
                  _buildBaskets(),
                  _buildSips(),
                  _buildAlerts(),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}