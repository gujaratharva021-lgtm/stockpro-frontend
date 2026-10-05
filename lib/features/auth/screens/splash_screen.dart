import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:stock_app/core/services/websocket_service.dart';
import 'package:stock_app/core/services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _bg = Colors.black;
  AnimationController? _lottieController;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _lottieController?.dispose();
    super.dispose();
  }

  Future<void> _navigateNext() async {
    if (_navigated) return;
    _navigated = true;
    if (!mounted) return;
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');
    if (!mounted) return;
    if (token == null) {
      context.go('/login');
    } else {
      WebSocketService.connect(); // fire-and-forget: order/price updates start flowing in the background
      bool kycDone = true;
      try {
        final me = await ApiService.getMe().timeout(const Duration(seconds: 8));
        final user = me['user'];
        if (user is Map) kycDone = user['kyc_completed'] == true;
      } catch (_) {}
      if (!mounted) return;
      final stillLoggedIn = await storage.read(key: 'auth_token');
      if (!mounted) return;
      if (stillLoggedIn == null) {
        context.go('/login');
      } else {
        context.go(kycDone ? '/dashboard' : '/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          SizedBox.expand(
            child: Lottie.asset(
              'assets/animations/splash_animation_v2.json',
              fit: BoxFit.cover,
              controller: _lottieController,
              onLoaded: (composition) {
                _lottieController = AnimationController(vsync: this, duration: composition.duration * 0.6)
                  ..addStatusListener((status) {
                    if (status == AnimationStatus.completed) _navigateNext();
                  })
                  ..forward();
                setState(() {});
              },
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  'OneInvest',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 4
                      ..color = Colors.black,
                  ),
                ),
                const Text(
                  'OneInvest',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
