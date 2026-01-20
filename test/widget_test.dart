import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/theme/theme_controller.dart';

void main() {
  testWidgets('SmartStay app loads successfully', (WidgetTester tester) async {
    // Create theme controller (same as main.dart)
    final themeController = ThemeController();

    // Load saved theme (safe for tests)
    await themeController.loadTheme();

    // Build the app
    await tester.pumpWidget(SmartStayApp(themeController: themeController));

    // Allow initial frames to settle
    await tester.pumpAndSettle();

    // Verify Login screen is shown
    expect(find.text('SmartStay'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
