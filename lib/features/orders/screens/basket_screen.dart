import 'package:flutter/material.dart';
import 'package:stock_app/core/models/order.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/services/order_service.dart';
import 'package:stock_app/core/theme/app_colors.dart';
import 'package:stock_app/features/stock_detail/screens/basket_service.dart';

class BasketScreen extends StatefulWidget {
  const BasketScreen({super.key});
  @override
  State<BasketScreen> createState() => _BasketScreenState();
}

class _BasketScreenState extends State<BasketScreen> {
  final BasketService _basketService = BasketService();
  bool _executing = false;

  void _createBasket() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Basket'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Tech Stocks, Banking...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _basketService.createBasket(controller.text.trim());
                setState(() {});
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeBasket(Basket basket) async {
    if (basket.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Basket is empty')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Execute ${basket.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buy ${basket.items.length} stocks for approximately ₹${basket.totalValue.toStringAsFixed(2)}?'),
            const SizedBox(height: 6),
            const Text(
              'Prices shown are estimates from when items were added. Actual execution price for each stock may differ slightly at the time of order placement.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            ...basket.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(item.symbol, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${item.quantity} × ₹${item.price.toStringAsFixed(2)}'),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buy All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _executing = true);
    int success = 0;
    int failed = 0;

    // Fetch all fresh quotes concurrently -- this was previously one
    // sequential network round-trip per item, which made a large basket
    // slow and meant a single slow/failed quote blocked every item after it.
    final quotes = await Future.wait(
      basket.items.map((item) async {
        try {
          return await ApiService.getQuote(item.symbol);
        } catch (_) {
          return null;
        }
      }),
    );

    for (var i = 0; i < basket.items.length; i++) {
      final item = basket.items[i];
      final freshQuote = quotes[i];
      try {
        if (freshQuote == null) {
          failed++;
          continue;
        }
        final rawPrice = freshQuote['price'];
        if (rawPrice is! num) {
          failed++;
          continue;
        }
        final placed = await OrderService.submit(
          stockId: item.stockId,
          side: 'BUY',
          quantity: item.quantity.toDouble(),
        );
        Order finalOrder = placed;
        try {
          finalOrder = await OrderService.trackToTerminal(placed).last;
        } on OrderTrackingTimeout catch (e) {
          finalOrder = e.lastKnown;
        } catch (_) {
          finalOrder = await OrderService.getOrder(placed.id);
        }
        if (finalOrder.isRejectedOrFailed || finalOrder.isCancelled) {
          failed++;
        } else {
          success++;
        }
      } catch (_) {
        failed++;
      }
    }

    setState(() => _executing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failed == 0
              ? '$success orders placed successfully!'
              : '$success orders placed, $failed failed'),
          backgroundColor: failed == 0 ? AppColors.success : AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final baskets = _basketService.baskets;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          if (baskets.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_basket_outlined, color: AppColors.textMuted, size: 48),
                    const SizedBox(height: 12),
                    const Text('No baskets yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    const SizedBox(height: 6),
                    const Text('Create a basket and add stocks to buy together', style: TextStyle(color: AppColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _createBasket,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Create Basket', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: baskets.length,
                itemBuilder: (context, index) {
                  final basket = baskets[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.shopping_basket_outlined, color: AppColors.primaryDark, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(basket.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text('${basket.items.length} stocks • ₹${basket.totalValue.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                onPressed: () {
                                  _basketService.deleteBasket(basket.id);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                        if (basket.items.isNotEmpty)
                          ...basket.items.map((item) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border, width: 0.5))),
                            child: Row(
                              children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                  child: Center(child: Text(item.symbol[0], style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: 12))),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.symbol, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text(item.companyName, style: const TextStyle(color: AppColors.textMuted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${item.quantity} shares', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    Text('₹${(item.quantity * item.price).toStringAsFixed(0)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: AppColors.textMuted, size: 16),
                                  onPressed: () {
                                    _basketService.removeFromBasket(basket.id, item.symbol);
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                          )),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _executing || basket.items.isEmpty ? null : () => _executeBasket(basket),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _executing
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text('Execute Basket • ₹${basket.totalValue.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: baskets.isNotEmpty
          ? FloatingActionButton(
              onPressed: _createBasket,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
