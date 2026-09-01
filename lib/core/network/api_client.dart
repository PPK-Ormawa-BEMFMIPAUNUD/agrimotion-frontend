import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:agrimotion/core/constants/api_constants.dart';
import 'package:agrimotion/features/auth/data/token_storage.dart';
import 'package:agrimotion/features/auth/presentation/controllers/auth_controller.dart';

// =============================================================================
// API CLIENT EXCEPTIONS
// =============================================================================

/// Base exception class for all HTTP and network communication errors.
class ApiException implements Exception {
  /// User-friendly descriptive error message in Indonesian.
  final String message;

  /// HTTP status code if available (e.g., 400, 401, 500).
  final int? statusCode;

  /// Raw response payload or underlying error details for diagnostic purposes.
  final dynamic details;

  const ApiException(
    this.message, {
    this.statusCode,
    this.details,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'ApiException (HTTP $statusCode): $message';
    }
    return 'ApiException: $message';
  }
}

/// Thrown when a network connectivity failure occurs (DNS lookup failure, offline, socket dropped).
class NetworkException extends ApiException {
  const NetworkException(
    super.message, {
    super.statusCode,
    super.details,
  });
}

/// Thrown when an HTTP request exceeds the maximum timeout duration.
class ApiTimeoutException extends ApiException {
  const ApiTimeoutException([
    super.message =
        'Koneksi ke server timeout (15 detik). Periksa koneksi internet Anda atau status backend.',
  ]) : super(statusCode: 408);
}

/// Thrown when the server returns HTTP 401 Unauthorized (invalid or expired JWT token).
class UnauthorizedException extends ApiException {
  const UnauthorizedException([
    super.message =
        'Sesi autentikasi telah berakhir atau tidak sah. Silakan login kembali.',
  ]) : super(statusCode: 401);
}

/// Thrown when the server returns HTTP 403 Forbidden (insufficient permissions).
class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message =
        'Akses ditolak. Anda tidak memiliki izin untuk mengakses resource ini.',
  ]) : super(statusCode: 403);
}

/// Thrown when the server returns HTTP 404 Not Found.
class NotFoundException extends ApiException {
  const NotFoundException([
    super.message = 'Resource yang diminta tidak ditemukan di server.',
  ]) : super(statusCode: 404);
}

/// Thrown when the server returns HTTP 500+ Internal Server Error.
class ServerException extends ApiException {
  const ServerException([
    super.message =
        'Terjadi kesalahan pada server backend. Silakan coba beberapa saat lagi.',
    int? statusCode = 500,
  ]) : super(statusCode: statusCode);
}

// =============================================================================
// API CLIENT
// =============================================================================

/// Callback type invoked when the API client detects an expired/invalid token.
///
/// Used by the router or auth controller to trigger automatic logout
/// and redirect to the login page.
typedef OnUnauthorizedCallback = void Function();

/// Robust HTTP client wrapper for the AgriMotion platform.
///
/// Features:
/// - Auto-injection of JWT Bearer tokens from [TokenStorage]
/// - Standard anti-caching HTTP headers
/// - Configurable request timeout (defaults to 15 seconds)
/// - Comprehensive error translation to structured [ApiException] subclasses
/// - 401 Unauthorized auto-handling: purges stored token and invokes [onUnauthorized]
/// - Cross-platform compatible (no `dart:io` dependency for Flutter Web)
class ApiClient {
  final http.Client _client;
  final TokenStorage _tokenStorage;
  final Duration _timeout;

  /// Optional callback invoked when an HTTP 401 is received.
  /// Set this to trigger auth state reset and router redirect to login.
  OnUnauthorizedCallback? onUnauthorized;

  /// Optional callback invoked when network connectivity changes.
  void Function(bool isOnline)? onConnectionChange;

  /// Creates a new [ApiClient] instance.
  ApiClient({
    http.Client? client,
    TokenStorage? tokenStorage,
    Duration? timeout,
    this.onUnauthorized,
    this.onConnectionChange,
  })  : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage.instance,
        _timeout = timeout ?? ApiConstants.requestTimeout;

  /// Default anti-cache headers injected into every outgoing request.
  static const Map<String, String> antiCacheHeaders = <String, String>{
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    'Pragma': 'no-cache',
    'Expires': '0',
    'Accept': 'application/json',
  };

  // ---------------------------------------------------------------------------
  // HEADER BUILDER
  // ---------------------------------------------------------------------------

