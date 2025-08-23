// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:anned_finds/main.dart';
import 'package:anned_finds/services/theme_service.dart';

void main() {
  testWidgets('App loads without errors', (WidgetTester tester) async {
    // Create a theme service for testing
    final themeService = ThemeService();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: themeService,
        child: const AnneDFindsApp(),
      ),
    );

    // Verify that the app loads without errors
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
