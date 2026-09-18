import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/auth/data/token_storage.dart';
import '../config/api_config.dart';
import '../models/sensor_data.dart';
import '../models/ews_status_model.dart';
import '../models/soil_moisture_trend_model.dart';
import '../models/analytics_model.dart';
import '../constants/api_constants.dart';
import 'ews_service.dart';

/// Service responsible for fetching sensor telemetry data
/// from the NestJS production API at the VPS.
///
/// Features:
/// 1. Anti-caching HTTP Headers to prevent HTTP caching without adding non-whitelisted URL query parameters.
/// 2. Safe device ID filtering support with fallback to client-side filtering.
/// 3. Automatic sorting of telemetry items by timestamp DESCENDING (newest first).
/// 4. Multi-device support: fetch all telemetry or filter by deviceId UUID / farmId.
class SensorService {
  final http.Client _client;
  final EwsService _ewsService;

  SensorService({http.Client? client}) 
      : _client = client ?? http.Client(),
        _ewsService = EwsService(client: client ?? http.Client());

  /// Fetches EWS status for a specific demplot via [EwsService].
  Future<EwsStatusModel> fetchEwsStatus(int demplotId) async {
    return await _ewsService.fetchEwsStatus(demplotId);
  }

  /// Standard HTTP request headers to completely bypass client and proxy caching.
  /// Uses headers rather than URL query parameters to avoid NestJS DTO ValidationPipe 400 errors.
  Map<String, String> get _antiCacheHeaders => const {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
        'Accept': 'application/json',
      };

  /// Builds headers with optional JWT Authorization token from TokenStorage.
  Future<Map<String, String>> _getHeaders({bool requiresAuth = false}) async {
    final headers = Map<String, String>.from(_antiCacheHeaders);
    headers['Content-Type'] = 'application/json';
    final token = await TokenStorage.instance.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Builds a URI with optional `deviceId` query parameter.
  ///
  /// IMPORTANT: [deviceId] must be a valid UUID (e.g., "10000000-0000-0000-0000-000000000001").
  /// Sending a string device code like "node-a" will cause HTTP 400 / PostgreSQL P2007 error.
  Uri _buildUri(String baseUrlEndpoint, {String? deviceId}) {
    final uri = Uri.parse(baseUrlEndpoint);
    if (deviceId != null &&
        deviceId.isNotEmpty &&
        deviceId.toUpperCase() != 'ALL') {
      return uri.replace(queryParameters: {'deviceId': deviceId});
    }
    return uri;
  }

  // ===========================================================================
  // PRIMARY FETCH METHODS
  // ===========================================================================

  /// Fetches ALL latest telemetry data from the backend (all devices/nodes).
  ///
  /// Returns a list of [SensorData] sorted descending by timestamp.
  /// This is the recommended method for the dashboard to populate all Demplot data at once.
  Future<List<SensorData>> fetchAllLatestTelemetry() async {
    try {
      final uri = Uri.parse(ApiConfig.latestTelemetryEndpoint);
      final response = await _client
          .get(uri, headers: _antiCacheHeaders)
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        final items = _extractSensorDataList(body);
        items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return items;
      } else {
        throw _buildHttpException(response.statusCode);
      }
    } on TimeoutException {
      throw Exception(
        'Koneksi ke server timeout (${ApiConfig.requestTimeout.inSeconds}s). '
        'Pastikan VPS backend aktif dan port ${Uri.parse(ApiConfig.baseUrl).port} terbuka.',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Gagal terhubung ke server: ${e.message}. '
        'Pastikan perangkat terhubung ke internet dan VPS aktif.',
      );
    } on FormatException {
      throw Exception(
        'Respons dari server bukan JSON valid. Periksa backend logs.',
      );
    }
  }

  /// Fetches telemetry data for all devices in a specific Demplot (farm),
  /// filtering client-side by [farmId].
  ///
  /// Returns a list of [SensorData] for nodes belonging to the given farm UUID.
  Future<List<SensorData>> fetchTelemetryByFarmId(String farmId) async {
    final allData = await fetchAllLatestTelemetry();
    return allData.where((item) => item.farmId == farmId).toList();
  }