  /// Combines default anti-cache headers, JWT Bearer token, and custom headers.
  Future<Map<String, String>> _buildHeaders({
    Map<String, String>? customHeaders,
    bool requiresAuth = true,
    bool isJsonBody = false,
  }) async {
    final Map<String, String> headers = <String, String>{
      ...antiCacheHeaders,
    };

    if (isJsonBody) {
      headers['Content-Type'] = 'application/json; charset=UTF-8';
    }

    if (requiresAuth) {
      final String? token = await _tokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    return headers;
  }

  /// Encodes body payload to JSON string if it is a `Map` or `List`.
  Object? _serializeBody(Object? body) {
    if (body == null) return null;
    if (body is String) return body;
    if (body is Map || body is List) {
      return jsonEncode(body);
    }
    return body;
  }

  /// Determines whether the body payload is JSON-serializable.
  bool _isJsonPayload(Object? body) {
    return body is Map || body is List;
  }

  // ---------------------------------------------------------------------------
  // REQUEST EXECUTOR WITH ERROR HANDLING
  // ---------------------------------------------------------------------------

  /// Wraps HTTP execution with timeout and network exception translation.
  ///
  /// Cross-platform: uses only `http.ClientException` for network errors
  /// (no `dart:io` `SocketException` for Flutter Web compatibility).
  Future<http.Response> _execute(
    Future<http.Response> Function() requestFn,
  ) async {
    try {
      final http.Response response = await requestFn().timeout(
        _timeout,
        onTimeout: () {
          throw ApiTimeoutException(
            'Koneksi ke server timeout (${_timeout.inSeconds} detik). '
            'Pastikan koneksi internet stabil dan backend aktif.',
          );
        },
      );
      onConnectionChange?.call(true);
      return response;
    } on http.ClientException catch (e) {
      onConnectionChange?.call(false);
      throw NetworkException(
        'Gagal terhubung ke server. Pastikan perangkat terhubung ke internet. (${e.message})',
      );
    } on FormatException catch (e) {
      throw ApiException(
        'Format data tidak valid: ${e.message}',
      );
    } on ApiTimeoutException {
      onConnectionChange?.call(false);
      rethrow;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        'Terjadi kesalahan komunikasi jaringan: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // HTTP METHODS
  // ---------------------------------------------------------------------------

  /// Performs an HTTP GET request.
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    bool requiresAuth = true,
  }) async {
    final Map<String, String> finalHeaders = await _buildHeaders(
      customHeaders: headers,
      requiresAuth: requiresAuth,
    );

    int retries = 0;
    const int maxRetries = 2;

    while (true) {
      try {
        final response = await _execute(
          () => _client.get(url, headers: finalHeaders),
        );
        if (response.statusCode == 502 || response.statusCode == 503) {
          if (retries < maxRetries) {
            retries++;
            await Future.delayed(const Duration(milliseconds: 1500));
            continue;
          }
        }
        return response;
      } on NetworkException {
        if (retries < maxRetries) {
          retries++;
          await Future.delayed(const Duration(milliseconds: 1500));
          continue;
        }
        rethrow;
      } on ApiTimeoutException {
        if (retries < maxRetries) {
          retries++;
          await Future.delayed(const Duration(milliseconds: 1500));
          continue;
        }
        rethrow;
      }
    }
  }

  /// Performs an HTTP POST request.
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool requiresAuth = true,
  }) async {
    final bool isJson = _isJsonPayload(body);
    final Object? serializedBody = _serializeBody(body);
    final Map<String, String> finalHeaders = await _buildHeaders(
      customHeaders: headers,
      requiresAuth: requiresAuth,
      isJsonBody: isJson,
    );

    return _execute(
      () => _client.post(
        url,
        headers: finalHeaders,
        body: serializedBody,
        encoding: encoding,
      ),
    );
  }

  /// Performs an HTTP PUT request.
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool requiresAuth = true,
  }) async {
    final bool isJson = _isJsonPayload(body);
    final Object? serializedBody = _serializeBody(body);
    final Map<String, String> finalHeaders = await _buildHeaders(
      customHeaders: headers,
      requiresAuth: requiresAuth,
      isJsonBody: isJson,
    );

    return _execute(
      () => _client.put(
        url,
        headers: finalHeaders,
        body: serializedBody,
        encoding: encoding,
      ),
    );
  }

  /// Performs an HTTP DELETE request.
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool requiresAuth = true,
  }) async {
    final bool isJson = _isJsonPayload(body);
    final Object? serializedBody = _serializeBody(body);
    final Map<String, String> finalHeaders = await _buildHeaders(
      customHeaders: headers,
      requiresAuth: requiresAuth,
      isJsonBody: isJson,
    );

    return _execute(
      () => _client.delete(
        url,
        headers: finalHeaders,
        body: serializedBody,
        encoding: encoding,
      ),
    );
  }

  /// Performs an HTTP PATCH request.
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    bool requiresAuth = true,
  }) async {
    final bool isJson = _isJsonPayload(body);
    final Object? serializedBody = _serializeBody(body);
    final Map<String, String> finalHeaders = await _buildHeaders(
      customHeaders: headers,
      requiresAuth: requiresAuth,
      isJsonBody: isJson,
    );

    return _execute(
      () => _client.patch(
        url,
        headers: finalHeaders,
        body: serializedBody,
        encoding: encoding,
      ),
    );
  }

  /// Performs an HTTP HEAD request.
  Future<http.Response> head(
    Uri url, {
    Map<String, String>? headers,
    bool requiresAuth = true,
  }) async {
    final Map<String, String> finalHeaders = await _buildHeaders(
      customHeaders: headers,
      requiresAuth: requiresAuth,
    );

    return _execute(
      () => _client.head(url, headers: finalHeaders),
    );
  }

  // ---------------------------------------------------------------------------
  // RESPONSE UTILITIES
  // ---------------------------------------------------------------------------

  /// Validates the [response] status code, returning the response if 2xx,
  /// or throwing a descriptive [ApiException] subclass if 4xx/5xx.
  ///
  /// On HTTP 401, automatically purges stored session and invokes [onUnauthorized].
  http.Response validateResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    switch (response.statusCode) {
      case 400:
        // Try to extract backend validation message
        String msg =
            'Permintaan tidak valid (HTTP 400). Periksa format data yang dikirim.';
        try {
          final dynamic body = jsonDecode(response.body);
          if (body is Map<String, dynamic>) {
            if (body['message'] is String) {
              msg = body['message'] as String;
            } else if (body['message'] is List &&
                (body['message'] as List).isNotEmpty) {
              msg = (body['message'] as List).first.toString();
            }
          }
        } catch (_) {}
        throw ApiException(msg, statusCode: 400, details: response.body);
      case 401:
        // Auto-purge session and notify listeners
        _handleUnauthorized();
        throw const UnauthorizedException();
      case 403:
        throw const ForbiddenException();
      case 404:
        throw const NotFoundException();
      case 408:
        throw const ApiTimeoutException();
      case 500:
      case 502:
      case 503:
      case 504:
        throw ServerException(
          'Server backend mengalami gangguan (HTTP ${response.statusCode}). Silakan coba lagi nanti.',
          response.statusCode,
        );
      default:
        throw ApiException(
          'Server merespons dengan kode status ${response.statusCode}.',
          statusCode: response.statusCode,
          details: response.body,
        );
    }
  }

  /// Parses JSON response body safely after validation.
  dynamic parseJson(http.Response response) {
    validateResponse(response);
    try {
      return jsonDecode(response.body);
    } catch (e) {
      throw ApiException(
        'Gagal mengurai respons JSON dari server: $e',
        statusCode: response.statusCode,
        details: response.body,
      );
    }
  }

  /// Internal handler for 401 Unauthorized responses.
  /// Clears stored token and invokes the [onUnauthorized] callback.
  void _handleUnauthorized() {
    _tokenStorage.clearSession();
    onUnauthorized?.call();
  }

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  /// Closes the underlying HTTP client and releases open network sockets.
  void dispose() {
    _client.close();
  }
}

// =============================================================================
// RIVERPOD PROVIDER
// =============================================================================

/// Tracks the global server connectivity state.
final serverOnlineStateProvider = StateProvider<bool>((ref) => true);

/// Riverpod provider for the singleton [ApiClient] instance.
final apiClientProvider = Provider<ApiClient>((ref) {
  final ApiClient client = ApiClient();
  client.onUnauthorized = () {
    ref.read(authProvider.notifier).forceLogout();
  };
  client.onConnectionChange = (bool isOnline) {
    if (ref.read(serverOnlineStateProvider) != isOnline) {
      ref.read(serverOnlineStateProvider.notifier).state = isOnline;
    }
  };
  ref.onDispose(() => client.dispose());
  return client;
});
