import 'package:flutter_test/flutter_test.dart';
import 'package:rusend_next/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RusendNextApp());
    // Basic test to ensure app loads
    expect(find.text('Welcome to Rusend Next'), findsOneWidget);
  });
}
