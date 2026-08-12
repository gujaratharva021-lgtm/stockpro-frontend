import 'dart:async';
import 'dart:convert';
import 'package:stock_app/core/services/api_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Owns the single authenticated websocket connection to the backend hub
/// (pkg/websocket/hub.go). Handles both broadcast messages (price_update)
/// and per-user messages (order_update, alert).
///
/// Connecting requires a short-lived single-use ticket (see
/// ApiService.getWsTicket) rather than putting the JWT in the URL -- the
/// ticket is fetched fresh on every connect/reconnect attempt since it
/// expires after ~30 seconds and can only be used once.
class WebSocketService {
  static WebSocketChannel? _channel;
  static bool _connecting = false;
  static bool _wantConnected = false;
  static int _reconnectAttempt = 0;

  static final _priceController = StreamController<Map<String, dynamic>>.broadcast();
  static final _orderController = StreamController<Map<String, dynamic>>.broadcast();

  /// Raw price_update payloads (unchanged from before).
  static Stream<Map<String, dynamic>> get priceStream => _priceController.stream;

  /// Raw order_update payloads -- each is a JSON-decoded `orders.Order`
  /// (see lib/core/models/order.dart for the typed shape). Emitted every
  /// time an order this user owns changes state on the backend, so a
  /// screen tracking one order should filter this stream by order id
  /// rather than assuming every event is theirs.
  static Stream<Map<String, dynamic>> get orderUpdateStream => _orderController.stream;

  /// Connects (or reconnects) the websocket. Safe to call multiple times --
  /// a connect already in flight or already open is a no-op. Call this once
  /// the user is authenticated (splash screen with a stored token, or right
  /// after login/signup) and call [disconnect] on logout.
  static Future<void> connect() async {
    _wantConnected = true;
    if (_channel != null || _connecting) return;
    _connecting = true;
    try {
      final ticket = await ApiService.getWsTicket();
      if (!_wantConnected) return; // logged out while the ticket request was in flight
      final uri = Uri.parse(ApiService.wsUrl).replace(queryParameters: {'ticket': ticket});
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _reconnectAttempt = 0;
      channel.stream.listen(
        _handleMessage,
        onError: (_) => _handleDisconnect(),
        onDone: () => _handleDisconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _channel = null;
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  static void _handleMessage(dynamic data) {
    try {
      final decoded = jsonDecode(data as String);
      final type = decoded['type'];
      final payload = decoded['payload'];
      if (payload is! Map) return;
      if (type == 'price_update') {
        _priceController.add(Map<String, dynamic>.from(payload));
      } else if (type == 'order_update') {
        _orderController.add(Map<String, dynamic>.from(payload));
      }
    } catch (_) {
      // ignore malformed messages
    }
  }

  static void _handleDisconnect() {
    _channel = null;
    if (_wantConnected) _scheduleReconnect();
  }

  static void _scheduleReconnect() {
    // Capped exponential backoff (5s, 10s, 20s, ... up to 60s) so a
    // prolonged backend outage doesn't hammer the server with reconnects.
    _reconnectAttempt++;
    final backoffSteps = _reconnectAttempt.clamp(1, 4); // caps the shift below at 2^3
    final delaySeconds = 5 * (1 << (backoffSteps - 1));
    Future.delayed(Duration(seconds: delaySeconds), () {
      if (_wantConnected && _channel == null) connect();
    });
  }

  static void disconnect() {
    _wantConnected = false;
    _channel?.sink.close();
    _channel = null;
  }
}
