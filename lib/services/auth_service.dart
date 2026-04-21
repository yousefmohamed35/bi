import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../core/notification_service/notification_service.dart';
import '../models/auth_response.dart';
import 'token_storage_service.dart';

class EmailNotVerifiedException implements Exception {
  final String message;

  EmailNotVerifiedException(this.message);

  @override
  String toString() => 'Exception: $message';
}

/// Authentication Service
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  String _extractServerMessage(dynamic error, String fallback) {
    try {
      String raw = '';
      if (error is ApiException) {
        raw = error.responseBody?.trim().isNotEmpty == true
            ? error.responseBody!.trim()
            : error.message;
      } else {
        raw = error?.toString() ?? '';
      }

      final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(raw);
      if (match != null) {
        final errorJson = jsonDecode(match.group(0)!);
        final errors = errorJson['errors'];
        if (errors is Map) {
          for (final value in errors.values) {
            if (value is String && value.trim().isNotEmpty) {
              return value.trim();
            }
            if (value is List && value.isNotEmpty) {
              final first = value.first?.toString() ?? '';
              if (first.trim().isNotEmpty) {
                return first.trim();
              }
            }
          }
        }

        final parsed = (errorJson['message'] ?? errorJson['error'])?.toString();
        if (parsed != null && parsed.trim().isNotEmpty) {
          return parsed.trim();
        }
      }
      if (raw.trim().isNotEmpty) {
        return raw.trim();
      }
    } catch (_) {}
    return fallback;
  }

  bool isMissingEmailVerifiedTokenError(dynamic error) {
    try {
      String raw = '';
      if (error is ApiException) {
        raw = error.responseBody?.trim().isNotEmpty == true
            ? error.responseBody!.trim()
            : error.message;
      } else {
        raw = error?.toString() ?? '';
      }

      final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(raw);
      if (match == null) return false;
      final errorJson = jsonDecode(match.group(0)!);
      final errors = errorJson['errors'];
      if (errors is! Map) return false;

      final tokenError = errors['email_verified_token'];
      if (tokenError is String && tokenError.trim().isNotEmpty) {
        final hasOtherErrors = errors.entries.any((entry) {
          if (entry.key == 'email_verified_token') return false;
          final value = entry.value;
          if (value is String) return value.trim().isNotEmpty;
          if (value is List) return value.isNotEmpty;
          return value != null;
        });
        return !hasOtherErrors;
      }
    } catch (_) {}
    return false;
  }

  bool _isEmailNotVerifiedMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('confirm') ||
        normalized.contains('verification') ||
        normalized.contains('verify') ||
        normalized.contains('confirmed') ||
        normalized.contains('تأكيد') ||
        normalized.contains('التحقق');
  }

  /// Login user with email or phone
  Future<AuthResponse> login({
    required String deviceId,
    required String emailOrPhone,
    required String password,
    String? fcmToken,
  }) async {
    try {
      // Determine if input is email or phone

      // Build request body with appropriate key
      final Map<String, dynamic> requestBody = {
        'identifier': emailOrPhone.trim(),
        'password': password,
      };

      // Backend expects a fingerprint value for device restriction.
      // Use FCM token as the fingerprint (fallback to deviceId if unavailable).
      String? fingerprint = (fcmToken != null && fcmToken.trim().isNotEmpty)
          ? fcmToken.trim()
          : FirebaseNotification.fcmToken;
      if (fingerprint == null || fingerprint.trim().isEmpty) {
        await FirebaseNotification.getFcmToken();
        fingerprint = FirebaseNotification.fcmToken;
      }
      final resolvedFingerprint =
          (fingerprint != null && fingerprint.trim().isNotEmpty)
              ? fingerprint.trim()
              : deviceId.trim();
      if (resolvedFingerprint.isNotEmpty) {
        requestBody['deviceFingerprint'] = resolvedFingerprint;
      }
      if (fingerprint != null && fingerprint.trim().isNotEmpty) {
        requestBody['fcm_token'] = fingerprint.trim();
      }

      final response = await ApiClient.instance.post(
        ApiEndpoints.login,
        body: requestBody,
        requireAuth: false, // Login doesn't need auth
      );

      // Print full response for debugging
      if (kDebugMode) {
        print('📦 Full Login Response:');
        print('  Response: $response');
        print('  Response Type: ${response.runtimeType}');
        print('  Response Keys: ${response.keys.toList()}');
        response.forEach((key, value) {
          print('    $key: $value (${value.runtimeType})');
        });
      }

      if (response['success'] == true) {
        // Debug: Print raw response to see structure
        if (kDebugMode) {
          print('🔍 Raw Login Response:');
          print('  response keys: ${response.keys.toList()}');
          if (response['data'] != null) {
            final data = response['data'] as Map<String, dynamic>;
            print('  data keys: ${data.keys.toList()}');
            print('  token in data: ${data.containsKey('token')}');
            final tokenStr = data['token']?.toString() ?? 'NULL';
            final tokenPreview = tokenStr != 'NULL' && tokenStr.length > 20
                ? '${tokenStr.substring(0, 20)}...'
                : tokenStr;
            print('  token value: $tokenPreview');
            print(
                '  refresh_token in data: ${data.containsKey('refresh_token')}');
          }
        }

        final authResponse = AuthResponse.fromJson(response);

        print('🔐 Login successful - Parsing tokens...');
        print(
            '  Token from model: ${authResponse.token.isNotEmpty ? "${authResponse.token.substring(0, authResponse.token.length > 20 ? 20 : authResponse.token.length)}..." : "EMPTY"}');
        print('  Token length: ${authResponse.token.length}');
        print('  Refresh token length: ${authResponse.refreshToken.length}');

        if (authResponse.token.isEmpty) {
          print('❌ ERROR: Token is EMPTY after parsing!');
          print('💡 Check if API response contains token in data.token');
          throw Exception('Token is empty in response');
        }

        // Save tokens to cache (like Dio setTokenIntoHeaderAfterLogin)
        print('💾 Saving tokens to cache...');
        await TokenStorageService.instance.saveTokens(
          accessToken: authResponse.token,
          refreshToken: authResponse.refreshToken,
        );
        await TokenStorageService.instance.saveUserRole(authResponse.user.role);
        await TokenStorageService.instance
            .saveUserData(authResponse.user.toJson());

        // Verify token was saved to cache
        print('🔍 Verifying token was saved to cache...');
        final savedToken = await TokenStorageService.instance.getAccessToken();
        if (savedToken != null && savedToken.isNotEmpty) {
          if (savedToken == authResponse.token) {
            print('✅ Token cached successfully');
            print('  Cached token length: ${savedToken.length}');
            print('  💡 Token is now available for all API requests');
          } else {
            print('❌ Token mismatch in cache!');
            print(
                '  Original: ${authResponse.token.substring(0, authResponse.token.length > 20 ? 20 : authResponse.token.length)}...');
            print(
                '  Cached: ${savedToken.substring(0, savedToken.length > 20 ? 20 : savedToken.length)}...');
          }
        } else {
          print('❌ Token cache verification failed');
          print('  savedToken is null: ${savedToken == null}');
          print('  savedToken is empty: ${savedToken?.isEmpty ?? true}');
          throw Exception('Failed to cache token after login');
        }

        return authResponse;
      } else {
        throw Exception(response['message'] ?? 'Login failed');
      }
    } catch (e) {
      if (e is ApiException) {
        final message = e.message;
        if (_isEmailNotVerifiedMessage(message)) {
          throw EmailNotVerifiedException(message);
        }
        throw Exception(message.isNotEmpty
            ? message
            : 'فشل تسجيل الدخول. تحقق من بيانات الاعتماد');
      }
      rethrow;
    }
  }

  /// Send verification code to email before registration
  Future<String> sendRegisterVerificationCode({
    required String email,
  }) async {
    final response = await ApiClient.instance.post(
      ApiEndpoints.registerSendCode,
      body: {'email': email.trim()},
      requireAuth: false,
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'فشل إرسال رمز التحقق');
    }

    final data = response['data'] as Map<String, dynamic>?;
    return data?['verificationToken']?.toString() ?? '';
  }

  /// Verify email code and return backend success message
  Future<String> verifyRegisterEmailCode({
    required String email,
    required String code,
    String? verificationToken,
  }) async {
    final body = <String, dynamic>{
      'email': email.trim(),
      'code': code.trim(),
    };
    if (verificationToken != null && verificationToken.trim().isNotEmpty) {
      body['verificationToken'] = verificationToken.trim();
    }

    final response = await ApiClient.instance.post(
      ApiEndpoints.registerVerifyCode,
      body: body,
      requireAuth: false,
    );

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'رمز التحقق غير صحيح');
    }

    final message = response['message']?.toString().trim() ?? '';
    if (message.isNotEmpty) {
      return message;
    }
    return 'تم تأكيد البريد الإلكتروني وتفعيل الحساب بنجاح';
  }

  /// Complete register user after email verification
  Future<AuthResponse> register({
    required String name,
    required String email,
    String? phone,
    String? username,
    String? whatsAppNumber,
    String? nationalId,
    required String password,
    required String passwordConfirmation,
    required bool acceptTerms,
    String role = 'student', // Default to student, can be 'instructor'
    String? studentType, // Only required for students
    required String deviceId,
    required String deviceName,
    required String platform,
    String? fcmToken,
    String? emailVerifiedToken,
    String? avatar,
  }) async {
    try {
      // Normalize WhatsApp number to +20XXXXXXXXXX format if possible
      String? normalizedWhatsApp = whatsAppNumber;
      if (normalizedWhatsApp != null && normalizedWhatsApp.isNotEmpty) {
        normalizedWhatsApp = normalizedWhatsApp.trim();
        if (!normalizedWhatsApp.startsWith('+20')) {
          if (normalizedWhatsApp.startsWith('0')) {
            normalizedWhatsApp = normalizedWhatsApp.substring(1);
          }
          normalizedWhatsApp = '+20$normalizedWhatsApp';
        }
      }

      // Keep device_id as a stable device identifier (not FCM token),
      // because some backends validate device_id format/length strictly.
      final resolvedRegistrationFingerprint = deviceId.trim();

      // Build request body
      final body = <String, dynamic>{
        'name': name,
        'email': email,
        'password': password,
        'confirmPassword': passwordConfirmation,
        'accept_terms': acceptTerms,
        'role': role,
        'device_id': resolvedRegistrationFingerprint,
        'device_name': deviceName,
        'platform': platform,
      };

      if (emailVerifiedToken != null && emailVerifiedToken.trim().isNotEmpty) {
        body['email_verified_token'] = emailVerifiedToken.trim();
      }

      // Add phone if provided
      if (phone != null && phone.isNotEmpty) {
        body['phone'] = phone;
      }

      // Add username if provided
      if (username != null && username.isNotEmpty) {
        body['username'] = username;
      }

      // Add WhatsApp number if provided
      if (normalizedWhatsApp != null && normalizedWhatsApp.isNotEmpty) {
        body['whatsappNumber'] = normalizedWhatsApp;
      }

      // Add national ID if provided
      if (nationalId != null && nationalId.isNotEmpty) {
        body['nationalId'] = nationalId;
      }

      // Add student_type only for students
      if (role == 'student' && studentType != null) {
        // Map student_type values to API format
        // API expects: "online" or "offline"
        String mappedStudentType = studentType;
        if (studentType == 'in_person') {
          mappedStudentType = 'offline';
        } else if (studentType == 'both') {
          mappedStudentType = 'online'; // Default to online for "both"
        }
        body['student_type'] = mappedStudentType;
      }

      // Add FCM token if provided
      if (fcmToken != null && fcmToken.isNotEmpty) {
        body['fcm_token'] = fcmToken;
      }

      // Add avatar image URL/path if provided
      if (avatar != null && avatar.trim().isNotEmpty) {
        body['avatar'] = avatar.trim();
      }

      Future<Map<String, dynamic>> sendRegisterRequest(
        Map<String, dynamic> requestBody,
      ) {
        return ApiClient.instance.post(
          ApiEndpoints.register,
          body: requestBody,
          requireAuth: false, // Register doesn't need auth
        );
      }

      Map<String, dynamic> response;
      try {
        response = await sendRegisterRequest(body);
      } catch (e) {
        final hasAvatar = body['avatar'] != null;
        final normalizedError = e.toString().toLowerCase();
        final looksLikeGenericInvalidData =
            normalizedError.contains('invalid data provided') ||
                normalizedError.contains('تأكد من صحة الحقول');
        if (hasAvatar && looksLikeGenericInvalidData) {
          final fallbackBody = Map<String, dynamic>.from(body)
            ..remove('avatar');
          response = await sendRegisterRequest(fallbackBody);
        } else {
          rethrow;
        }
      }

      // Print full response for debugging
      if (kDebugMode) {
        print('📦 Full Register Response:');
        print('  Response: $response');
        print('  Response Type: ${response.runtimeType}');
        print('  Response Keys: ${response.keys.toList()}');
        response.forEach((key, value) {
          print('    $key: $value (${value.runtimeType})');
        });
      }

      if (response['success'] == true) {
        // Parse response but DO NOT auto-login; user must log in manually
        final authResponse = AuthResponse.fromJson(response);
        return authResponse;
      } else {
        throw Exception(response['message'] ?? 'Registration failed');
      }
    } catch (e) {
      if (e is ApiException) {
        throw Exception(_extractServerMessage(
          e,
          'فشل إنشاء الحساب. يرجى المحاولة مرة أخرى',
        ));
      }
      rethrow;
    }
  }

  /// Refresh access token
  Future<AuthResponse> refreshAccessToken() async {
    try {
      final refreshToken = await TokenStorageService.instance.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw Exception('لا يوجد refresh token');
      }

      final response = await ApiClient.instance.post(
        ApiEndpoints.refreshToken,
        body: {
          'refreshToken': refreshToken,
        },
        requireAuth: false, // Refresh doesn't need access token
      );

      if (response['success'] == true) {
        final authResponse = AuthResponse.fromJson(response);

        if (authResponse.token.isEmpty) {
          throw Exception('Token is empty in refresh response');
        }

        // Save new tokens to cache
        await TokenStorageService.instance.saveTokens(
          accessToken: authResponse.token,
          refreshToken: authResponse.refreshToken,
        );

        if (kDebugMode) {
          print('✅ Access token refreshed successfully');
          print('  New token length: ${authResponse.token.length}');
        }

        return authResponse;
      } else {
        throw Exception(response['message'] ?? 'فشل تجديد الـ access token');
      }
    } catch (e) {
      if (e is ApiException) {
        // Try to parse error message from response body
        try {
          final errorBody = e.message;
          final match = RegExp(r'\{.*\}').firstMatch(errorBody);
          if (match != null) {
            final errorJson = jsonDecode(match.group(0)!);
            final message = errorJson['message'] ??
                errorJson['error'] ??
                'فشل تجديد الـ access token';
            throw Exception(message);
          }
        } catch (_) {}
        throw Exception(
            'فشل تجديد الـ access token. يرجى تسجيل الدخول مرة أخرى');
      }
      rethrow;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      // Use requireAuth: true to automatically add token from cache
      await ApiClient.instance.post(
        ApiEndpoints.logout,
        requireAuth: true,
      );
    } catch (e) {
      // Even if API call fails, clear cached tokens
      print('Logout API error: $e');
    } finally {
      // Always clear cached tokens (like _handleTokenExpiry)
      print('🗑️ Clearing cached tokens...');
      await TokenStorageService.instance.clearTokens();
      print('✅ Cached tokens cleared');
    }
  }

  /// Forgot password - Send reset link to email
  Future<void> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.forgotPassword,
        body: {
          'email': email,
        },
        requireAuth: false, // Forgot password doesn't need auth
      );

      if (response['success'] != true) {
        throw Exception(
            response['message'] ?? 'فشل إرسال رابط إعادة تعيين كلمة المرور');
      }
    } catch (e) {
      if (e is ApiException) {
        // Try to parse error message from response body
        try {
          final errorBody = e.message;
          final match = RegExp(r'\{.*\}').firstMatch(errorBody);
          if (match != null) {
            final errorJson = jsonDecode(match.group(0)!);
            final message = errorJson['message'] ??
                errorJson['error'] ??
                'فشل إرسال رابط إعادة تعيين كلمة المرور';
            throw Exception(message);
          }
        } catch (_) {}
        throw Exception(
            'فشل إرسال رابط إعادة تعيين كلمة المرور. يرجى المحاولة مرة أخرى');
      }
      rethrow;
    }
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    return await TokenStorageService.instance.isLoggedIn();
  }

  /// Google sign-in with API integration
  Future<AuthResponse> signInWithGoogle() async {
    try {
      // Step 1: Get Google credentials
      GoogleSignIn googleSignIn;

      // Try to initialize GoogleSignIn - on Android it requires OAuth client ID
      // If oauth_client is empty in google-services.json, this will fail
      try {
        googleSignIn = GoogleSignIn(
          scopes: ['email', 'profile'],
        );
      } catch (e) {
        if (kDebugMode) {
          print('❌ GoogleSignIn initialization error: $e');
        }
        throw Exception(
            'خطأ في إعدادات Google Sign-In. يرجى التحقق من إعدادات Firebase Console وإضافة OAuth Client ID');
      }

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('تم إلغاء تسجيل الدخول بواسطة المستخدم');
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null || googleAuth.accessToken == null) {
        throw Exception('فشل الحصول على بيانات المصادقة من جوجل');
      }

      // Step 2: Get FCM token
      String? fcmToken = FirebaseNotification.fcmToken;
      if (fcmToken == null || fcmToken.isEmpty) {
        // Try to get token if not available
        await FirebaseNotification.getFcmToken();
        fcmToken = FirebaseNotification.fcmToken ?? '';
      }

      // Step 3: Get device info
      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'unknown';

      // Step 4: Build request body
      final requestBody = {
        'provider': 'google',
        'id_token': googleAuth.idToken,
        'access_token': googleAuth.accessToken,
        'fcm_token': fcmToken,
        'device': {
          'platform': platform,
          'model': 'Unknown', // Can be enhanced with device_info_plus package
          'app_version': '1.0.0',
        },
      };

      if (kDebugMode) {
        print('🔐 Google Social Login Request:');
        print('  provider: google');
        print('  id_token: ${googleAuth.idToken?.substring(0, 20)}...');
        print('  access_token: ${googleAuth.accessToken?.substring(0, 20)}...');
        print(
            '  fcm_token: ${fcmToken.isNotEmpty ? "${fcmToken.substring(0, 20)}..." : "EMPTY"}');
        print('  platform: $platform');
      }

      // Step 5: Send request to API
      final response = await ApiClient.instance.post(
        ApiEndpoints.socialLogin,
        body: requestBody,
        requireAuth: false, // Social login doesn't need auth
      );

      if (response['success'] == true) {
        final authResponse = AuthResponse.fromJson(response);

        if (kDebugMode) {
          print('🔐 Google Social Login successful - Saving tokens...');
          print('  Token length: ${authResponse.token.length}');
          print('  Refresh token length: ${authResponse.refreshToken.length}');
        }

        // Save tokens to cache
        await TokenStorageService.instance.saveTokens(
          accessToken: authResponse.token,
          refreshToken: authResponse.refreshToken,
        );
        await TokenStorageService.instance.saveUserRole(authResponse.user.role);
        await TokenStorageService.instance
            .saveUserData(authResponse.user.toJson());

        // Verify token was cached
        final savedToken = await TokenStorageService.instance.getAccessToken();
        if (savedToken != null &&
            savedToken.isNotEmpty &&
            savedToken == authResponse.token) {
          if (kDebugMode) {
            print('✅ Token cached successfully (length: ${savedToken.length})');
          }
        } else {
          if (kDebugMode) {
            print('❌ Token cache verification failed');
          }
          throw Exception('Failed to cache token after Google login');
        }

        return authResponse;
      } else {
        throw Exception(response['message'] ?? 'فشل تسجيل الدخول عبر جوجل');
      }
    } catch (e) {
      // Handle PlatformException specifically for Google Sign-In errors
      if (e.toString().contains('PlatformException') ||
          e.toString().contains('sign_in_failed') ||
          e.toString().contains('ApiException')) {
        if (kDebugMode) {
          print('❌ Google Sign-In PlatformException: $e');
        }

        // Check for common OAuth configuration errors
        if (e.toString().contains('oauth_client') ||
            e.toString().contains('Api10') ||
            e.toString().contains('SIGN_IN_REQUIRED') ||
            e.toString().contains('DEVELOPER_ERROR')) {
          throw Exception('خطأ في إعدادات Google Sign-In:\n'
              'يرجى التأكد من:\n'
              '1. تفعيل Google Sign-In في Firebase Console\n'
              '2. إضافة OAuth Client ID للـ Android app\n'
              '3. تحميل ملف google-services.json المحدث\n'
              '4. التأكد من تطابق package_name مع applicationId');
        }

        // Generic Google Sign-In error
        throw Exception('فشل تسجيل الدخول عبر Google. يرجى التحقق من:\n'
            '- اتصال الإنترنت\n'
            '- إعدادات Google Sign-In في Firebase Console\n'
            '- ملف google-services.json يحتوي على OAuth Client IDs');
      }

      if (e is ApiException) {
        // Try to parse error message from response body
        try {
          final errorBody = e.message;
          final match = RegExp(r'\{.*\}').firstMatch(errorBody);
          if (match != null) {
            final errorJson = jsonDecode(match.group(0)!);
            final message = errorJson['message'] ??
                errorJson['error'] ??
                'فشل تسجيل الدخول عبر جوجل';
            throw Exception(message);
          }
        } catch (_) {}
        throw Exception('فشل تسجيل الدخول عبر جوجل. يرجى المحاولة مرة أخرى');
      }

      // Re-throw if it's already a user-friendly Exception
      final errorString = e.toString();
      if (e is Exception &&
          (errorString.contains('خطأ') ||
              errorString.contains('تم إلغاء') ||
              errorString.contains('فشل'))) {
        rethrow;
      }

      // Generic error fallback
      throw Exception('فشل تسجيل الدخول عبر Google: ${e.toString()}');
    }
  }

  /// Apple sign-in with API integration
  Future<AuthResponse> signInWithApple() async {
    try {
      // Step 1: Generate nonce for Apple sign-in
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      // Step 2: Get Apple credentials
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      if (appleCredential.identityToken == null) {
        throw Exception('فشل الحصول على بيانات المصادقة من Apple');
      }

      // Step 3: Get FCM token
      String? fcmToken = FirebaseNotification.fcmToken;
      if (fcmToken == null || fcmToken.isEmpty) {
        // Try to get token if not available
        await FirebaseNotification.getFcmToken();
        fcmToken = FirebaseNotification.fcmToken ?? '';
      }

      // Step 4: Get device info
      final platform = Platform.isAndroid
          ? 'android'
          : Platform.isIOS
              ? 'ios'
              : 'unknown';

      // Step 5: Build request body
      final requestBody = {
        'provider': 'apple',
        'id_token': appleCredential.identityToken,
        'nonce': rawNonce,
        'fcm_token': fcmToken,
        'device': {
          'platform': platform,
          'model': 'Unknown', // Can be enhanced with device_info_plus package
          'app_version': '1.0.0',
        },
      };

      if (kDebugMode) {
        print('🔐 Apple Social Login Request:');
        print('  provider: apple');
        print(
            '  id_token: ${appleCredential.identityToken?.substring(0, 20)}...');
        print('  nonce: ${rawNonce.substring(0, 20)}...');
        print(
            '  fcm_token: ${fcmToken.isNotEmpty ? "${fcmToken.substring(0, 20)}..." : "EMPTY"}');
        print('  platform: $platform');
      }

      // Step 6: Send request to API
      final response = await ApiClient.instance.post(
        ApiEndpoints.socialLogin,
        body: requestBody,
        requireAuth: false, // Social login doesn't need auth
      );

      if (response['success'] == true) {
        final authResponse = AuthResponse.fromJson(response);

        if (kDebugMode) {
          print('🔐 Apple Social Login successful - Saving tokens...');
          print('  Token length: ${authResponse.token.length}');
          print('  Refresh token length: ${authResponse.refreshToken.length}');
        }

        // Save tokens to cache
        await TokenStorageService.instance.saveTokens(
          accessToken: authResponse.token,
          refreshToken: authResponse.refreshToken,
        );
        await TokenStorageService.instance.saveUserRole(authResponse.user.role);
        await TokenStorageService.instance
            .saveUserData(authResponse.user.toJson());

        // Verify token was cached
        final savedToken = await TokenStorageService.instance.getAccessToken();
        if (savedToken != null &&
            savedToken.isNotEmpty &&
            savedToken == authResponse.token) {
          if (kDebugMode) {
            print('✅ Token cached successfully (length: ${savedToken.length})');
          }
        } else {
          if (kDebugMode) {
            print('❌ Token cache verification failed');
          }
          throw Exception('Failed to cache token after Apple login');
        }

        return authResponse;
      } else {
        throw Exception(response['message'] ?? 'فشل تسجيل الدخول عبر Apple');
      }
    } catch (e) {
      if (e is ApiException) {
        // Try to parse error message from response body
        try {
          final errorBody = e.message;
          final match = RegExp(r'\{.*\}').firstMatch(errorBody);
          if (match != null) {
            final errorJson = jsonDecode(match.group(0)!);
            final message = errorJson['message'] ??
                errorJson['error'] ??
                'فشل تسجيل الدخول عبر Apple';
            throw Exception(message);
          }
        } catch (_) {}
        throw Exception('فشل تسجيل الدخول عبر Apple. يرجى المحاولة مرة أخرى');
      }
      rethrow;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
