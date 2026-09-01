import 'package:agrimotion/core/constants/api_constants.dart';

/// Legacy API configuration class — delegates to [ApiConstants].
///
/// Maintained for backward compatibility with existing imports.
/// New code should import [ApiConstants] directly.
class ApiConfig {
  ApiConfig._();

  /// Base URL of the backend NestJS server.
  static const String baseUrl = ApiConstants.baseUrl;

  /// Endpoint to fetch the latest telemetry readings.
  static const String latestTelemetryEndpoint =
      ApiConstants.latestTelemetryEndpoint;

  /// Endpoint to fetch paginated telemetry history.
  static const String telemetryHistoryEndpoint =
      ApiConstants.telemetryHistoryEndpoint;

  /// Polling interval for live sensor data on the dashboard.
  static const Duration pollingInterval = ApiConstants.pollingInterval;

  /// HTTP request timeout.
  static const Duration requestTimeout = ApiConstants.requestTimeout;

  /// Maximum consecutive fetch failures before switching to backoff polling.
  static const int maxConsecutiveFailures =
      ApiConstants.maxConsecutiveFailures;

  /// Base backoff interval.
  static const Duration reconnectBackoffBase =
      ApiConstants.reconnectBackoffBase;

  /// Maximum backoff interval cap.
  static const Duration reconnectBackoffMax =
      ApiConstants.reconnectBackoffMax;

  /// Stale data warning threshold.
  static const Duration staleDataThreshold =
      ApiConstants.staleDataThreshold;
}
