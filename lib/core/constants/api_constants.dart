/// Centralized API & network configuration for AgriMotion.
///
/// All backend endpoint paths and network tuning constants are defined here.
/// The backend is a NestJS application running on the VPS with NO global route prefix.
class ApiConstants {
  ApiConstants._();

  /// Base URL of the backend NestJS server.
  ///
  /// Override at build time with: `--dart-define=API_URL=http://your-server:3001`
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://103.174.114.65:3001',
  );

  // ---------------------------------------------------------------------------
  // Auth Endpoints
  // ---------------------------------------------------------------------------

  /// POST - Authenticate user and receive JWT access token.
  static const String loginEndpoint = '$baseUrl/auth/login';

  /// POST - Register a new user account.
  static const String registerEndpoint = '$baseUrl/auth/register';

  /// GET - Fetch current authenticated user profile.
  static const String profileEndpoint = '$baseUrl/auth/profile';

  // ---------------------------------------------------------------------------
  // Telemetry Endpoints
  // ---------------------------------------------------------------------------

  /// GET - Fetch the latest telemetry data across demplots.
  /// Query params: `deviceId` (UUID), `limit`, `sort`
  static const String latestTelemetryEndpoint = '$baseUrl/telemetry/latest';

  /// GET - Fetch paginated historical telemetry data.
  /// Query params: `deviceId` (UUID), `date`, `page`, `limit`, `sort`
  static const String telemetryHistoryEndpoint = '$baseUrl/telemetry/history';

  // ---------------------------------------------------------------------------
  // Farm & Device Endpoints
  // ---------------------------------------------------------------------------

  /// GET - Fetch list of farms (demplots) with nested devices.
  static const String farmsEndpoint = '$baseUrl/farms';

  /// GET - Fetch all devices with their metadata.
  static const String devicesEndpoint = '$baseUrl/devices';

  /// GET - Fetch device online/offline status summary.
  static const String devicesStatusEndpoint = '$baseUrl/devices/status';

  // ---------------------------------------------------------------------------
  // User Management Endpoints
  // ---------------------------------------------------------------------------

  /// GET/POST - List all users or create a new user.
  static const String usersEndpoint = '$baseUrl/users';

  // ---------------------------------------------------------------------------
  // Alert Endpoints
  // ---------------------------------------------------------------------------

  /// GET - Fetch alert events and notifications.
  static const String alertsEndpoint = '$baseUrl/alerts';

  // ---------------------------------------------------------------------------
  // System Activity Log Endpoints
  // ---------------------------------------------------------------------------

  /// GET - Fetch cadre login audit logs.
  static const String userLoginsEndpoint = '$baseUrl/user-logins';

  /// GET - Fetch watering and actuation logs.
  static const String wateringLogsEndpoint = '$baseUrl/watering-logs';

  // ---------------------------------------------------------------------------
  // Server Monitoring Endpoints
  // ---------------------------------------------------------------------------

  /// GET - Fetch server health status (database, memory, disk, mqtt).
  static const String healthEndpoint = '$baseUrl/health';

  /// GET - Fetch system information (CPU, memory, uptime, services).
  static const String systemInfoEndpoint = '$baseUrl/system/info';

  // ---------------------------------------------------------------------------
  // Timeouts & Intervals
  // ---------------------------------------------------------------------------

  /// Standard HTTP request timeout duration.
  static const Duration requestTimeout = Duration(seconds: 8);

  /// Polling interval for live dashboard data updates.
  static const Duration pollingInterval = Duration(seconds: 10);

  /// Duration after which sensor data is considered stale.
  static const Duration staleDataThreshold = Duration(minutes: 3);

  /// Maximum consecutive network failures before switching to backoff polling.
  static const int maxConsecutiveFailures = 3;

  /// Base backoff duration for reconnection attempts.
  static const Duration reconnectBackoffBase = Duration(seconds: 15);

  /// Maximum backoff duration for reconnection attempts.
  static const Duration reconnectBackoffMax = Duration(seconds: 60);

  // ---------------------------------------------------------------------------
  // WebSocket / SSE
  // ---------------------------------------------------------------------------

  /// WebSocket endpoint for real-time sensor streams.
  static const String wsEndpoint = 'ws://103.174.114.65:3001/ws';

  /// Server-Sent Events endpoint for real-time server log streaming.
  static const String sseLogsEndpoint = '$baseUrl/server/logs/sse';

  // ---------------------------------------------------------------------------
  // MQTT Broker
  // ---------------------------------------------------------------------------

  /// MQTT broker host address.
  static const String mqttHost = '103.174.114.65';

  /// MQTT broker port.
  static const int mqttPort = 1883;
}
