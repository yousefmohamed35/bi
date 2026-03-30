import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

/// Service for payments and checkout
class PaymentsService {
  PaymentsService._();

  static final PaymentsService instance = PaymentsService._();

  /// Create cash enrollment request for a course
  Future<Map<String, dynamic>> createCashCourseRequest({
    required String courseId,
    String? message,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.enrollmentRequests,
        body: {
          'course_id': courseId,
          if (message != null && message.trim().isNotEmpty)
            'message': message.trim(),
        },
        requireAuth: true,
      );

      if (response['success'] == true) {
        return response['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
      }

      throw Exception(
          response['message'] ?? 'Failed to create cash course request');
    } catch (e) {
      rethrow;
    }
  }

  /// List my enrollment requests (cash requests)
  Future<Map<String, dynamic>> getMyEnrollmentRequests({
    int page = 1,
    int perPage = 20,
    String? status, // pending | approved | rejected
  }) async {
    try {
      final query = <String>[
        'page=$page',
        'per_page=$perPage',
        if (status != null && status.isNotEmpty) 'status=$status',
      ].join('&');

      final response = await ApiClient.instance.get(
        '${ApiEndpoints.enrollmentRequests}?$query',
        requireAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      }
      throw Exception(
          response['message'] ?? 'Failed to load enrollment requests');
    } catch (e) {
      rethrow;
    }
  }

  /// Initiate checkout
  Future<Map<String, dynamic>> initiateCheckout({
    required String courseId,
    required String paymentMethod,
    String? couponCode,
  }) async {
    try {
      final body = <String, dynamic>{
        'course_id': courseId,
        'payment_method': paymentMethod,
        if (couponCode != null && couponCode.isNotEmpty)
          'coupon_code': couponCode,
      };

      final response = await ApiClient.instance.post(
        ApiEndpoints.payments,
        body: body,
        requireAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to initiate checkout');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Complete checkout
  Future<Map<String, dynamic>> completeCheckout({
    required String checkoutSessionId,
    required String paymentMethod,
    required String paymentToken,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.confirmPayment(checkoutSessionId),
        body: {
          'checkout_session_id': checkoutSessionId,
          'payment_method': paymentMethod,
          'payment_token': paymentToken,
        },
        requireAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to complete checkout');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Validate coupon
  Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required String courseId,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.validateCoupon,
        body: {
          'code': code,
          'course_id': courseId,
        },
        requireAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Invalid coupon code');
      }
    } catch (e) {
      rethrow;
    }
  }
}
