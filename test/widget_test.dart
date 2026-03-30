// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:educational_app/main.dart';
import 'package:educational_app/core/config/app_config_provider.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    // Create a config provider for testing
    final configProvider = AppConfigProvider();
    await configProvider.initialize();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(EducationalApp(configProvider: configProvider));

    // Verify app launches without errors
    await tester.pumpAndSettle();
  });
}
