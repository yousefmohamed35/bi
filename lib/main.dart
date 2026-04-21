import 'dart:developer';
import 'package:educational_app/core/notification_service/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:screen_protector/screen_protector.dart';
import 'core/design/app_theme.dart';
import 'core/navigation/app_router.dart';
import 'core/config/theme_provider.dart';
import 'l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseNotification.initializeNotifications();
  log('FCM Token: ${FirebaseNotification.fcmToken}');

  // Initialize screen protection (prevent screenshots and screen recording)
  try {
    await ScreenProtector.protectDataLeakageOn();
    await ScreenProtector.preventScreenshotOn();
  } catch (e) {
    // Log error but don't prevent app from running
    debugPrint('Screen protection initialization error: $e');
  }

  // App config is intentionally disabled to avoid runtime dependency on it.

  // Initialize theme provider (singleton) and load preferences
  final themeProvider = ThemeProvider.instance;
  await themeProvider.ensureInitialized();

  runApp(EducationalApp(
    themeProvider: themeProvider,
  ));
}

class EducationalApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const EducationalApp({
    super.key,
    required this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'STP',
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final clampedScale =
                mediaQuery.textScaler.scale(1.0).clamp(0.9, 1.15);

            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(clampedScale),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },

          // RTL & Localization
          locale: themeProvider.locale,
          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],

          // Theme without app-config dependency
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: themeProvider.themeMode,

          // Router
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}
