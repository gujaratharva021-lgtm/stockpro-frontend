import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:stock_app/main.dart';
import 'package:stock_app/core/theme/theme_provider.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MyApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
  });
}