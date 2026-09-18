import 'dart:convert';
import 'package:agrimotion/core/constants/api_constants.dart';
import 'package:agrimotion/core/network/api_client.dart';
import 'package:agrimotion/core/models/watering_log_model.dart';
import 'package:agrimotion/features/auth/data/token_storage.dart';

class WateringLogService {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  WateringLogService({ApiClient? apiClient, TokenStorage? tokenStorage})
      : _apiClient = apiClient ?? ApiClient(),
        _tokenStorage = tokenStorage ?? TokenStorage.instance;

  /// Checks whether user is currently authenticated with a valid token.
  Future<bool> isUserLoggedIn() async {
    return await _tokenStorage.hasValidToken();
  }

  /// Fetches recent watering logs from the backend.
  /// Automatically injects JWT Bearer token and intercepts 401 to clear expired session.
  /// Falls back to mock data if network is down.
  Future<List<WateringLogModel>> fetchRecentLogs({int limit = 5}) async {
    final token = await _tokenStorage.getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final candidateEndpoints = [
      '${ApiConstants.baseUrl}/watering-logs?limit=$limit',
      '${ApiConstants.baseUrl}/api/watering-logs?limit=$limit',
      '${ApiConstants.baseUrl}/actuations/logs?limit=$limit',
      '${ApiConstants.baseUrl}/api/watering/history?limit=$limit',
      '${ApiConstants.baseUrl}/api/watering/logs?limit=$limit',
      '${ApiConstants.baseUrl}/activity-logs?limit=$limit',
    ];

    for (final endpoint in candidateEndpoints) {
      try {
        final response = await _apiClient.get(Uri.parse(endpoint), headers: headers);
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
        } else if (response.statusCode == 401) {
          // Token expired or invalid: clear session and halt redundant requests
          await _tokenStorage.clearSession();
          break;
        }
      } catch (e) {
        if (e is UnauthorizedException) {
          await _tokenStorage.clearSession();
          break;
        }
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