  /// Fetches the latest sensor telemetry data from the production backend
  /// for a single device identified by its UUID.
  ///
  /// [deviceId] MUST be a valid UUID. Passing a device code string like
  /// "node-a" will cause HTTP 400 Bad Request from the backend.
  ///
  /// Parses the response array/object, sorts items descending by timestamp,
  /// and returns the most recent telemetry record.
  Future<SensorData> fetchLatestSensorData({String? deviceId}) async {
    try {
      Uri uri =
          _buildUri(ApiConfig.latestTelemetryEndpoint, deviceId: deviceId);
      http.Response response = await _client
          .get(uri, headers: _antiCacheHeaders)
          .timeout(ApiConfig.requestTimeout);

      // Fallback: If server returns HTTP 400 Bad Request (e.g. query param not whitelisted in DTO),
      // retry fetching without query parameters and filter client-side.
      if (response.statusCode == 400 &&
          deviceId != null &&
          deviceId.toUpperCase() != 'ALL') {
        uri = Uri.parse(ApiConfig.latestTelemetryEndpoint);
        response = await _client
            .get(uri, headers: _antiCacheHeaders)
            .timeout(ApiConfig.requestTimeout);
      }

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        List<SensorData> items = _extractSensorDataList(body);

        if (items.isEmpty) {
          throw Exception(
            'Belum ada data telemetri di database. '
            'Pastikan perangkat ESP32 sudah mengirim data melalui MQTT.',
          );
        }

        // Filter by deviceId client-side as fallback if server returns all devices
        if (deviceId != null &&
            deviceId.isNotEmpty &&
            deviceId.toUpperCase() != 'ALL') {
          final filtered = items
              .where((item) =>
                  (item.deviceId != null &&
                      item.deviceId!.toLowerCase() == deviceId.toLowerCase()) ||
                  (item.deviceCode != null &&
                      item.deviceCode!.toLowerCase() == deviceId.toLowerCase()))
              .toList();
          if (filtered.isNotEmpty) {
            items = filtered;
          }
        }

        // SORT DESCENDING BY TIMESTAMP (NEWEST FIRST)
        items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // Return index 0 (the newest telemetry record)
        return items.first;
      } else {
        throw _buildHttpException(response.statusCode);
      }
    } on TimeoutException {
      throw Exception(
        'Koneksi ke server timeout (${ApiConfig.requestTimeout.inSeconds}s). '
        'Pastikan VPS backend aktif dan port ${Uri.parse(ApiConfig.baseUrl).port} terbuka.',
      );
    } on http.ClientException catch (e) {
      throw Exception(
        'Gagal terhubung ke server: ${e.message}. '
        'Pastikan perangkat terhubung ke internet dan VPS aktif.',
      );
    } on FormatException {
      throw Exception(
        'Respons dari server bukan JSON valid. Periksa backend logs.',
      );
    }
  }

  /// Fetches a list of telemetry entries, sorted descending by timestamp.
  Future<List<SensorData>> fetchTelemetryList(
      {String? deviceId, int limit = 20}) async {
    try {
      Uri uri =
          _buildUri(ApiConfig.latestTelemetryEndpoint, deviceId: deviceId);
      http.Response response = await _client
          .get(uri, headers: _antiCacheHeaders)
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 400 &&
          deviceId != null &&
          deviceId.toUpperCase() != 'ALL') {
        uri = Uri.parse(ApiConfig.latestTelemetryEndpoint);
        response = await _client
            .get(uri, headers: _antiCacheHeaders)
            .timeout(ApiConfig.requestTimeout);
      }

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        List<SensorData> items = _extractSensorDataList(body);

        if (deviceId != null &&
            deviceId.isNotEmpty &&
            deviceId.toUpperCase() != 'ALL') {
          final filtered = items
              .where((item) =>
                  (item.deviceId != null &&
                      item.deviceId!.toLowerCase() == deviceId.toLowerCase()) ||
                  (item.deviceCode != null &&
                      item.deviceCode!.toLowerCase() == deviceId.toLowerCase()))
              .toList();
          if (filtered.isNotEmpty) {
            items = filtered;
          }
        }

        // Sort descending by timestamp (newest first)
        items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return items.take(limit).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  /// Helper to extract list of SensorData from various JSON wrapper formats.
  List<SensorData> _extractSensorDataList(dynamic body) {
    final List<SensorData> results = [];

    if (body is Map<String, dynamic>) {
      if (body.containsKey('data')) {
        final rawData = body['data'];
        if (rawData is List) {
          for (final item in rawData) {
            if (item is Map<String, dynamic>) {
              results.add(SensorData.fromJson(item));
            }
          }
        } else if (rawData is Map<String, dynamic>) {
          results.add(SensorData.fromJson(rawData));
        }
      } else if (body.containsKey('lux') ||
          body.containsKey('temperature') ||
          body.containsKey('soilMoisture') ||
          body.containsKey('nitrogen')) {
        results.add(SensorData.fromJson(body));
      }
    } else if (body is List) {
      for (final item in body) {
        if (item is Map<String, dynamic>) {
          results.add(SensorData.fromJson(item));
        }
      }
    }

    return results;
  }

  /// Builds a descriptive exception for non-200 HTTP status codes.
  Exception _buildHttpException(int statusCode) {
    switch (statusCode) {
      case 400:
        return Exception(
          'Server merespons dengan HTTP 400 (Bad Request). '
          'Periksa skema respons backend di ${ApiConfig.latestTelemetryEndpoint}.',
        );
      case 401:
        return Exception(
          'Akses ditolak (HTTP 401). Endpoint memerlukan autentikasi JWT.',
        );
      case 404:
        return Exception(
          'Endpoint tidak ditemukan (HTTP 404). '
          'Periksa URL: ${ApiConfig.latestTelemetryEndpoint}',
        );
      default:
        return Exception(
          'Server merespons dengan HTTP $statusCode.',
        );
    }
  }

  /// Fetches 7-day soil moisture trends for a specific Demplot.
  Future<List<SoilMoistureTrendModel>> fetchSoilMoistureTrends(
    dynamic demplotId, {
    int days = 7,
  }) async {
    try {
      final endpoint = ApiConstants.soilMoistureTrendEndpoint(demplotId, days: days);
      final uri = Uri.parse(endpoint);
      final response = await _client
          .get(uri, headers: _antiCacheHeaders)
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        List<dynamic> list = [];
        if (body is Map<String, dynamic> && body['data'] is List) {
          list = body['data'] as List;
        } else if (body is List) {
          list = body;
        }
        return list
            .map((item) => SoilMoistureTrendModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw _buildHttpException(response.statusCode);
      }
    } on TimeoutException {
      throw Exception('Koneksi ke server timeout saat mengambil tren kelembaban tanah.');
    } on http.ClientException catch (e) {
      throw Exception('Gagal terhubung ke server: ${e.message}');
    } catch (e) {
      throw Exception('Gagal memuat tren kelembaban: $e');
    }
  }

  Future<AnalyticsOverviewModel> fetchAnalyticsOverview(dynamic demplotId, String period) async {
    try {
      final endpoint = ApiConstants.analyticsOverviewEndpoint(demplotId, period);
      final response = await _client.get(Uri.parse(endpoint), headers: _antiCacheHeaders).timeout(ApiConfig.requestTimeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return AnalyticsOverviewModel.fromJson(body['data'] ?? body);
      } else {
        throw _buildHttpException(response.statusCode);
      }
    } catch (e) {
      throw Exception('Gagal memuat overview analitik: $e');
    }
  }

  /// Fetches latest telemetry for a specific demplot or device.
  /// Guarantees integer parsing of demplotId (0, 1, 2) and graceful empty state.
  Future<SensorData?> fetchLatestTelemetry({dynamic demplotId, String? deviceId}) async {
    try {
      final Map<String, String> queryParams = {};
      if (demplotId != null) {
        final parsed = int.tryParse(demplotId.toString());
        if (parsed != null) {
          queryParams['demplotId'] = parsed.toString();
        }
      }
      if (deviceId != null && deviceId.isNotEmpty && deviceId.toUpperCase() != 'ALL') {
        queryParams['deviceId'] = deviceId;
      }

      Uri uri = Uri.parse(ApiConfig.latestTelemetryEndpoint);
      if (queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await _client
          .get(uri, headers: _antiCacheHeaders)
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final dynamic jsonBody = jsonDecode(response.body);
        final dynamic data = jsonBody is Map<String, dynamic> ? jsonBody['data'] : jsonBody;
        if (data == null) {
          return null;
        }
        if (data is List) {
          if (data.isEmpty) return null;
          return SensorData.fromJson(data.first as Map<String, dynamic>);
        }
        return SensorData.fromJson(data as Map<String, dynamic>);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<DemplotAnalyticsModel?> fetchDemplotAnalytics(int demplotId, {String period = '7d'}) async {
    try {
      final endpoint = ApiConstants.demplotAnalyticsEndpoint(demplotId, period: period);
      final headers = await _getHeaders();
      final response = await _client
          .get(Uri.parse(endpoint), headers: headers)
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final dynamic data = body is Map<String, dynamic> ? (body['data'] ?? body) : body;
        if (data == null) return null;
        return DemplotAnalyticsModel.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<FarmActivityModel>> fetchActivities({required int demplotId, String? type, int limit = 20}) async {
    try {
      final uri = Uri.parse(ApiConstants.activitiesEndpoint).replace(queryParameters: {
        'demplotId': demplotId.toString(),
        if (type != null && type.isNotEmpty && type != 'Semua') 'type': type,
        'limit': limit.toString(),
      });
      final headers = await _getHeaders();
      final response = await _client.get(uri, headers: headers).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final rawData = body is Map<String, dynamic> ? (body['data'] ?? body) : body;
        if (rawData is List) {
          return rawData.whereType<Map<String, dynamic>>().map((e) => FarmActivityModel.fromJson(e)).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<FarmActivitySummaryModel?> fetchActivitySummary(int demplotId) async {
    try {
      final endpoint = ApiConstants.activitySummaryEndpoint(demplotId);
      final headers = await _getHeaders();
      final response = await _client.get(Uri.parse(endpoint), headers: headers).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final dynamic data = body is Map<String, dynamic> ? (body['data'] ?? body) : body;
        if (data == null) return null;
        return FarmActivitySummaryModel.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> createActivity(Map<String, dynamic> payload) async {
    try {
      final uri = Uri.parse(ApiConstants.activitiesEndpoint);
      final headers = await _getHeaders(requiresAuth: true);
      final response = await _client
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<WaterUsageAnalyticsModel?> fetchWaterUsageAnalytics(String period) async {
    try {
      final endpoint = ApiConstants.waterUsageAnalyticsEndpoint(period);
      final headers = await _getHeaders(requiresAuth: true);
      final response = await _client
          .get(Uri.parse(endpoint), headers: headers)
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final dynamic data = body is Map<String, dynamic> ? (body['data'] ?? body) : body;
        if (data == null) {
          return null;
        }
        return WaterUsageAnalyticsModel.fromJson(data as Map<String, dynamic>);
      } else if (response.statusCode == 401) {
        await TokenStorage.instance.clearSession();
        throw Exception('Sesi Anda telah berakhir, silakan login kembali.');
      } else {
        throw _buildHttpException(response.statusCode);
      }
    } on TimeoutException {
      throw Exception('Koneksi ke server timeout saat memuat data penggunaan air.');
    } on http.ClientException catch (e) {
      throw Exception('Gagal terhubung ke server: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  void dispose() {
    _client.close();
  }
}
