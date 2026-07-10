import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  static WebSocketChannel? _channel;
  static final _priceController = StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get priceStream => _priceController.stream;

  static void connect() {
    if (_channel != null) return; // already connected
    try {
      _channel = WebSocketChannel.connect(Uri.parse('wss://adjimrxt3y.ap-south-1.awsapprunner.com/ws'));
      _channel!.stream.listen(
            (data) {
          try {
            final decoded = jsonDecode(data);
            if (decoded['type'] == 'price_update') {
              _priceController.add(Map<String, dynamic>.from(decoded['payload']));
            }
          } catch (_) {
            // ignore malformed messages
          }
        },
        onError: (_) => _reconnectLater(),
        onDone: () => _reconnectLater(),
      );
    } catch (_) {
      _reconnectLater();
    }
  }

  static void _reconnectLater() {
    _channel = null;
    Future.delayed(const Duration(seconds: 5), connect);
  }

  static void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}