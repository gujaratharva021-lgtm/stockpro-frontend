import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/services/order_service.dart';
import 'package:stock_app/features/orders/screens/buy_order_screen.dart';

/// MARKET orders go through the legacy synchronous endpoint
/// (POST /api/v1/portfolio/orders): a successful call means the trade already
/// executed at the server's live quote (the `price` field only has to be > 0).
/// One idempotency key is generated per call (= per user tap), so a retried
/// request resolves to the same order instead of a duplicate trade.
Future<OrderSubmitResult> submitMarketOrderAndTrack({
  required String stockId,
  required String side, // BUY | SELL
  required double quantity,
  String productType = 'REGULAR',
}) {
  return _submitLegacy(
    stockId: stockId,
    side: side,
    quantity: quantity,
    price: 1, // placeholder -- server ignores this and uses its live quote
    productType: productType,
    idempotencyKey: OrderService.newIdempotencyKey(),
  );
}

/// LIMIT orders are placed as pending LIMIT orders that rest until the limit
/// price is hit (never executed immediately at market).
Future<OrderSubmitResult> submitLimitOrderThroughEngine({
  required String stockId,
  required String side, // BUY | SELL
  required double quantity,
  required double limitPrice,
  String productType = 'REGULAR',
}) async {
  if (limitPrice <= 0) throw Exception('Enter a valid limit price');
  try {
    await ApiService.createPendingOrder(stockId, side, 'LIMIT', quantity, limitPrice);
  } on DioException catch (e) {
    final serverMsg = e.response?.data is Map ? (e.response?.data['error']?.toString()) : null;
    throw Exception(serverMsg ?? e.message ?? 'Order failed');
  }
  return const OrderSubmitResult(status: 'Pending');
}

Future<OrderSubmitResult> _submitLegacy({
  required String stockId,
  required String side,
  required double quantity,
  required double price,
  required String idempotencyKey,
  String productType = 'REGULAR',
}) async {
  late Map<String, dynamic> res;
  try {
    res = await ApiService.placeOrder(
      stockId,
      side,
      quantity.round(),
      price,
      productType: productType,
      idempotencyKey: idempotencyKey,
    );
  } on DioException catch (e) {
    final serverMsg = e.response?.data is Map
        ? (e.response?.data['error']?.toString())
        : null;
    throw Exception(serverMsg ?? e.message ?? 'Order failed');
  }
  final txn = res['transaction'];
  final filled = txn is Map ? (txn['quantity'] as num?)?.toDouble() : null;
  return OrderSubmitResult(
    status: 'Executed',
    orderId: null,
    filledQty: filled,
  );
}