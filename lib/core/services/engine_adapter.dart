import 'package:stock_app/core/services/api_service.dart';

/// Maps the order-engine calls onto real backend endpoints:
/// MARKET -> POST /portfolio/orders (synchronous, returns a transaction),
/// LIMIT  -> /pending-orders (create / list / delete).
class EngineAdapter {
  static String _status(String? s) {
    switch (s) {
      case 'EXECUTED':
        return 'FILLED';
      case 'CANCELLED':
        return 'CANCELLED';
      case 'REJECTED':
        return 'REJECTED';
      default:
        return 'OPEN';
    }
  }

  static Map<String, dynamic> _fromPending(Map<String, dynamic> o) {
    final status = _status(o['status']?.toString());
    return {
      'id': o['id'],
      'user_id': o['user_id'],
      'stock_id': o['stock_id'],
      'symbol': o['symbol'],
      'side': o['buy_sell'],
      'order_type': o['order_type'],
      'product_type': o['product_type'],
      'quantity': o['quantity'],
      'limit_price': o['trigger_price'],
      'filled_quantity': status == 'FILLED' ? o['quantity'] : 0,
      'status': status,
      'broker': 'SIM',
      'created_at': o['created_at'],
      'updated_at': o['executed_at'] ?? o['created_at'],
    };
  }

  static Future<Map<String, dynamic>> placeEngineOrder({
    required String stockId,
    required String side,
    required String idempotencyKey,
    String orderType = 'MARKET',
    String productType = 'REGULAR',
    required double quantity,
    double? limitPrice,
  }) async {
    if (orderType == 'MARKET') {
      final res = await ApiService.placeOrder(stockId, side, quantity.toInt(), 0.0, productType: productType);
      final t = Map<String, dynamic>.from(res['transaction'] as Map);
      return {
        'order': {
          'id': t['id'],
          'user_id': t['user_id'],
          'stock_id': t['stock_id'],
          'symbol': '',
          'side': t['buy_sell'],
          'order_type': 'MARKET',
          'product_type': productType,
          'quantity': t['quantity'],
          'filled_quantity': t['quantity'],
          'avg_fill_price': t['price'],
          'status': 'FILLED',
          'broker': 'SIM',
          'created_at': t['created_at'],
          'updated_at': t['created_at'],
        }
      };
    }
    await ApiService.createPendingOrder(stockId, side, orderType, quantity, limitPrice ?? 0);
    final list = await ApiService.getPendingOrders();
    for (final e in list) {
      final m = Map<String, dynamic>.from(e as Map);
      if (m['stock_id']?.toString() == stockId && m['buy_sell'] == side && m['status'] == 'PENDING') {
        return {'order': _fromPending(m)};
      }
    }
    throw Exception('order was created but could not be read back');
  }

  static Future<Map<String, dynamic>> getEngineOrder(String orderId) async {
    final list = await ApiService.getPendingOrders();
    for (final e in list) {
      final m = Map<String, dynamic>.from(e as Map);
      if (m['id']?.toString() == orderId) return {'order': _fromPending(m)};
    }
    throw Exception('order not found');
  }

  static Future<List<dynamic>> listEngineOrders({int? limit}) async {
    final list = await ApiService.getPendingOrders();
    final mapped = list.map((e) => _fromPending(Map<String, dynamic>.from(e as Map))).toList();
    return limit != null && mapped.length > limit ? mapped.sublist(0, limit) : mapped;
  }

  static Future<Map<String, dynamic>> cancelEngineOrder(String orderId) async {
    final cur = await getEngineOrder(orderId);
    await ApiService.cancelPendingOrder(orderId);
    final o = Map<String, dynamic>.from(cur['order'] as Map);
    o['status'] = 'CANCELLED';
    return {'order': o};
  }
}