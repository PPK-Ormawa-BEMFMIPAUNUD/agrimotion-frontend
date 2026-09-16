import 'dart:convert';
import 'package:agrimotion/core/constants/api_constants.dart';
import 'package:agrimotion/core/network/api_client.dart';
import 'package:agrimotion/core/models/watering_log_model.dart';

class WateringLogService {
  final ApiClient _apiClient;

  WateringLogService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  /// Fetches recent watering logs from the backend.
  /// Falls back to mock data if the network is down.
  Future<List<WateringLogModel>> fetchRecentLogs({int limit = 5}) async {
    final candidateEndpoints = [
      '${ApiConstants.baseUrl}/watering-logs?limit=$limit',
      '${ApiConstants.baseUrl}/api/watering-logs?limit=$limit',
      '${ApiConstants.baseUrl}/actuations/logs?limit=$limit',
      '${ApiConstants.baseUrl}/activity-logs?limit=$limit',
    ];

    for (final endpoint in candidateEndpoints) {
      try {
        final response = await _apiClient.get(Uri.parse(endpoint));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final dynamic body = _apiClient.parseJson(response);
          List<WateringLogModel> logs = [];

          if (body is Map<String, dynamic>) {
            final possibleLists = [
              body['watering_logs'],
              body['wateringLogs'],
              body['data'],
              body['rows']
            ];

            for (final list in possibleLists) {
              if (list != null && list is List) {
                logs = list
                    .whereType<Map<String, dynamic>>()
                    .map((item) => WateringLogModel.fromJson(item))
                    .toList();
                break;
              }
            }
          } else if (body is List) {
            logs = body
                .whereType<Map<String, dynamic>>()
                .map((item) => WateringLogModel.fromJson(item))
                .toList();
          }

          if (logs.isNotEmpty) {
            logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return logs.take(limit).toList();
          }
        }
      } catch (_) {
        // Continue to the next fallback endpoint if there's an error
        continue;
      }
    }

    // Fallback Mock Dataset if server unreachable / empty / no endpoints work
    return _getFallbackLogs(limit);
  }

  List<WateringLogModel> _getFallbackLogs(int limit) {
    final List<Map<String, dynamic>> rawWaterings = [
      {
        "id": "mock-1",
        "deviceId": "10000000-0000-0000-0000-000000000001",
        "type": "FERTILIZER",
        "duration": 60,
        "createdAt": DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String()
      },
      {
        "id": "mock-2",
        "deviceId": "20000000-0000-0000-0000-000000000001",
        "type": "PESTICIDE",
        "duration": 30,
        "createdAt": DateTime.now().subtract(const Duration(hours: 1)).toIso8601String()
      },
      {
        "id": "mock-3",
        "deviceId": "30000000-0000-0000-0000-000000000001",
        "type": "WATER",
        "duration": 120,
        "createdAt": DateTime.now().subtract(const Duration(days: 1)).toIso8601String()
      },
    ];

    final list = rawWaterings.map((e) => WateringLogModel.fromJson(e)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(limit).toList();
  }
}
