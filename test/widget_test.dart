// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:educational_app/main.dart';
import 'package:educational_app/core/config/theme_provider.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    final themeProvider = ThemeProvider.instance;
    await themeProvider.ensureInitialized();

    // Build our app and trigger a frame.
    await tester.pumpWidget(EducationalApp(themeProvider: themeProvider));

    // Verify app launches without errors
    await tester.pumpAndSettle();
  });
}
