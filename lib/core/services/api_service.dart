import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stock_app/core/services/websocket_service.dart';
class ApiService {
  static const String host = 'adjimrxt3y.ap-south-1.awsapprunner.com';
  static const String baseUrl = 'https://$host/api/v1';
  static const String wsUrl = 'wss://$host/ws';
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
    sendTimeout: const Duration(seconds: 60),
  ));
  static const _storage = FlutterSecureStorage();
  static Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }
  static Future<void> saveToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }
  static Future<void> clearToken() async {
    await _storage.delete(key: 'auth_token');
    // Every logout path (explicit logout, account deletion, an expired-token
    // 401 caught by the interceptor below) funnels through here, so tearing
    // the websocket down in one place means no call site can forget it and
    // leave a stale authenticated connection open after the user signs out.
    WebSocketService.disconnect();
  }
  static bool _interceptorAdded = false;
  static Future<Dio> _authDio() async {
    if (!_interceptorAdded) {
      _interceptorAdded = true;
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            options.headers.remove('Authorization');
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Some endpoints (like delete-account) also return 401 for a
            // wrong password confirmation, which has nothing to do with
            // the auth token itself -- only clear the token when the
            // error is actually about the token/auth header, not a
            // in-request password check.
            final message = error.response?.data is Map
                ? (error.response!.data['error']?.toString().toLowerCase() ?? '')
                : '';
            final isPasswordCheck = message.contains('password');
            if (!isPasswordCheck) {
              await clearToken();
            }
          }
          handler.next(error);
        },
      ));
    }
    return _dio;
  }
  static Future<Map<String, dynamic>> signup(String email, String password, String name) async {
    final res = await _dio.post('/auth/signup', data: {
      'email': email,
      'password': password,
      'name': name,
    });
    return res.data;
  }
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return res.data;
  }
  static Future<Map<String, dynamic>> getMe() async {
    final dio = await _authDio();
    final res = await dio.get('/auth/me');
    return res.data;
  }
  static Future<void> completeKYC() async {
    final dio = await _authDio();
    await dio.post('/auth/complete-kyc');
  }
  static Future<String> uploadAvatar(String filePath) async {
    final dio = await _authDio();
    final formData = FormData.fromMap({
      'avatar': await MultipartFile.fromFile(filePath, filename: filePath.split('/').last),
    });
    final res = await dio.post('/auth/avatar', data: formData);
    return res.data['avatar_url'];
  }
  static Future<List<dynamic>> getStocks() async {
    final dio = await _authDio();
    final res = await dio.get('/stocks');
    return res.data['stocks'] ?? [];
  }
  static Future<Map<String, dynamic>> getQuote(String symbol) async {
    final dio = await _authDio();
    final res = await dio.get('/stocks/$symbol/quote');
    return res.data['quote'];
  }
  static Future<List<dynamic>> getHistory(String symbol) async {
    final dio = await _authDio();
    final res = await dio.get('/stocks/$symbol/history');
    return res.data['history'] ?? [];
  }
  static Future<List<dynamic>> getWatchlist({String? listName}) async {
    final dio = await _authDio();
    final res = await dio.get('/watchlist', queryParameters: listName != null ? {'list_name': listName} : null);
    return res.data['watchlist'] ?? [];
  }
  static Future<List<String>> getWatchlistNames() async {
    final dio = await _authDio();
    final res = await dio.get('/watchlist/lists');
    return List<String>.from(res.data['lists'] ?? ['My Watchlist']);
  }
  static Future<void> addToWatchlist(String stockId, {String? listName}) async {
    final dio = await _authDio();
    await dio.post('/watchlist', data: {'stock_id': stockId, if (listName != null) 'list_name': listName});
  }
  static Future<void> removeFromWatchlist(String stockId, {String? listName}) async {
    final dio = await _authDio();
    await dio.delete('/watchlist/$stockId', queryParameters: listName != null ? {'list_name': listName} : null);
  }
  static Future<List<dynamic>> getHoldings() async {
    final dio = await _authDio();
    final res = await dio.get('/portfolio/holdings');
    return res.data['holdings'] ?? [];
  }
  static Future<List<dynamic>> getPositions() async {
    final dio = await _authDio();
    final res = await dio.get('/portfolio/positions');
    return res.data['positions'] ?? [];
  }
  static Future<List<dynamic>> getTransactions() async {
    final dio = await _authDio();
    final res = await dio.get('/portfolio/transactions');
    return res.data['transactions'] ?? [];
  }
  static Future<Map<String, dynamic>> getTaxReport() async {
    final dio = await _authDio();
    final res = await dio.get('/portfolio/tax-report');
    return res.data;
  }
  static Future<Map<String, dynamic>> getPnLReport() async {
    final dio = await _authDio();
    final res = await dio.get('/portfolio/pnl-report');
    return res.data;
  }
  static Future<Map<String, dynamic>> getPerformance() async {
    final dio = await _authDio();
    final res = await dio.get('/portfolio/performance');
    return res.data;
  }
  /// Legacy synchronous endpoint. Kept only for any caller not yet migrated
  /// to [placeEngineOrder] -- new code should not call this. It gives no
  /// order id, no state machine, and no way to know whether an order that
  /// looked like it succeeded was actually FILLED, REJECTED, or still OPEN.
  static Future<Map<String, dynamic>> placeOrder(String stockId, String buySell, int quantity, double price, {String productType = 'REGULAR'}) async {
    final dio = await _authDio();
    final res = await dio.post('/portfolio/orders', data: {
      'stock_id': stockId,
      'buy_sell': buySell,
      'quantity': quantity,
      'price': price,
      'product_type': productType,
    });
    return res.data;
  }
  // ---------------------------------------------------------------------
  // Order engine (/api/v1/orders) -- state-machine-backed order placement.
  // See internal/orders on the backend. A successful response here means
  // "the order was accepted for processing", not "the order filled" --
  // callers must read the returned `status` field, and keep watching it
  // (via OrderTracker) until it reaches a terminal state.
  // ---------------------------------------------------------------------
  /// Places an order through the real order engine. [idempotencyKey] should
  /// be a fresh key per user tap (see OrderService.newIdempotencyKey) so a
  /// retried/timed-out request can never result in the order being placed
  /// twice -- the backend returns the original order instead.
  static Future<Map<String, dynamic>> placeEngineOrder({
    required String stockId,
    required String side, // BUY | SELL
    required String idempotencyKey,
    String orderType = 'MARKET',
    String productType = 'REGULAR',
    required double quantity,
    double? limitPrice,
  }) async {
    final dio = await _authDio();
    final res = await dio.post(
      '/orders',
      data: {
        'stock_id': stockId,
        'side': side,
        'order_type': orderType,
        'product_type': productType,
        'quantity': quantity,
        if (limitPrice != null) 'limit_price': limitPrice,
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return res.data;
  }
  /// Fetches the current state of a single order -- the fallback path when
  /// a WS order_update was missed (connection drop, backgrounded app, etc).
  static Future<Map<String, dynamic>> getEngineOrder(String orderId) async {
    final dio = await _authDio();
    final res = await dio.get('/orders/$orderId');
    return res.data;
  }
  static Future<List<dynamic>> listEngineOrders({int? limit}) async {
    final dio = await _authDio();
    final res = await dio.get('/orders', queryParameters: limit != null ? {'limit': limit} : null);
    return res.data['orders'] ?? [];
  }
  static Future<Map<String, dynamic>> cancelEngineOrder(String orderId) async {
    final dio = await _authDio();
    final res = await dio.post('/orders/$orderId/cancel');
    return res.data;
  }
  /// Exchanges the current auth token for a short-lived, single-use ticket
  /// to open the authenticated websocket connection at `/ws?ticket=...`,
  /// so the long-lived JWT never has to go in a URL (see auth.WsTicket on
  /// the backend). Tickets expire in ~30s and can only be used once.
  static Future<String> getWsTicket() async {
    final dio = await _authDio();
    final res = await dio.post('/ws-ticket');
    return res.data['ticket'] as String;
  }
  static Future<List<dynamic>> getPendingOrders() async {
    final dio = await _authDio();
    final res = await dio.get('/pending-orders');
    return res.data['orders'] ?? [];
  }
  static Future<void> createPendingOrder(String stockId, String buySell, String orderType, double quantity, double triggerPrice, {bool isGtt = false}) async {
    final dio = await _authDio();
    await dio.post('/pending-orders', data: {
      'stock_id': stockId,
      'buy_sell': buySell,
      'order_type': orderType,
      'quantity': quantity,
      'trigger_price': triggerPrice,
      'is_gtt': isGtt,
    });
  }
  static Future<void> cancelPendingOrder(String orderId) async {
    final dio = await _authDio();
    await dio.delete('/pending-orders/$orderId');
  }
  static Future<void> modifyPendingOrder(String orderId, {required double price, required int quantity}) async {
    final dio = await _authDio();
    await dio.patch('/pending-orders/$orderId', data: {
      'trigger_price': price,
      'quantity': quantity,
    });
  }
  static Future<double> getBalance() async {
    final result = await getMe();
    final user = result['user'] ?? {};
    return (user['balance'] as num?)?.toDouble() ?? 0.0;
  }
  static Future<Map<String, dynamic>> mtfOpenPosition(String stockId, String symbol, double quantity) async {
    final dio = await _authDio();
    final res = await dio.post('/mtf/open', data: {
      'stock_id': stockId,
      'symbol': symbol,
      'quantity': quantity,
    });
    return res.data['position'] ?? {};
  }
  static Future<void> mtfClosePosition(String positionId, String symbol) async {
    final dio = await _authDio();
    await dio.post('/mtf/close', data: {
      'position_id': positionId,
      'symbol': symbol,
    });
  }
  static Future<List<dynamic>> mtfGetPositions() async {
    final dio = await _authDio();
    final res = await dio.get('/mtf/positions');
    return res.data['positions'] ?? [];
  }
  static Future<List<dynamic>> getNews() async {
    final dio = await _authDio();
    final res = await dio.get('/news');
    return res.data['news'] ?? [];
  }
  static Future<List<dynamic>> getNotifications() async {
    final dio = await _authDio();
    final res = await dio.get('/notifications');
    return res.data['notifications'] ?? [];
  }
  static Future<void> markNotificationRead(String id) async {
    final dio = await _authDio();
    await dio.patch('/notifications/$id/read');
  }
  static Future<List<dynamic>> getAlerts() async {
    final dio = await _authDio();
    final res = await dio.get('/alerts');
    return res.data['alerts'] ?? [];
  }
  static Future<void> createAlert(String stockId, double targetPrice, String direction) async {
    final dio = await _authDio();
    await dio.post('/alerts', data: {
      'stock_id': stockId,
      'target_price': targetPrice,
      'direction': direction,
    });
  }
  static Future<List<dynamic>> getMutualFunds() async {
    final dio = await _authDio();
    final res = await dio.get('/mutualfunds');
    return res.data['funds'] ?? [];
  }
  static Future<Map<String, dynamic>> getMutualFundDetail(String fundId) async {
    final dio = await _authDio();
    final res = await dio.get('/mutualfunds/$fundId');
    return res.data['fund'];
  }
  static Future<List<dynamic>> getMyFunds() async {
    final dio = await _authDio();
    final res = await dio.get('/mutualfunds/portfolio');
    return res.data['funds'] ?? [];
  }
  static Future<void> placeFundOrder(String fundId, String buySell, double amount) async {
    final dio = await _authDio();
    await dio.post('/mutualfunds/orders', data: {
      'fund_id': fundId,
      'buy_sell': buySell,
      'amount': amount,
    });
  }
  static Future<List<dynamic>> getFDProducts() async {
    final dio = await _authDio();
    final res = await dio.get('/fd/products');
    return res.data['products'] ?? [];
  }
  static Future<List<dynamic>> getFDInvestments() async {
    final dio = await _authDio();
    final res = await dio.get('/fd/investments');
    return res.data['investments'] ?? [];
  }
  static Future<Map<String, dynamic>> investFD(String productId, double amount) async {
    final dio = await _authDio();
    final res = await dio.post('/fd/invest', data: {
      'product_id': productId,
      'amount': amount,
    });
    return res.data['investment'];
  }
  static Future<double> withdrawFD(String investmentId) async {
    final dio = await _authDio();
    final res = await dio.post('/fd/withdraw', data: {
      'investment_id': investmentId,
    });
    return (res.data['payout'] as num).toDouble();
  }
  static Future<List<dynamic>> getMTFPositions() async {
    final dio = await _authDio();
    final res = await dio.get('/mtf/positions');
    return res.data['positions'] ?? [];
  }
  static Future<Map<String, dynamic>> openMTFPosition(String stockId, String symbol, double quantity) async {
    final dio = await _authDio();
    final res = await dio.post('/mtf/open', data: {
      'stock_id': stockId,
      'symbol': symbol,
      'quantity': quantity,
    });
    return res.data['position'];
  }
  static Future<void> closeMTFPosition(String positionId, String symbol) async {
    final dio = await _authDio();
    await dio.post('/mtf/close', data: {
      'position_id': positionId,
      'symbol': symbol,
    });
  }
  static Future<List<dynamic>> getCommodities() async {
    final dio = await _authDio();
    final res = await dio.get('/commodity');
    return res.data['commodities'] ?? [];
  }
  static Future<List<dynamic>> getCommodityPortfolio() async {
    final dio = await _authDio();
    final res = await dio.get('/commodity/portfolio');
    return res.data['commodities'] ?? [];
  }
  static Future<Map<String, dynamic>> getCommodityDetail(String id) async {
    final dio = await _authDio();
    final res = await dio.get('/commodity/$id');
    return res.data['commodity'];
  }
  static Future<Map<String, dynamic>> placeCommodityOrder(String commodityId, String buySell, double amount) async {
    final dio = await _authDio();
    final res = await dio.post('/commodity/orders', data: {
      'commodity_id': commodityId,
      'buy_sell': buySell,
      'amount': amount,
    });
    return res.data['transaction'];
  }
  static Future<List<dynamic>> getETFs() async {
    final dio = await _authDio();
    final res = await dio.get('/etf');
    return res.data['etfs'] ?? [];
  }
  static Future<Map<String, dynamic>> getETFDetail(String etfId) async {
    final dio = await _authDio();
    final res = await dio.get('/etf/$etfId');
    return res.data['etf'];
  }
  static Future<List<dynamic>> getMyETFs() async {
    final dio = await _authDio();
    final res = await dio.get('/etf/portfolio');
    return res.data['etfs'] ?? [];
  }
  static Future<void> placeETFOrder(String etfId, String buySell, double amount) async {
    final dio = await _authDio();
    await dio.post('/etf/orders', data: {
      'etf_id': etfId,
      'buy_sell': buySell,
      'amount': amount,
    });
  }
  static Future<List<dynamic>> getIPOs() async {
    final dio = await _authDio();
    final res = await dio.get('/ipo');
    return res.data['ipos'] ?? [];
  }
  static Future<Map<String, dynamic>> getIPODetail(String ipoId) async {
    final dio = await _authDio();
    final res = await dio.get('/ipo/$ipoId');
    return res.data['ipo'];
  }
  static Future<List<dynamic>> getMyIPOApplications() async {
    final dio = await _authDio();
    final res = await dio.get('/ipo/applications');
    return res.data['applications'] ?? [];
  }
  static Future<void> applyIPO(String ipoId, int lots, String upiId) async {
    final dio = await _authDio();
    await dio.post('/ipo/apply', data: {
      'ipo_id': ipoId,
      'lots': lots,
      'upi_id': upiId,
    });
  }
  static Future<List<dynamic>> getFutures() async {
    final dio = await _authDio();
    final res = await dio.get('/fno/futures');
    return res.data['positions'] ?? [];
  }
  static Future<void> openFutures(String stockId, String symbol, String positionType, int lotSize) async {
    final dio = await _authDio();
    await dio.post('/fno/futures', data: {
      'stock_id': stockId,
      'symbol': symbol,
      'position_type': positionType,
      'lot_size': lotSize,
    });
  }
  static Future<void> closeFutures(String positionId, String symbol) async {
    final dio = await _authDio();
    await dio.post('/fno/futures/$positionId/close', data: {'symbol': symbol});
  }
  static Future<List<dynamic>> getOptions() async {
    final dio = await _authDio();
    final res = await dio.get('/fno/options');
    return res.data['positions'] ?? [];
  }
  static Future<void> buyOption(String stockId, String symbol, String optionType, double strikePrice, int lotSize, String expiryDate) async {
    final dio = await _authDio();
    await dio.post('/fno/options', data: {
      'stock_id': stockId,
      'symbol': symbol,
      'option_type': optionType,
      'strike_price': strikePrice,
      'lot_size': lotSize,
      'expiry_date': expiryDate,
    });
  }
  static Future<void> closeOption(String positionId, String symbol) async {
    final dio = await _authDio();
    await dio.post('/fno/options/$positionId/close', data: {'symbol': symbol});
  }
  static Future<void> forgotPassword(String email) async {
    await _dio.post(
      '/auth/forgot-password',
      data: {'email': email},
      options: Options(
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }
  static Future<List<dynamic>> getAngelOneHoldings() async {
    final dio = await _authDio();
    final res = await dio.get('/portfolio/angelone-holdings');
    return res.data['holdings'] ?? [];
  }
  static Future<Map<String, dynamic>> createPaymentOrder(double amount) async {
    final dio = await _authDio();
    final res = await dio.post('/payments/create-order', data: {'amount': amount});
    return res.data;
  }
  static Future<void> confirmPayment(String orderId, String paymentId, String signature, double amount) async {
    final dio = await _authDio();
    await dio.post('/payments/confirm', data: {
      'razorpay_order_id': orderId,
      'razorpay_payment_id': paymentId,
      'razorpay_signature': signature,
      'amount': amount,
    });
  }
  static Future<void> withdrawFunds(double amount) async {
    final dio = await _authDio();
    await dio.post('/payments/withdraw', data: {'amount': amount});
  }
  static Future<List<dynamic>> getWalletHistory() async {
    final dio = await _authDio();
    final res = await dio.get('/payments/history');
    return res.data['transactions'] ?? [];
  }
  static Future<void> deleteAccount(String password) async {
    final dio = await _authDio();
    await dio.delete('/auth/account', data: {'password': password});
  }
  static Future<void> resetPassword(String email, String otp, String newPassword) async {
    await _dio.post<Map<String, dynamic>>('/auth/reset-password', data: {
      'email': email,
      'otp': otp,
      'new_password': newPassword,
    });
  }
  static Future<void> createSIP(String fundId, double amount, String frequency, String nextDate) async {
    final dio = await _authDio();
    await dio.post('/mutualfunds/sip', data: {
      'fund_id': fundId,
      'amount': amount,
      'frequency': frequency,
      'next_date': nextDate,
    });
  }
  static Future<List<dynamic>> getSIPs() async {
    final dio = await _authDio();
    final res = await dio.get('/mutualfunds/sip');
    return res.data['sips'] ?? [];
  }
  static Future<void> cancelSIP(String sipId) async {
    final dio = await _authDio();
    await dio.delete('/mutualfunds/sip/$sipId');
  }
  static Future<List<dynamic>> getIntraday(String symbol, String interval) async {
    final dio = await _authDio();
    final res = await dio.get('/stocks/$symbol/intraday?interval=$interval');
    return res.data['history'] ?? [];
  }
  static Future<String> getAbout(String symbol) async {
    final dio = await _authDio();
    final res = await dio.get('/stocks/$symbol/about');
    return res.data['about'] as String? ?? '';
  }
	static Future<String> askAssistant(String message, {List<Map<String, String>> history = const []}) async {
		try {
			final dio = await _authDio();
			final res = await dio.post('/assistant/chat', data: {'message': message, 'history': history});
			return res.data['reply'] as String? ?? 'No response';
		} catch (e) {
			return 'Error: $e';
		}
	}
  static Future<List<dynamic>> getOptionChain(String symbol, String expiry) async {
    final dio = await _authDio();
    final res = await dio.get('/stocks/$symbol/options', queryParameters: {'expiry': expiry});
    return res.data['option_chain'] ?? [];
  }
}
