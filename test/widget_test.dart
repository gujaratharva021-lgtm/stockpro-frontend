import 'package:flutter_test/flutter_test.dart';

import 'package:stock_app/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 5));
  });
}
