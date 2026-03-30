import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';

class StudentPointsService {
  StudentPointsService._();

  static final StudentPointsService instance = StudentPointsService._();

  Future<int> getMyPoints() async {
    final response = await ApiClient.instance.get(
      ApiEndpoints.studentsMePoints,
      requireAuth: true,
      logTag: 'StudentPoints',
    );

    if (response['success'] == true) {
      final data = response['data'];
      final totalPoints = (data is Map<String, dynamic>)
          ? (data['totalPoints'] as num?)?.toInt()
          : null;
      return totalPoints ?? 0;
    }

    if (kDebugMode) {
      print('❌ getMyPoints failed: ${response['message']}');
    }
    throw Exception(response['message'] ?? 'Failed to fetch points');
  }
}
