import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _introController;
  late AnimationController _orbitController;
  late AnimationController _lineController;
  late AnimationController _dotsController;
  late AnimationController _timerController;
  late AnimationController _marqueeController;
  final ScrollController _tickerScrollController = ScrollController();

  static const _bgTop = Color(0xFF0B0F19);
  static const _bgBottom = Color(0xFF151C2C);

  final List<Map<String, dynamic>> _tickerItems = const [
    {'sym': 'NIFTY 50', 'val': '24,180.45', 'chg': '+0.42%', 'up': true},
    {'sym': 'SENSEX', 'val': '79,540.12', 'chg': '+0.38%', 'up': true},
    {'sym': 'RELIANCE', 'val': '1,305.70', 'chg': '-0.21%', 'up': false},
    {'sym': 'TCS', 'val': '3,654.20', 'chg': '+0.85%', 'up': true},
    {'sym': 'HDFCBANK', 'val': '1,623.45', 'chg': '-0.34%', 'up': false},
    {'sym': 'INFY', 'val': '1,456.80', 'chg': '+1.12%', 'up': true},
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _marqueeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _marqueeController.addListener(() {
      if (_tickerScrollController.hasClients) {
        _tickerScrollController.jumpTo(_tickerScrollController.offset + 0.7);
      }
    });

    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );
    _timerController.addStatusListener(_onTimerStatus);

    _lineController.forward();
    _introController.forward();
    _timerController.forward();
  }

  Future<void> _onTimerStatus(AnimationStatus status) async {
    if (status != AnimationStatus.completed) return;
    if (!mounted) return;
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');
    if (!mounted) return;
    if (token == null) {
      context.go('/login');
    } else {
      context.go('/home');
    }
  }

  double _eased(double t, double begin, double end, Curve curve) {
    if (t <= begin) return 0;
    if (t >= end) return 1;
    return curve.transform((t - begin) / (end - begin));
  }



  @override
  void dispose() {
    _introController.dispose();
    _orbitController.dispose();
    _lineController.dispose();
    _dotsController.dispose();
    _timerController.dispose();
    _marqueeController.dispose();
    _tickerScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgTop,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_bgTop, _bgBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Single dramatic breakout line, corner to corner
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _lineController,
              builder: (_, __) => CustomPaint(
                painter: _BreakoutLinePainter(
                  progress: _lineController.value,
                  lineColor: AppColors.primary,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_bgTop, Color(0x000B0F19), Color(0xCC0B0F19)],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 14),
                _buildTicker(),
                Expanded(child: Center(child: _buildLogoBlock())),
                const SizedBox(height: 28),
                _buildDotsLoader(),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicker() {
    return SizedBox(
      height: 30,
      child: ListView.builder(
        controller: _tickerScrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 400,
        itemBuilder: (context, index) {
          final item = _tickerItems[index % _tickerItems.length];
          final up = item['up'] as bool;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item['sym'] as String,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item['val'] as String,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(width: 4),
                Icon(
                  up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  size: 14,
                  color: up ? AppColors.success : AppColors.danger,
                ),
                Text(
                  item['chg'] as String,
                  style: TextStyle(
                    color: up ? AppColors.success : AppColors.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogoBlock() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 180,
          height: 180,
          child: AnimatedBuilder(
            animation: Listenable.merge([_orbitController, _introController]),
            builder: (_, __) {
              final introT = _introController.value.clamp(0.0, 1.0);
              final scale = Curves.elasticOut.transform(introT);
              final fade = _eased(introT, 0.0, 0.45, Curves.easeIn);
              final angleBase = _orbitController.value * 2 * math.pi;

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Orbiting particles
                  ...List.generate(3, (i) {
                    final angle = angleBase + i * (2 * math.pi / 3);
                    final radius = 78.0;
                    final dx = radius * math.cos(angle);
                    final dy = radius * math.sin(angle) * 0.55;
                    final dotSize = i == 0 ? 9.0 : 6.0;
                    return Opacity(
                      opacity: fade,
                      child: Transform.translate(
                        offset: Offset(dx, dy),
                        child: Container(
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.7),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  // Faint orbit ring guide
                  Opacity(
                    opacity: 0.12 * fade,
                    child: Container(
                      width: 156,
                      height: 86,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
                  // Core logo
                  Opacity(
                    opacity: fade,
                    child: Transform.scale(
                      scale: 0.5 + 0.5 * scale,
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.45),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.trending_up,
                            color: Colors.white, size: 44),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: _introController,
          builder: (_, __) {
            final t = _introController.value.clamp(0.0, 1.0);
            final ev = _eased(t, 0.25, 0.6, Curves.easeOutCubic);
            return Opacity(
              opacity: ev,
              child: Transform.translate(
                offset: Offset(0, 14 * (1 - ev)),
                child: const Text(
                  'StockPro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            );
          },
        ),
        ],
    );
  }



  Widget _buildDotsLoader() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_dotsController.value + i * 0.22) % 1.0;
            final dy = -9 * math.sin(t * math.pi);
            final opacity = 0.4 + 0.6 * math.sin(t * math.pi);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(opacity.clamp(0.4, 1.0)),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _BreakoutLinePainter extends CustomPainter {
  final double progress;
  final Color lineColor;

  _BreakoutLinePainter({required this.progress, required this.lineColor});

  static const List<Offset> _points = [
    Offset(0.0, 0.92),
    Offset(0.14, 0.82),
    Offset(0.26, 0.86),
    Offset(0.4, 0.64),
    Offset(0.52, 0.7),
    Offset(0.64, 0.46),
    Offset(0.78, 0.52),
    Offset(1.0, 0.2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final fullPath = Path();
    for (int i = 0; i < _points.length; i++) {
      final p = _points[i];
      final dx = p.dx * size.width;
      final dy = p.dy * size.height;
      if (i == 0) {
        fullPath.moveTo(dx, dy);
      } else {
        fullPath.lineTo(dx, dy);
      }
    }

    final metrics = fullPath.computeMetrics().toList();
    final revealPath = Path();
    for (final metric in metrics) {
      revealPath.addPath(metric.extractPath(0, metric.length * progress), Offset.zero);
    }

    final glowPaint = Paint()
      ..color = lineColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10);
    canvas.drawPath(revealPath, glowPaint);

    final linePaint = Paint()
      ..color = lineColor.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(revealPath, linePaint);

    // Dot at the leading tip of the line while drawing
    if (progress > 0.02 && progress < 1.0 && metrics.isNotEmpty) {
      final lastMetric = metrics.last;
      final tangent = lastMetric.getTangentForOffset(lastMetric.length * progress);
      if (tangent != null) {
        final dotPaint = Paint()..color = lineColor;
        canvas.drawCircle(tangent.position, 4, dotPaint);
        final dotGlow = Paint()
          ..color = lineColor.withOpacity(0.5)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
        canvas.drawCircle(tangent.position, 8, dotGlow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BreakoutLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}