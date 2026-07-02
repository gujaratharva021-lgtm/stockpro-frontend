import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/shared/widgets/main_shell.dart';
import 'package:stock_app/features/search/screens/search_screen.dart';
import 'package:stock_app/features/orders/screens/basket_screen.dart';

class PendingOrdersScreen extends StatefulWidget {
  const PendingOrdersScreen({super.key});
  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  List<dynamic> _orders = [];
  List<dynamic> _transactions = [];
  bool _loading = true;
  String? _error;
  int _tab = 0; // 0 = Open Orders, 1 = Order History
  String _historyFilter = 'All'; // All, Executed, Cancelled
  bool _newestFirst = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.getPendingOrders(),
        ApiService.getTransactions(),
      ]);
      setState(() {
        _orders = results[0];
        _transactions = results[1];
      });
    } catch (_) {
      setState(() => _error = 'Could not load orders');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(String orderId) async {
    try {
      await ApiService.cancelPendingOrder(orderId);
      _load();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not cancel order')),
      );
    }
  }

  List<dynamic> get _pendingOnly => _orders.where((o) => o['status'] == 'PENDING').toList();
  List<dynamic> get _cancelledOrders => _orders.where((o) => o['status'] == 'CANCELLED').toList();

  double get _totalPendingValue => _pendingOnly.fold(0.0, (sum, o) {
    final qty = (o['quantity'] as num?)?.toDouble() ?? 0;
    final price = (o['trigger_price'] as num?)?.toDouble() ?? 0;
    return sum + qty * price;
  });

  List<dynamic> get _filteredHistory {
    if (_historyFilter == 'Cancelled') {
      final list = List<dynamic>.from(_cancelledOrders);
      list.sort((a, b) {
        final aDate = (a['created_at'] ?? '').toString();
        final bDate = (b['created_at'] ?? '').toString();
        return _newestFirst ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
      });
      return list;
    }
    if (_historyFilter == 'Executed') {
      final list = List<dynamic>.from(_transactions);
      list.sort((a, b) {
        final aDate = (a['created_at'] ?? '').toString();
        final bDate = (b['created_at'] ?? '').toString();
        return _newestFirst ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
      });
      return list;
    }
    // 'All': merge executed transactions + cancelled pending orders, sorted by date
    final merged = [
      ..._transactions.map((t) => {'type': 'executed', 'data': t}),
      ..._cancelledOrders.map((o) => {'type': 'cancelled', 'data': o}),
    ];
    merged.sort((a, b) {
      final aDate = (a['data']['created_at'] ?? '').toString();
      final bDate = (b['data']['created_at'] ?? '').toString();
      return _newestFirst ? bDate.compareTo(aDate) : aDate.compareTo(bDate);
    });
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    return MainShell(
      currentIndex: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Orders', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.search, color: AppColors.textPrimary),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                        ),
                        IconButton(
                          icon: Icon(_newestFirst ? Icons.south : Icons.north, color: AppColors.textPrimary),
                          tooltip: _newestFirst ? 'Newest first' : 'Oldest first',
                          onPressed: () => setState(() => _newestFirst = !_newestFirst),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _tabChip('Open Orders', _pendingOnly.length, 0),
                    const SizedBox(width: 20),
                    _tabChip('Order History', null, 1),
                    const SizedBox(width: 20),
                    _tabChip('Baskets', null, 2),
                  ],
                ),
              ),
              const Divider(color: AppColors.border, height: 20),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              else if (_error != null)
                Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: AppColors.textSecondary))))
              else
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _load,
                    child: _tab == 0 ? _buildOpenOrders() : _tab == 1 ? _buildHistory() : const BasketScreen(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabChip(String label, int? count, int index) {
    final active = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(color: active ? AppColors.primaryDark : AppColors.textSecondary, fontSize: 14, fontWeight: active ? FontWeight.bold : FontWeight.w500)),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: active ? AppColors.primary.withOpacity(0.15) : AppColors.border, borderRadius: BorderRadius.circular(10)),
                  child: Text('$count', style: TextStyle(color: active ? AppColors.primaryDark : AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          if (active) Container(margin: const EdgeInsets.only(top: 6), height: 2, width: 24, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Row(
          children: [
            _summaryStat('Total Orders', '${_orders.length + _transactions.length}'),
            _summaryStat('Executed', '${_transactions.length}'),
            _summaryStat('Pending', '${_pendingOnly.length}'),
            _summaryStat('Total Value', '₹${_totalPendingValue.toStringAsFixed(0)}'),
          ],
        ),
      ),
    );
  }

  Widget _summaryStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenOrders() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _summaryCard()),
        if (_pendingOnly.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pending_actions_outlined, color: AppColors.textMuted, size: 48),
                  const SizedBox(height: 12),
                  const Text('No open orders', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text('Place a limit or stop-loss order from a stock page', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Open Orders (${_pendingOnly.length})', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                  if (_pendingOnly.length > 1)
                    GestureDetector(
                      onTap: () async {
                        for (final o in List.from(_pendingOnly)) {
                          await _cancel(o['id']);
                        }
                      },
                      child: const Text('Cancel All', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) => _openOrderCard(_pendingOnly[index]),
                childCount: _pendingOnly.length,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _openOrderCard(dynamic o) {
    final isBuy = o['buy_sell'] == 'BUY';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: (isBuy ? AppColors.success : AppColors.danger).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                    child: Text(o['buy_sell'] ?? '', style: TextStyle(color: isBuy ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Text(o['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: const Text('OPEN', style: TextStyle(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${o['order_type'] == 'LIMIT' ? 'Limit' : 'Stop-Loss'} • ${o['quantity']} shares • Trigger: ₹${o['trigger_price']}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _cancel(o['id']),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Cancel Order', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    final items = _filteredHistory;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ['All', 'Executed', 'Cancelled'].map((f) {
                  final active = _historyFilter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _historyFilter = f),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: active ? AppColors.primary : AppColors.border),
                        ),
                        child: Text(f, style: TextStyle(color: active ? Colors.white : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, color: AppColors.textMuted, size: 48),
                  const SizedBox(height: 12),
                  const Text('No orders here yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  if (_historyFilter == 'Executed') return _executedCard(items[index]);
                  if (_historyFilter == 'Cancelled') return _cancelledCard(items[index]);
                  final entry = items[index];
                  return entry['type'] == 'executed' ? _executedCard(entry['data']) : _cancelledCard(entry['data']);
                },
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _executedCard(dynamic t) {
    final isBuy = (t['buy_sell']?.toString().toUpperCase() ?? '') == 'BUY';
    final qty = (t['quantity'] as num?) ?? 0;
    final price = (t['price'] as num?)?.toDouble() ?? 0;
    final date = t['created_at']?.toString().split('T').first ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: (isBuy ? AppColors.success : AppColors.danger).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                    child: Text(isBuy ? 'BUY' : 'SELL', style: TextStyle(color: isBuy ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Text(t['symbol']?.toString() ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: const Text('EXECUTED', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Qty: $qty • ₹${price.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              Text('Executed on $date', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cancelledCard(dynamic o) {
    final isBuy = o['buy_sell'] == 'BUY';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: (isBuy ? AppColors.success : AppColors.danger).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                    child: Text(o['buy_sell'] ?? '', style: TextStyle(color: isBuy ? AppColors.success : AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  Text(o['symbol'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.textMuted.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: const Text('CANCELLED', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${o['order_type'] == 'LIMIT' ? 'Limit' : 'Stop-Loss'} • ${o['quantity']} shares • Trigger: ₹${o['trigger_price']}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}