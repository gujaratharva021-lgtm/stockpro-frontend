import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_app/features/auth/screens/splash_screen.dart';
import 'package:stock_app/features/auth/screens/login_screen.dart';
import 'package:stock_app/features/auth/screens/signup_screen.dart';
import 'package:stock_app/features/watchlist/screens/watchlist_screen.dart';
import 'package:stock_app/features/ipo/screens/ipo_screen.dart';
import 'package:stock_app/features/portfolio/screens/portfolio_screen.dart';
import 'package:stock_app/features/news/screens/news_screen.dart';

import 'package:provider/provider.dart';
import 'package:stock_app/core/theme/app_theme.dart';
import 'package:stock_app/core/theme/theme_provider.dart';
import 'package:stock_app/features/onboarding/screens/onboarding_flow.dart';
import 'package:stock_app/features/onboarding/screens/kyc_success_screen.dart';
import 'package:stock_app/features/profile/screens/profile_screen.dart';
import 'package:stock_app/features/compare/screens/compare_screen.dart';
import 'package:stock_app/features/heatmap/screens/heatmap_screen.dart';
import 'package:stock_app/features/tax/screens/tax_report_screen.dart';
import 'package:stock_app/features/orders/screens/pending_orders_screen.dart';
import 'package:stock_app/features/calculator/screens/brokerage_calculator_screen.dart';
import 'package:stock_app/features/screener/screens/screener_screen.dart';
import 'package:stock_app/features/portfolio/screens/performance_screen.dart';
import 'package:stock_app/features/assistant/screens/assistant_screen.dart';
import 'package:stock_app/features/auth/screens/forgot_password_screen.dart';
import 'package:stock_app/features/fiidii/screens/fiidii_screen.dart';
import 'package:stock_app/features/notifications/screens/notifications_screen.dart';
import 'package:stock_app/features/smallcase/screens/smallcase_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:stock_app/features/mutualfunds/screens/sip_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    GoRoute(path: '/watchlist', builder: (context, state) => const WatchlistScreen()),
    GoRoute(path: '/ipo', builder: (context, state) => const IpoScreen()),
    GoRoute(path: '/portfolio', builder: (context, state) => const PortfolioScreen()),
    GoRoute(path: '/news', builder: (context, state) => const NewsScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingFlow()),
    GoRoute(path: '/kyc-success', builder: (context, state) => const KycSuccessScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(path: '/compare', builder: (context, state) => const CompareScreen()),
    GoRoute(path: '/heatmap', builder: (context, state) => const HeatmapScreen()),
    GoRoute(path: '/tax-report', builder: (context, state) => const TaxReportScreen()),
    GoRoute(path: '/pending-orders', builder: (context, state) => const PendingOrdersScreen()),
    GoRoute(path: '/brokerage-calculator', builder: (context, state) => const BrokerageCalculatorScreen()),
    GoRoute(path: '/screener', builder: (context, state) => const ScreenerScreen()),
    GoRoute(path: '/performance', builder: (context, state) => const PerformanceScreen()),
    GoRoute(path: '/assistant', builder: (context, state) => const AssistantScreen()),
    GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
    GoRoute(path: '/fii-dii', builder: (context, state) => const FiiDiiScreen()),
    GoRoute(path: '/smallcase', builder: (context, state) => const SmallcaseScreen()),
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
    GoRoute(path: '/sip', builder: (context, state) => const SipScreen()),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'StockPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light().copyWith(
        textTheme: GoogleFonts.notoSansTextTheme(AppTheme.light().textTheme),
      ),
      routerConfig: _router,
    );
  }
}