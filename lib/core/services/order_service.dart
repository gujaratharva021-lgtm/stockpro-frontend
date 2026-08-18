import 'dart:async';
import 'dart:math';

import 'package:stock_app/core/models/order.dart';
import 'package:stock_app/core/services/api_service.dart';
import 'package:stock_app/core/services/websocket_service.dart';

/// Thrown when an order was accepted by the engine but did not reach a
/// terminal state before we gave up watching it. This is NOT the same as
/// the order failing -- the order may still fill later. Callers should
/// tell the user to check the order book rather than "your order failed".
class OrderTrackingTimeout implements Exception {
  final Order lastKnown;
  OrderTrackingTimeout(this.lastKnown);
}

/// Submits orders through the real order engine (POST /orders) and tracks
/// them to a terminal state (FILLED / REJECTED / CANCELLED / EXPIRED /
/// FAILED), instead of ever treating "the HTTP call returned" as "the order
/// executed".
///
/// Two independent signals feed the tracking, whichever arrives first wins:
///  1. The order_update push over the websocket (fast path -- usually
///     sub-second for a simulated/market fill).
///  2. A polling fallback against GET /orders/:id (safety net for a missed
///     or delayed WS message, a backgrounded app, or a dropped connection).
class OrderService {
  static final _rng = Random.secure();

  /// A fresh idempotency key per submit attempt. Generating this once per
  /// user tap (not per HTTP retry) is what lets Dio's retry-on-timeout
  /// behavior, or a user's frustrated double-tap, safely resolve to the
  /// same underlying order instead of two real orders.
  static String newIdempotencyKey() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Places an order and returns as soon as the engine has *accepted* it
  /// (i.e. the HTTP call succeeded) -- this is deliberately NOT the final
  /// state. Use [trackToTerminal] (or [placeAndTrack]) to find out what
  /// actually happened to it.
  static Future<Order> submit({
    required String stockId,
    required String side,
    String orderType = 'MARKET',
    String productType = 'REGULAR',
    required double quantity,
    double? limitPrice,
  }) async {
    final data = await ApiService.placeEngineOrder(
      stockId: stockId,
      side: side,
      orderType: orderType,
      productType: productType,
      quantity: quantity,
      limitPrice: limitPrice,
      idempotencyKey: newIdempotencyKey(),
    );
    return Order.fromJson(data['order'] as Map<String, dynamic>);
  }

  /// Watches [order] until it reaches a terminal status, emitting every
  /// intermediate update along the way (e.g. OPEN -> PARTIALLY_FILLED ->
  /// FILLED). Combines the WS push with a polling fallback so a dropped
  /// connection never leaves the UI stuck showing "Submitting...".
  ///
  /// [pollInterval] governs the fallback poll cadence; [timeout] is a hard
  /// ceiling after which the stream closes with an [OrderTrackingTimeout]
  /// error -- at that point the order itself may still resolve later, we
  /// have just stopped watching it here.
  static Stream<Order> trackToTerminal(
    Order order, {
    Duration pollInterval = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 30),
  }) {
    late StreamController<Order> controller;
    StreamSubscription? wsSub;
    Timer? pollTimer;
    Timer? timeoutTimer;
    Order latest = order;
    var closed = false;

    void finish([Object? error]) {
      if (closed) return;
      closed = true;
      wsSub?.cancel();
      pollTimer?.cancel();
      timeoutTimer?.cancel();
      if (error != null) {
        controller.addError(error);
      }
      controller.close();
    }

    void emit(Order updated) {
      if (closed) return;
      latest = updated;
      controller.add(updated);
      if (updated.isTerminal) finish();
    }

    controller = StreamController<Order>(
      onListen: () {
        if (order.isTerminal) {
          emit(order);
          return;
        }

        wsSub = WebSocketService.orderUpdateStream.listen((payload) {
          if (payload['id']?.toString() != order.id) return;
          emit(Order.fromJson(payload));
        });

        pollTimer = Timer.periodic(pollInterval, (_) async {
          if (closed) return;
          try {
            final data = await ApiService.getEngineOrder(order.id);
            final fetched = Order.fromJson(data['order'] as Map<String, dynamic>);
            emit(fetched);
          } catch (_) {
            // Transient network hiccup -- the next poll tick (or a WS
            // push) will pick it back up. Don't fail the whole stream
            // over one missed poll.
          }
        });

        timeoutTimer = Timer(timeout, () => finish(OrderTrackingTimeout(latest)));
      },
      onCancel: () {
        wsSub?.cancel();
        pollTimer?.cancel();
        timeoutTimer?.cancel();
      },
    );

    return controller.stream;
  }

  /// Convenience wrapper: places the order, then waits for it to reach a
  /// terminal state and returns that final [Order]. Prefer [trackToTerminal]
  /// directly when the UI wants to show intermediate states (e.g. "Open,
  /// waiting for fill...") rather than just a spinner.
  static Future<Order> placeAndTrack({
    required String stockId,
    required String side,
    String orderType = 'MARKET',
    String productType = 'REGULAR',
    required double quantity,
    double? limitPrice,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final placed = await submit(
      stockId: stockId,
      side: side,
      orderType: orderType,
      productType: productType,
      quantity: quantity,
      limitPrice: limitPrice,
    );
    return await trackToTerminal(placed, timeout: timeout).last;
  }

  static Future<Order> cancel(String orderId) async {
    final data = await ApiService.cancelEngineOrder(orderId);
    return Order.fromJson(data['order'] as Map<String, dynamic>);
  }

  static Future<Order> getOrder(String orderId) async {
    final data = await ApiService.getEngineOrder(orderId);
    return Order.fromJson(data['order'] as Map<String, dynamic>);
  }

  static Future<List<Order>> listOrders({int? limit}) async {
    final list = await ApiService.listEngineOrders(limit: limit);
    return list.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }
}
