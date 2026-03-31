import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:rusend_next/main.dart';
import 'package:rusend_next/providers/auth_provider.dart';
import 'package:rusend_next/providers/email_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => EmailProvider()),
        ],
        child: const RusendNextApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Welcome to Remail'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
