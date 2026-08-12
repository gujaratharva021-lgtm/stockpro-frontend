/// Mirrors `orders.Order` from the Go order engine (internal/orders/models.go).
/// Never assume a placeOrder() call that returned 200 means the order is
/// FILLED -- always read `status` off this object instead of inferring
/// success from "the HTTP request didn't throw".
class Order {
  final String id;
  final String userId;
  final String stockId;
  final String symbol;
  final String side; // BUY | SELL
  final String orderType; // MARKET | LIMIT
  final String productType; // REGULAR | INTRADAY | MTF

  final double quantity;
  final double? limitPrice;
  final double? requestedPrice;
  final double filledQuantity;
  final double? avgFillPrice;

  final String status; // see OrderStatus below
  final String? rejectReason;

  final String broker;
  final String? brokerOrderId;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.userId,
    required this.stockId,
    required this.symbol,
    required this.side,
    required this.orderType,
    required this.productType,
    required this.quantity,
    this.limitPrice,
    this.requestedPrice,
    required this.filledQuantity,
    this.avgFillPrice,
    required this.status,
    this.rejectReason,
    required this.broker,
    this.brokerOrderId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) => v == null ? null : (v as num).toDouble();
    return Order(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      stockId: json['stock_id']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      side: json['side']?.toString() ?? '',
      orderType: json['order_type']?.toString() ?? '',
      productType: json['product_type']?.toString() ?? '',
      quantity: asDouble(json['quantity']) ?? 0,
      limitPrice: asDouble(json['limit_price']),
      requestedPrice: asDouble(json['requested_price']),
      filledQuantity: asDouble(json['filled_quantity']) ?? 0,
      avgFillPrice: asDouble(json['avg_fill_price']),
      status: json['status']?.toString() ?? OrderStatus.created,
      rejectReason: json['reject_reason']?.toString(),
      broker: json['broker']?.toString() ?? '',
      brokerOrderId: json['broker_order_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  bool get isTerminal => OrderStatus.terminal.contains(status);
  bool get isFilled => status == OrderStatus.filled;
  bool get isRejectedOrFailed => status == OrderStatus.rejected || status == OrderStatus.failed;
  bool get isCancelled => status == OrderStatus.cancelled;

  Order copyWith({String? status, double? filledQuantity, double? avgFillPrice, String? rejectReason}) {
    return Order(
      id: id,
      userId: userId,
      stockId: stockId,
      symbol: symbol,
      side: side,
      orderType: orderType,
      productType: productType,
      quantity: quantity,
      limitPrice: limitPrice,
      requestedPrice: requestedPrice,
      filledQuantity: filledQuantity ?? this.filledQuantity,
      avgFillPrice: avgFillPrice ?? this.avgFillPrice,
      status: status ?? this.status,
      rejectReason: rejectReason ?? this.rejectReason,
      broker: broker,
      brokerOrderId: brokerOrderId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Status string constants -- must match internal/orders/models.go exactly
/// (the backend state machine is the single source of truth for these).
class OrderStatus {
  static const created = 'CREATED';
  static const validating = 'VALIDATING';
  static const accepted = 'ACCEPTED';
  static const sentToBroker = 'SENT_TO_BROKER';
  static const open = 'OPEN';
  static const partiallyFilled = 'PARTIALLY_FILLED';
  static const filled = 'FILLED';
  static const rejected = 'REJECTED';
  static const cancelRequested = 'CANCEL_REQUESTED';
  static const cancelled = 'CANCELLED';
  static const expired = 'EXPIRED';
  static const failed = 'FAILED';

  static const terminal = {filled, rejected, cancelled, expired, failed};

  /// Short label for UI (snackbars, order list rows).
  static String label(String status) {
    switch (status) {
      case created:
      case validating:
      case accepted:
      case sentToBroker:
        return 'Submitting…';
      case open:
        return 'Open';
      case partiallyFilled:
        return 'Partially filled';
      case filled:
        return 'Filled';
      case rejected:
        return 'Rejected';
      case cancelRequested:
        return 'Cancelling…';
      case cancelled:
        return 'Cancelled';
      case expired:
        return 'Expired';
      case failed:
        return 'Failed';
      default:
        return status;
    }
  }
}
