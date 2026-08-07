import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/sensor_data.dart';

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

  SensorService({http.Client? client}) : _client = client ?? http.Client();

  /// Standard HTTP request headers to completely bypass client and proxy caching.
  /// Uses headers rather than URL query parameters to avoid NestJS DTO ValidationPipe 400 errors.
  Map<String, String> get _antiCacheHeaders => const {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
        'Accept': 'application/json',
      };

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
    } on SocketException catch (e) {
      throw Exception(
        'Gagal terhubung ke server: ${e.message}. '
        'Pastikan perangkat terhubung ke internet dan VPS aktif.',
      );
    } on http.ClientException catch (e) {
      throw Exception('Kesalahan koneksi HTTP: ${e.message}');
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
    return allData
        .where((item) => item.farmId == farmId)
        .toList();
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
          final filtered = items.where((item) =>
              (item.deviceId != null &&
                  item.deviceId!.toLowerCase() == deviceId.toLowerCase()) ||
              (item.deviceCode != null &&
                  item.deviceCode!.toLowerCase() == deviceId.toLowerCase())).toList();
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
    } on SocketException catch (e) {
      throw Exception(
        'Gagal terhubung ke server: ${e.message}. '
        'Pastikan perangkat terhubung ke internet dan VPS aktif.',
      );
    } on http.ClientException catch (e) {
      throw Exception('Kesalahan koneksi HTTP: ${e.message}');
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
          final filtered = items.where((item) =>
              (item.deviceId != null &&
                  item.deviceId!.toLowerCase() == deviceId.toLowerCase()) ||
              (item.deviceCode != null &&
                  item.deviceCode!.toLowerCase() == deviceId.toLowerCase())).toList();
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

  void dispose() {
    _client.close();
  }
}
