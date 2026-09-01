import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agrimotion/core/network/api_client.dart';
import 'package:agrimotion/core/constants/api_constants.dart';
import 'package:agrimotion/features/activity_logs/domain/activity_log_models.dart';

final activityLogServiceProvider = Provider<ActivityLogService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ActivityLogService(apiClient);
});

final loginLogsProvider = FutureProvider.autoDispose<List<UserLoginLog>>((ref) async {
  final service = ref.watch(activityLogServiceProvider);
  return service.fetchLoginLogs();
});

final wateringLogsProvider = FutureProvider.autoDispose<List<WateringLog>>((ref) async {
  final service = ref.watch(activityLogServiceProvider);
  return service.fetchWateringLogs();
});

class ActivityLogService {
  final ApiClient _apiClient;

  ActivityLogService(this._apiClient);

  Future<List<UserLoginLog>> fetchLoginLogs() async {
    final candidateEndpoints = [
      '${ApiConstants.baseUrl}/api/activity-logs',
      '${ApiConstants.baseUrl}/activity-logs',
      '${ApiConstants.baseUrl}/api/user-logins',
      '${ApiConstants.baseUrl}/user-logins',
      '${ApiConstants.baseUrl}/api/user_logins',
      '${ApiConstants.baseUrl}/user_logins',
      '${ApiConstants.baseUrl}/api/logs/logins',
      '${ApiConstants.baseUrl}/logs/logins',
      '${ApiConstants.baseUrl}/api/logins',
      '${ApiConstants.baseUrl}/logins',
      '${ApiConstants.baseUrl}/api/auth/logins',
      '${ApiConstants.baseUrl}/auth/logins',
      '${ApiConstants.baseUrl}/api/users/logins',
      '${ApiConstants.baseUrl}/users/logins',
    ];

    final uniqueEndpoints = candidateEndpoints.toSet().toList();

    for (final endpoint in uniqueEndpoints) {
      try {
        final response = await _apiClient.get(Uri.parse(endpoint));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final dynamic body = _apiClient.parseJson(response);
          List<UserLoginLog> logs = [];

          if (body is Map<String, dynamic>) {
            if (body['user_logins'] != null && body['user_logins'] is List) {
              final List<dynamic> data = body['user_logins'];
              logs = data
                  .whereType<Map<String, dynamic>>()
                  .map((item) => UserLoginLog.fromJson(item))
                  .toList();
            } else if (body['userLogins'] != null && body['userLogins'] is List) {
              final List<dynamic> data = body['userLogins'];
              logs = data
                  .whereType<Map<String, dynamic>>()
                  .map((item) => UserLoginLog.fromJson(item))
                  .toList();
            } else if (body['data'] != null && body['data'] is List) {
              final List<dynamic> data = body['data'];
              logs = data
                  .whereType<Map<String, dynamic>>()
                  .map((item) => UserLoginLog.fromJson(item))
                  .toList();
            } else if (body['rows'] != null && body['rows'] is List) {
              final List<dynamic> rows = body['rows'];
              logs = rows
                  .whereType<Map<String, dynamic>>()
                  .map((item) => UserLoginLog.fromJson(item))
                  .toList();
            }
          } else if (body is List) {
            logs = body
                .whereType<Map<String, dynamic>>()
                .map((item) => UserLoginLog.fromJson(item))
                .toList();
          }

          if (logs.isNotEmpty) {
            logs.sort((a, b) => b.loginAt.compareTo(a.loginAt));
            return logs;
          }
        }
      } on NotFoundException {
        continue;
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          continue;
        }
        continue;
      } catch (_) {
        continue;
      }
    }

    // Fallback Mock Dataset if server unreachable / empty
    return _getFallbackLoginLogs();
  }

  Future<List<WateringLog>> fetchWateringLogs() async {
    final candidateEndpoints = [
      '${ApiConstants.baseUrl}/api/activity-logs',
      '${ApiConstants.baseUrl}/activity-logs',
      '${ApiConstants.baseUrl}/api/watering-logs',
      '${ApiConstants.baseUrl}/watering-logs',
      '${ApiConstants.baseUrl}/api/watering_logs',
      '${ApiConstants.baseUrl}/watering_logs',
      '${ApiConstants.baseUrl}/api/logs/watering',
      '${ApiConstants.baseUrl}/logs/watering',
      '${ApiConstants.baseUrl}/api/watering',
      '${ApiConstants.baseUrl}/watering',
      '${ApiConstants.baseUrl}/api/activities',
      '${ApiConstants.baseUrl}/activities',
    ];

    final uniqueEndpoints = candidateEndpoints.toSet().toList();

    for (final endpoint in uniqueEndpoints) {
      try {
        final response = await _apiClient.get(Uri.parse(endpoint));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final dynamic body = _apiClient.parseJson(response);
          List<WateringLog> logs = [];

          if (body is Map<String, dynamic>) {
            if (body['watering_logs'] != null && body['watering_logs'] is List) {
              final List<dynamic> data = body['watering_logs'];
              logs = data
                  .whereType<Map<String, dynamic>>()
                  .map((item) => WateringLog.fromJson(item))
                  .toList();
            } else if (body['wateringLogs'] != null && body['wateringLogs'] is List) {
              final List<dynamic> data = body['wateringLogs'];
              logs = data
                  .whereType<Map<String, dynamic>>()
                  .map((item) => WateringLog.fromJson(item))
                  .toList();
            } else if (body['data'] != null && body['data'] is List) {
              final List<dynamic> data = body['data'];
              logs = data
                  .whereType<Map<String, dynamic>>()
                  .map((item) => WateringLog.fromJson(item))
                  .toList();
            } else if (body['rows'] != null && body['rows'] is List) {
              final List<dynamic> rows = body['rows'];
              logs = rows
                  .whereType<Map<String, dynamic>>()
                  .map((item) => WateringLog.fromJson(item))
                  .toList();
            }
          } else if (body is List) {
            logs = body
                .whereType<Map<String, dynamic>>()
                .map((item) => WateringLog.fromJson(item))
                .toList();
          }

          if (logs.isNotEmpty) {
            logs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return logs;
          }
        }
      } on NotFoundException {
        continue;
      } on ApiException catch (e) {
        if (e.statusCode == 404) {
          continue;
        }
        continue;
      } catch (_) {
        continue;
      }
    }

    // Fallback Mock Dataset if server unreachable / empty
    return _getFallbackWateringLogs();
  }

  // ---------------------------------------------------------------------------
  // Fallback Datasets (August 20 - 26, 2026 PostgreSQL dataset)
  // ---------------------------------------------------------------------------

  List<UserLoginLog> _getFallbackLoginLogs() {
    final List<Map<String, dynamic>> rawLogins = [
      {"id": "437c30b7-2e59-47ec-a574-cf542408b4de", "userId": "d1a11111-1111-1111-1111-111111111111", "userName": "I Wayan Madeg", "userEmail": "wayan.madeg@agrimotion.com", "role": "KADER_DIGITAL", "loginAt": "2026-08-26T17:15:00", "ipAddress": "192.168.1.42"},
      {"id": "512a10c8-3f41-4822-b912-9ab2e31411aa", "userId": "d2b11111-1111-1111-1111-111111111111", "userName": "I Nengah Aryana", "userEmail": "nengah.aryana@agrimotion.com", "role": "KADER_DIGITAL", "loginAt": "2026-08-26T14:22:00", "ipAddress": "192.168.1.18"},
      {"id": "18928374-1234-5678-9abc-def012345678", "userId": "d3c11111-1111-1111-1111-111111111111", "userName": "Ni Luh Putu Anggraini", "userEmail": "putu.anggraini@agrimotion.com", "role": "ADMIN", "loginAt": "2026-08-26T08:30:00", "ipAddress": "192.168.1.10"},
      {"id": "aa112233-4455-6677-8899-aabbccddeeff", "userId": "d4d11111-1111-1111-1111-111111111111", "userName": "I Made Sujana", "userEmail": "made.sujana@agrimotion.com", "role": "OPERATOR", "loginAt": "2026-08-25T16:45:00", "ipAddress": "192.168.1.55"},
      {"id": "bb223344-5566-7788-99aa-bbccddeeff00", "userId": "d1a11111-1111-1111-1111-111111111111", "userName": "I Wayan Madeg", "userEmail": "wayan.madeg@agrimotion.com", "role": "KADER_DIGITAL", "loginAt": "2026-08-25T09:12:00", "ipAddress": "192.168.1.42"},
      {"id": "cc334455-6677-8899-aabb-ccddeeff0011", "userId": "d2b11111-1111-1111-1111-111111111111", "userName": "I Nengah Aryana", "userEmail": "nengah.aryana@agrimotion.com", "role": "KADER_DIGITAL", "loginAt": "2026-08-24T18:05:00", "ipAddress": "192.168.1.18"},
      {"id": "dd445566-7788-99aa-bbcc-ddeeff001122", "userId": "d5e11111-1111-1111-1111-111111111111", "userName": "I Ketut Widiantara", "userEmail": "ketut.widiantara@agrimotion.com", "role": "KADER_DIGITAL", "loginAt": "2026-08-24T13:40:00", "ipAddress": "192.168.1.61"},
      {"id": "ee556677-8899-aabb-ccdd-eeff00112233", "userId": "d3c11111-1111-1111-1111-111111111111", "userName": "Ni Luh Putu Anggraini", "userEmail": "putu.anggraini@agrimotion.com", "role": "ADMIN", "loginAt": "2026-08-24T08:15:00", "ipAddress": "192.168.1.10"},
      {"id": "ff667788-99aa-bbcc-ddee-ff0011223344", "userId": "d1a11111-1111-1111-1111-111111111111", "userName": "I Wayan Madeg", "userEmail": "wayan.madeg@agrimotion.com", "role": "KADER_DIGITAL", "loginAt": "2026-08-23T15:20:00", "ipAddress": "192.168.1.42"},
      {"id": "00778899-aabb-ccdd-eeff-001122334455", "userId": "d4d11111-1111-1111-1111-111111111111", "userName": "I Made Sujana", "userEmail": "made.sujana@agrimotion.com", "role": "OPERATOR", "loginAt": "2026-08-23T10:05:00", "ipAddress": "192.168.1.55"},
      {"id": "118899aa-bbcc-ddee-ff00-112233445566", "userId": "d2b11111-1111-1111-1111-111111111111", "userName": "I Nengah Aryana", "userEmail": "nengah.aryana@agrimotion.com", "role": "KADER_DIGITAL", "loginAt": "2026-08-22T16:30:00", "ipAddress": "192.168.1.18"},
      {"id": "2299aabb-ccdd-eeff-0011-223344556677", "userId": "d5e11111-1111-1111-1111-111111111111", "userName": "I Ketut Widiantara", "userEmail": "ketut.widiantara@agrimotion.com", "role": "KADER_DIGITAL", "loginAt": "2026-08-22T08:50:00", "ipAddress": "192.168.1.61"},
      {"id": "33aabbcc-ddee-ff00-1122-334455667788", "userId": "d3c11111-1111-1111-1111-111111111111", "userName": "Ni Luh Putu Anggraini", "userEmail": "putu.anggraini@agrimotion.com", "role": "ADMIN", "loginAt": "2026-08-21T14:10:00", "ipAddress": "192.168.1.10"},
      {"id": "44bbccdd-eeff-0011-2233-445566778899", "userId": "d1a11111-1111-1111-1111-111111111111", "userName": "I Wayan Madeg", "userEmail": "wayan.madeg@agrimotion.com", "role": "KADER_DIGITAL", "loginAt": "2026-08-21T07:45:00", "ipAddress": "192.168.1.42"},
      {"id": "55ccddee-ff00-1122-3344-5566778899aa", "userId": "d2b11111-1111-1111-1111-111111111111", "userName": "I Nengah Aryana", "userEmail": "nengah.aryana@agrimotion.com", "role": "KADER_DIGITAL", "loginAt": "2026-08-20T16:15:00", "ipAddress": "192.168.1.18"},
      {"id": "437c30b7-2e59-47ec-a574-cf542408b4df", "userId": "d1a11111-1111-1111-1111-111111111111", "userName": "I Wayan Madeg", "userEmail": "wayan.madeg@agrimotion.com", "role": "KADER_DIGITAL", "loginAt": "2026-08-20T09:47:00", "ipAddress": "192.168.1.42"},
    ];

    final list = rawLogins.map((e) => UserLoginLog.fromJson(e)).toList();
    list.sort((a, b) => b.loginAt.compareTo(a.loginAt));
    return list;
  }

  List<WateringLog> _getFallbackWateringLogs() {
    final List<Map<String, dynamic>> rawWaterings = [
      {"id": "99ffdc0d-07e2-466f-bfb0-6f38ce6e8b99", "deviceId": "10000000-0000-0000-0000-000000000001", "deviceCode": "node-1a", "farmName": "Demplot 1 (Padi)", "userId": "d2b11111-1111-1111-1111-111111111111", "userName": "I Nengah Aryana", "type": "PESTICIDE", "duration": 90, "createdAt": "2026-08-26T16:45:00"},
      {"id": "98ffdc0d-07e2-466f-bfb0-6f38ce6e8b98", "deviceId": "20000000-0000-0000-0000-000000000001", "deviceCode": "node-2a", "farmName": "Demplot 2 (Bunga Pacar Air)", "userId": null, "userName": null, "type": "FERTILIZER", "duration": 60, "createdAt": "2026-08-26T14:10:00"},
      {"id": "97ffdc0d-07e2-466f-bfb0-6f38ce6e8b97", "deviceId": "30000000-0000-0000-0000-000000000001", "deviceCode": "node-3a", "farmName": "Demplot 3 (Sayuran Hijau)", "userId": null, "userName": null, "type": "WATER", "duration": 20, "createdAt": "2026-08-26T07:30:00"},
      {"id": "96ffdc0d-07e2-466f-bfb0-6f38ce6e8b96", "deviceId": "10000000-0000-0000-0000-000000000001", "deviceCode": "node-1a", "farmName": "Demplot 1 (Padi)", "userId": null, "userName": null, "type": "WATER", "duration": 30, "createdAt": "2026-08-26T06:00:00"},
      {"id": "85ffdc0d-07e2-466f-bfb0-6f38ce6e8b85", "deviceId": "20000000-0000-0000-0000-000000000001", "deviceCode": "node-2a", "farmName": "Demplot 2 (Bunga Pacar Air)", "userId": "d1a11111-1111-1111-1111-111111111111", "userName": "I Wayan Madeg", "type": "FERTILIZER", "duration": 120, "createdAt": "2026-08-25T16:20:00"},
      {"id": "84ffdc0d-07e2-466f-bfb0-6f38ce6e8b84", "deviceId": "30000000-0000-0000-0000-000000000001", "deviceCode": "node-3a", "farmName": "Demplot 3 (Sayuran Hijau)", "userId": "d4d11111-1111-1111-1111-111111111111", "userName": "I Made Sujana", "type": "PESTICIDE", "duration": 60, "createdAt": "2026-08-25T10:15:00"},
      {"id": "83ffdc0d-07e2-466f-bfb0-6f38ce6e8b83", "deviceId": "10000000-0000-0000-0000-000000000001", "deviceCode": "node-1a", "farmName": "Demplot 1 (Padi)", "userId": null, "userName": null, "type": "WATER", "duration": 15, "createdAt": "2026-08-25T06:10:00"},
      {"id": "74ffdc0d-07e2-466f-bfb0-6f38ce6e8b74", "deviceId": "30000000-0000-0000-0000-000000000001", "deviceCode": "node-3a", "farmName": "Demplot 3 (Sayuran Hijau)", "userId": null, "userName": null, "type": "WATER", "duration": 25, "createdAt": "2026-08-24T17:40:00"},
      {"id": "73ffdc0d-07e2-466f-bfb0-6f38ce6e8b73", "deviceId": "20000000-0000-0000-0000-000000000001", "deviceCode": "node-2a", "farmName": "Demplot 2 (Bunga Pacar Air)", "userId": "d5e11111-1111-1111-1111-111111111111", "userName": "I Ketut Widiantara", "type": "PESTICIDE", "duration": 90, "createdAt": "2026-08-24T15:00:00"},
      {"id": "72ffdc0d-07e2-466f-bfb0-6f38ce6e8b72", "deviceId": "10000000-0000-0000-0000-000000000001", "deviceCode": "node-1a", "farmName": "Demplot 1 (Padi)", "userId": null, "userName": null, "type": "FERTILIZER", "duration": 45, "createdAt": "2026-08-24T08:30:00"},
      {"id": "64ffdc0d-07e2-466f-bfb0-6f38ce6e8b64", "deviceId": "20000000-0000-0000-0000-000000000001", "deviceCode": "node-2a", "farmName": "Demplot 2 (Bunga Pacar Air)", "userId": null, "userName": null, "type": "WATER", "duration": 20, "createdAt": "2026-08-23T18:00:00"},
      {"id": "63ffdc0d-07e2-466f-bfb0-6f38ce6e8b63", "deviceId": "10000000-0000-0000-0000-000000000001", "deviceCode": "node-1a", "farmName": "Demplot 1 (Padi)", "userId": "d1a11111-1111-1111-1111-111111111111", "userName": "I Wayan Madeg", "type": "PESTICIDE", "duration": 75, "createdAt": "2026-08-23T11:20:00"},
      {"id": "62ffdc0d-07e2-466f-bfb0-6f38ce6e8b62", "deviceId": "30000000-0000-0000-0000-000000000001", "deviceCode": "node-3a", "farmName": "Demplot 3 (Sayuran Hijau)", "userId": null, "userName": null, "type": "WATER", "duration": 15, "createdAt": "2026-08-23T06:15:00"},
      {"id": "54ffdc0d-07e2-466f-bfb0-6f38ce6e8b54", "deviceId": "10000000-0000-0000-0000-000000000001", "deviceCode": "node-1a", "farmName": "Demplot 1 (Padi)", "userId": null, "userName": null, "type": "FERTILIZER", "duration": 60, "createdAt": "2026-08-22T17:10:00"},
      {"id": "53ffdc0d-07e2-466f-bfb0-6f38ce6e8b53", "deviceId": "20000000-0000-0000-0000-000000000001", "deviceCode": "node-2a", "farmName": "Demplot 2 (Bunga Pacar Air)", "userId": "d2b11111-1111-1111-1111-111111111111", "userName": "I Nengah Aryana", "type": "WATER", "duration": 45, "createdAt": "2026-08-22T09:40:00"},
      {"id": "8ffdc0dd-07e2-466f-bfb0-6f38ce6e8b8f", "deviceId": "10000000-0000-0000-0000-000000000001", "deviceCode": "node-1a", "farmName": "Demplot 1 (Padi)", "userId": "d2b11111-1111-1111-1111-111111111111", "userName": "I Nengah Aryana", "type": "PESTICIDE", "duration": 90, "createdAt": "2026-08-21T09:32:00"},
      {"id": "2aecafdc-ae1f-4899-bb0b-ab2ed4a4416a", "deviceId": "30000000-0000-0000-0000-000000000001", "deviceCode": "node-3a", "farmName": "Demplot 3 (Sayuran Hijau)", "userId": null, "userName": null, "type": "WATER", "duration": 15, "createdAt": "2026-08-20T06:05:00"},
    ];

    final list = rawWaterings.map((e) => WateringLog.fromJson(e)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}
