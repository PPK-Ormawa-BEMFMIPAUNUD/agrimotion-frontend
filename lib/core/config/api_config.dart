/// Centralized API configuration for AGRI-MOTION.
///
/// All API endpoints and network settings are defined here.
/// To switch environments (development ↔ production), only change
/// the [baseUrl] constant in this single file.
class ApiConfig {
  ApiConfig._(); // Prevent instantiation

  /// Base URL for the NestJS production API on the VPS.
  ///
  /// IMPORTANT: The NestJS backend runs on port 3001 and has NO global
  /// route prefix. Endpoints are directly off the root (e.g., /telemetry/latest).
  static const String baseUrl = 'http://103.174.114.65:3001';

  /// Endpoint to fetch the latest telemetry readings.
  /// Returns: { success: true, data: Telemetry[], meta: {...} }
  static const String latestTelemetryEndpoint = '$baseUrl/telemetry/latest';

  /// Endpoint to fetch paginated telemetry history.
  /// Returns: { success: true, data: Telemetry[], meta: { total, page, ... } }
  static const String telemetryHistoryEndpoint = '$baseUrl/telemetry/history';

  /// Polling interval for live sensor data on the dashboard.
  static const Duration pollingInterval = Duration(seconds: 10);

  /// HTTP request timeout — prevents hanging on unreachable servers.
  /// Set to 15s to account for cold-start latency on the VPS.
  static const Duration requestTimeout = Duration(seconds: 15);

  // ---------------------------------------------------------------------------
  // Reconnection & Resilience
  // ---------------------------------------------------------------------------

  /// Maximum consecutive fetch failures before switching to backoff polling.
  /// After this many failures, the polling interval gradually increases
  /// to avoid hammering a dead server while on mobile data.
  static const int maxConsecutiveFailures = 3;

  /// Base backoff interval (doubles with each consecutive failure).
  /// After [maxConsecutiveFailures], poll at: base × 2^(failures - max).
  static const Duration reconnectBackoffBase = Duration(seconds: 15);

  /// Maximum backoff interval cap (never poll slower than this).
  static const Duration reconnectBackoffMax = Duration(seconds: 60);

  /// If the newest telemetry timestamp is older than this, show a
  /// "data stale" warning even though the HTTP call itself succeeded.
  /// This catches MQTT broker outages where the server responds 200
  /// but the sensor data hasn't actually updated.
  static const Duration staleDataThreshold = Duration(minutes: 3);
}
