// Import necessary libraries
import 'dart:convert';
import 'dart:developer'; // For logging and debugging
import 'dart:math'
    show Random; // For generating random numbers (show only Random class)
import 'package:firebase_core/firebase_core.dart'; // Firebase core functionality
import 'package:firebase_messaging/firebase_messaging.dart'; // Firebase Cloud Messaging
import 'package:educational_app/firebase_options.dart'; // Firebase options
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Local notifications plugin
import 'package:educational_app/core/navigation/app_router.dart';
import 'package:educational_app/core/navigation/route_names.dart';

// Main class for handling Firebase notifications
/// Top-level background handler required by firebase_messaging
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  log('Background message received: ${message.messageId}');
  await FirebaseNotification.showBasicNotification(message);
}

class FirebaseNotification {
  // Firebase Messaging instance for handling FCM
  static final FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Local notifications plugin for showing notifications
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Variable to store the FCM token (device registration token)
  static String? fcmToken;
  static bool _isNavigatingToNotifications = false;
  static bool _isHandlingTap = false;

  // Android notification channel configuration (required for Android 8.0+)
  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // Channel ID (must be unique)
    'High Importance Notifications', // Channel name visible to user
    description:
        'This channel is used for important notifications.', // Channel description
    importance: Importance.high, // High importance for sound and alert
  );

  // Main initialization method for notifications
  static Future<void> initializeNotifications() async {
    // Ensure Firebase is initialized (defensive for any direct calls)
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    await requestNotificationPermission(); // Request user permission
    await getFcmToken(); // Get device FCM token
    await initializeLocalNotifications(); // Initialize local notifications
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Set up background message handler (when app is closed or in background)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Set up foreground message listener (when app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Received foreground message: ${message.messageId}'); // Log message receipt
      showBasicNotification(message); // Show local notification
    });

    // Open notifications screen when user taps an FCM notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleNotificationTapData(message.data);
    });

    // Handle notification tap when app is launched from terminated state
    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      handleNotificationTapData(initialMessage.data);
    }
  }

  // Initialize local notifications plugin
  static Future<void> initializeLocalNotifications() async {
    // Configuration for initializing local notifications
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android:
          AndroidInitializationSettings('@mipmap/ic_launcher'), // Android icon
      iOS: DarwinInitializationSettings(), // iOS settings
    );

    // Initialize the local notifications plugin
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) {
          _openNotificationsScreen();
          return;
        }

        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            final data = decoded['data'];
            if (data is Map<String, dynamic>) {
              handleNotificationTapData(data);
              return;
            }
            if (decoded['route'] is String) {
              _openRoute(decoded['route'] as String);
              return;
            }
          }
        } catch (e) {
          log('Failed to parse notification payload: $e');
        }

        _openNotificationsScreen();
      },
    );

    // Create notification channel for Android (required for Android 8.0+)
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // Request notification permissions from user
  static Future<void> requestNotificationPermission() async {
    final NotificationSettings settings = await messaging.requestPermission();
    log('Notification permission status: ${settings.authorizationStatus}'); // Log permission status
  }

  // Get and store the FCM token for this device
  static Future<void> getFcmToken() async {
    try {
      fcmToken = await messaging.getToken(); // Retrieve FCM token
      log('FCM Token: $fcmToken'); // Log the token for debugging

      // Listen for token refresh events (tokens can change)
      messaging.onTokenRefresh.listen((String newToken) {
        fcmToken = newToken; // Update stored token
        log('FCM Token refreshed: $newToken'); // Log token refresh
      });
    } catch (e) {
      log('Error getting FCM token: $e'); // Log any errors
    }
  }

  // Handle background messages (when app is closed or in background)
  // Random number generator for unique notification IDs
  static final Random random = Random();

  // Generate a random ID for notifications (prevents duplicate IDs)
  static int generateRandomId() {
    return random.nextInt(10000); // Generate random number between 0-9999
  }

  static Future<void> handleNotificationTapData(
    Map<String, dynamic>? data,
  ) async {
    if (_isHandlingTap) return;
    _isHandlingTap = true;
    try {
      final route = _resolveRouteFromData(data);
      if (route == null || route.isEmpty) {
        await _openNotificationsScreen();
        return;
      }
      await _openRoute(route);
    } catch (e) {
      log('Error handling notification tap: $e');
      await _openNotificationsScreen();
    } finally {
      _isHandlingTap = false;
    }
  }

  static String? _resolveRouteFromData(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return null;

    final dynamicRoute = _asString(data['route']) ??
        _asString(data['target_route']) ??
        _asString(data['screen']) ??
        _asString(data['target_screen']);

    if (_isAllowedRoute(dynamicRoute)) {
      return dynamicRoute;
    }

    final actionValue =
        _asString(data['action_value']) ?? _asString(data['target']);
    if (_isAllowedRoute(actionValue)) {
      return actionValue;
    }

    final actionType = (_asString(data['action_type']) ?? '').toLowerCase();
    switch (actionType) {
      case 'notifications':
      case 'notification':
        return RouteNames.notifications;
      case 'home':
        return RouteNames.home;
      case 'courses':
      case 'course':
        return RouteNames.courses;
      case 'live_courses':
      case 'live':
        return RouteNames.liveCourses;
      case 'downloads':
        return RouteNames.downloads;
      case 'certificates':
      case 'certificate':
        return RouteNames.certificates;
      case 'progress':
        return RouteNames.progress;
      case 'dashboard':
        return RouteNames.dashboard;
      case 'chat':
      case 'messages':
        return RouteNames.chatConversations;
      case 'exams':
        return RouteNames.exams;
      case 'my_exams':
        return RouteNames.myExams;
      default:
        return null;
    }
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    final parsed = value.toString().trim();
    return parsed.isEmpty ? null : parsed;
  }

  static bool _isAllowedRoute(String? route) {
    if (route == null) return false;
    const allowedRoutes = <String>{
      RouteNames.notifications,
      RouteNames.home,
      RouteNames.courses,
      RouteNames.progress,
      RouteNames.dashboard,
      RouteNames.liveCourses,
      RouteNames.downloads,
      RouteNames.certificates,
      RouteNames.exams,
      RouteNames.myExams,
      RouteNames.chatConversations,
      RouteNames.settings,
      RouteNames.enrolled,
    };
    return allowedRoutes.contains(route);
  }

  static Future<void> _openRoute(String route) async {
    // Give router a moment to attach when app is starting.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    AppRouter.router.go(route);
  }

  static Future<void> _openNotificationsScreen() async {
    if (_isNavigatingToNotifications) return;
    _isNavigatingToNotifications = true;
    try {
      await _openRoute(RouteNames.notifications);
    } catch (e) {
      log('Error opening notifications screen: $e');
    } finally {
      _isNavigatingToNotifications = false;
    }
  }

  // Display a basic local notification
  static Future<void> showBasicNotification(RemoteMessage message) async {
    try {
      // Notification details configuration for both platforms
      final NotificationDetails details = NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id, // Use predefined channel ID
          channel.name, // Use predefined channel name
          channelDescription: channel.description, // Channel description
          importance: Importance.high, // High importance level
          priority: Priority.high, // High priority for notification
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, // Show alert on iOS
          presentBadge: true, // Update app badge on iOS
          presentSound: true, // Play sound on iOS
        ),
      );

      // Display the notification using local notifications plugin
      await flutterLocalNotificationsPlugin.show(
        generateRandomId(), // Unique ID for notification
        message.notification?.title ?? 'No Title', // Title (with fallback)
        message.notification?.body ?? 'No Body', // Body (with fallback)
        details, // Platform-specific details
        payload: jsonEncode({
          'data': message.data,
        }),
      );

      log('Local notification shown successfully'); // Log success
    } catch (e) {
      log('Error showing local notification: $e'); // Log any errors
    }
  }
}
