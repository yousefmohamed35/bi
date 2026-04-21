import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import 'token_storage_service.dart';

/// Service for exams
class ExamsService {
  ExamsService._();

  static final ExamsService instance = ExamsService._();

  /// Get exam details
  Future<Map<String, dynamic>> getExamDetails(String examId) async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.exam(examId),
        requireAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch exam details');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Start exam
  Future<Map<String, dynamic>> startCourseExam(
    String courseId,
    String examId,
  ) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.courseExamStart(courseId, examId),
        requireAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to start exam');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Submit exam
  Future<Map<String, dynamic>> submitExam(
    String courseId,
    String examId, {
    required String attemptId,
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      final response = await ApiClient.instance.post(
        ApiEndpoints.courseExamSubmit(courseId, examId),
        body: {
          'attempt_id': attemptId,
          'answers': answers,
        },
        requireAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to submit exam');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get user exams
  Future<Map<String, dynamic>> getMyExams() async {
    try {
      final response = await ApiClient.instance.get(
        ApiEndpoints.myExamResults,
        requireAuth: true,
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch exams');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get course exams
  Future<List<Map<String, dynamic>>> getCourseExams(String courseId) async {
    try {
      // Auth is optional. When token exists, include it for richer attempt status.
      final token = await TokenStorageService.instance.getAccessToken();
      final headers = (token != null && token.trim().isNotEmpty)
          ? <String, String>{'Authorization': 'Bearer ${token.trim()}'}
          : null;

      final response = await ApiClient.instance.get(
        ApiEndpoints.courseExams(courseId),
        headers: headers,
        requireAuth: false,
        logTag: 'CourseExams',
      );

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        if (data is List) {
          return data.map((exam) => exam as Map<String, dynamic>).toList();
        } else {
          return [];
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch course exams');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get course exam details
  Future<Map<String, dynamic>> getCourseExamDetails(
    String courseId,
    String examId,
  ) async {
    try {
      // Auth is optional. When token exists, include it for richer attempt status.
      final token = await TokenStorageService.instance.getAccessToken();
      final headers = (token != null && token.trim().isNotEmpty)
          ? <String, String>{'Authorization': 'Bearer ${token.trim()}'}
          : null;

      final response = await ApiClient.instance.get(
        ApiEndpoints.courseExamDetails(courseId, examId),
        headers: headers,
        requireAuth: false,
        logTag: 'CourseExamDetails',
      );

      if (response['success'] == true && response['data'] != null) {
        return response['data'] as Map<String, dynamic>;
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch exam details');
      }
    } catch (e) {
      rethrow;
    }
  }
}
