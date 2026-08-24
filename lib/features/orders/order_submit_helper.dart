import 'package:dio/dio.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/features/orders/screens/buy_order_screen.dart';

/// TEMPORARY FIX (see stockpro-app notes): the real order engine
/// (POST /api/v1/orders, internal/orders on the backend) is not deployed
/// yet -- calling it returns 404. Until that backend module exists, every
/// screen that opens [OrderTicketScreen] goes through the legacy
/// synchronous endpoint (POST /api/v1/portfolio/orders) instead.
///
/// This endpoint gives no order id and no state machine -- a successful
/// call means the trade already executed (BUY/SELL happened against the
/// portfolio immediately), so we report a flat "Executed" status here.
/// There is no "Pending"/"Open" state and no tracking to wait for: swap
/// this helper back to OrderService.submit/trackToTerminal once
/// internal/orders is built and deployed.
///
/// The legacy endpoint's `price` field is `required,gt=0` server-side, even
/// though the server always overwrites it with its own live quote before
/// executing (see portfolio.Service.PlaceOrder) -- so any positive number
/// satisfies validation without affecting what the order actually fills at.
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
  );
}

/// Legacy endpoint always executes at the current live quote (it ignores
/// whatever price the client sends), so a "LIMIT" order placed through
/// this fallback executes immediately at market price rather than resting
/// on the book until the limit price is hit. Kept as a separate function
/// name so call sites don't change, and so the real LIMIT behaviour is a
/// one-line swap once internal/orders exists.
Future<OrderSubmitResult> submitLimitOrderThroughEngine({
  required String stockId,
  required String side, // BUY | SELL
  required double quantity,
  required double limitPrice,
  String productType = 'REGULAR',
}) {
  return _submitLegacy(
    stockId: stockId,
    side: side,
    quantity: quantity,
    price: limitPrice > 0 ? limitPrice : 1,
    productType: productType,
  );
}

Future<OrderSubmitResult> _submitLegacy({
  required String stockId,
  required String side,
  required double quantity,
  required double price,
  String productType = 'REGULAR',
}) async {
  try {
    await ApiService.placeOrder(
      stockId,
      side,
      quantity.round(),
      price,
      productType: productType,
    );
  } on DioException catch (e) {
    final serverMsg = e.response?.data is Map ? (e.response?.data['error']?.toString()) : null;
    throw Exception(serverMsg ?? e.message ?? 'Order failed');
  }
  return const OrderSubmitResult(status: 'Executed', orderId: null);
}
