import 'package:stock_app/core/models/order.dart';
import 'package:stock_app/core/services/order_service.dart';
import 'package:stock_app/features/orders/screens/buy_order_screen.dart';

/// Places a MARKET order through the real order engine and waits for it to
/// reach a terminal status before returning, instead of returning the
/// instant the HTTP request completes. Shared by every screen that opens
/// [OrderTicketScreen] for a MARKET order (orders_screen, stock_detail,
/// stock_quote_sheet) so they all get the same honest behaviour:
///
///  - FILLED / PARTIALLY_FILLED at the timeout -> returns normally with a
///    status label reflecting what actually happened.
///  - REJECTED / CANCELLED / FAILED -> throws, so it surfaces through the
///    existing error-handling path in OrderTicketScreen (shown to the user
///    as a real failure, not a fake success dialog).
///  - Still OPEN/pending when tracking gives up (timeout) -> returns
///    "Pending" rather than claiming it executed; the user can check the
///    order in Orders later.
Future<OrderSubmitResult> submitMarketOrderAndTrack({
  required String stockId,
  required String side, // BUY | SELL
  required double quantity,
  String productType = 'REGULAR',
}) {
  return _submitAndTrack(
    stockId: stockId,
    side: side,
    orderType: 'MARKET',
    quantity: quantity,
    productType: productType,
  );
}

/// Places a LIMIT order through the real order engine and waits for it to
/// reach a terminal status (or times out) before returning, mirroring
/// [submitMarketOrderAndTrack]. A LIMIT order that is still OPEN (resting
/// on the book, not yet matched) when tracking gives up is reported with
/// its actual status label rather than a blanket "Pending" -- it genuinely
/// is open, not just unconfirmed.
Future<OrderSubmitResult> submitLimitOrderThroughEngine({
  required String stockId,
  required String side, // BUY | SELL
  required double quantity,
  required double limitPrice,
  String productType = 'REGULAR',
}) {
  return _submitAndTrack(
    stockId: stockId,
    side: side,
    orderType: 'LIMIT',
    quantity: quantity,
    limitPrice: limitPrice,
    productType: productType,
  );
}

Future<OrderSubmitResult> _submitAndTrack({
  required String stockId,
  required String side,
  required String orderType,
  required double quantity,
  double? limitPrice,
  String productType = 'REGULAR',
}) async {
  final placed = await OrderService.submit(
    stockId: stockId,
    side: side,
    orderType: orderType,
    productType: productType,
    quantity: quantity,
    limitPrice: limitPrice,
  );

  Order finalOrder = placed;
  try {
    finalOrder = await OrderService.trackToTerminal(placed).last;
  } on OrderTrackingTimeout catch (e) {
    finalOrder = e.lastKnown;
  } catch (_) {
    // Tracking itself failed (e.g. network drop mid-poll) -- fall back to
    // one direct status check rather than silently reporting the order as
    // executed when we simply lost track of it.
    try {
      finalOrder = await OrderService.getOrder(placed.id);
    } catch (_) {
      // Still couldn't confirm -- be honest that we don't know, don't
      // claim success.
      return OrderSubmitResult(status: 'Pending', orderId: placed.id);
    }
  }

  if (finalOrder.isRejectedOrFailed) {
    throw Exception(finalOrder.rejectReason ?? 'Order ${OrderStatus.label(finalOrder.status).toLowerCase()}');
  }
  if (finalOrder.isCancelled) {
    throw Exception('Order was cancelled');
  }
  if (finalOrder.isFilled) {
    return OrderSubmitResult(status: 'Executed', orderId: finalOrder.id);
  }
  // OPEN / PARTIALLY_FILLED / still mid-flight when we stopped watching.
  return OrderSubmitResult(status: OrderStatus.label(finalOrder.status), orderId: finalOrder.id);
}
