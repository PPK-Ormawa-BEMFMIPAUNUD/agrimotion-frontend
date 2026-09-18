/// Centralized API & network configuration for AgriMotion.
///
/// All backend endpoint paths and network tuning constants are defined here.
/// The backend is a NestJS application proxied via Nginx over HTTPS.
class ApiConstants {
  ApiConstants._();

  /// Base URL of the backend server.
  ///
  /// Override at build time with: `--dart-define=API_URL=https://agrimotion.id/api`
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://agrimotion.id/api',
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

  /// GET - Fetch 7-day soil moisture trend for a demplot.
  static String soilMoistureTrendEndpoint(dynamic demplotId, {int days = 7}) {
    final base = baseUrl.endsWith('/api')
        ? baseUrl.substring(0, baseUrl.length - 4)
        : baseUrl;
    return '$base/api/telemetry/trends/soil-moisture/$demplotId?days=$days';
  }

  static String analyticsOverviewEndpoint(dynamic demplotId, String period) {
    final base = baseUrl.endsWith('/api') ? baseUrl.substring(0, baseUrl.length - 4) : baseUrl;
    return '$base/api/telemetry/analytics/overview?demplotId=$demplotId&period=$period';
  }

  static String demplotAnalyticsEndpoint(int demplotId, {String period = '7d'}) {
    final base = baseUrl.endsWith('/api') ? baseUrl.substring(0, baseUrl.length - 4) : baseUrl;
    return '$base/api/analytics/demplot/$demplotId?period=$period';
  }

  static String get activitiesEndpoint {
    final base = baseUrl.endsWith('/api') ? baseUrl.substring(0, baseUrl.length - 4) : baseUrl;
    return '$base/api/activities';
  }

  static String activitySummaryEndpoint(int demplotId) {
    final base = baseUrl.endsWith('/api') ? baseUrl.substring(0, baseUrl.length - 4) : baseUrl;
    return '$base/api/activities/summary/$demplotId';
  }

  static String waterUsageAnalyticsEndpoint(String period) {
    final base = baseUrl.endsWith('/api') ? baseUrl.substring(0, baseUrl.length - 4) : baseUrl;
    return '$base/api/actuations/analytics/water-usage?period=$period';
  }

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
  // EWS Endpoints
  // ---------------------------------------------------------------------------

  /// GET - Fetch Early Warning System status for caterpillar pests.
  static const String ewsStatus = '/api/ews/status';

  /// Helper to get EWS Status URL dynamically based on baseUrl.
  static String ewsStatusEndpoint(int demplotId) {
    // Prevent double '/api' if baseUrl already ends with '/api'
    final base = baseUrl.endsWith('/api')
        ? baseUrl.substring(0, baseUrl.length - 4)
        : baseUrl;
    return '$base$ewsStatus/$demplotId';
  }

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
  // Crop Cycle Endpoints
  // ---------------------------------------------------------------------------

  static String cropCycleActiveEndpoint(int demplotId) {
    final base = baseUrl.endsWith('/api') ? baseUrl.substring(0, baseUrl.length - 4) : baseUrl;
    return '$base/api/crop-cycles/active/$demplotId';
  }

  static String get cropCycleStartEndpoint {
    final base = baseUrl.endsWith('/api') ? baseUrl.substring(0, baseUrl.length - 4) : baseUrl;
    return '$base/api/crop-cycles/start';
  }

  static String cropCycleHarvestEndpoint(String id) {
    final base = baseUrl.endsWith('/api') ? baseUrl.substring(0, baseUrl.length - 4) : baseUrl;
    return '$base/api/crop-cycles/harvest/$id';
  }

  static String cropCycleHistoryEndpoint(int demplotId) {
    final base = baseUrl.endsWith('/api') ? baseUrl.substring(0, baseUrl.length - 4) : baseUrl;
    return '$base/api/crop-cycles/history/$demplotId';
  }

  // ---------------------------------------------------------------------------
  // Timeouts & Intervals
  // ---------------------------------------------------------------------------

  /// Standard HTTP request timeout duration.
  static const Duration requestTimeout = Duration(seconds: 15);

  /// Polling interval for live dashboard data updates.
  static const Duration pollingInterval = Duration(seconds: 10);

  /// Duration after which sensor data is considered stale.
  static const Duration staleDataThreshold = Duration(minutes: 5);

  /// Maximum consecutive network failures before switching to backoff polling.
  static const int maxConsecutiveFailures = 3;

  /// Base backoff duration for reconnection attempts.
  static const Duration reconnectBackoffBase = Duration(seconds: 5);

  /// Maximum backoff duration for reconnection attempts.
  static const Duration reconnectBackoffMax = Duration(seconds: 60);

  // ---------------------------------------------------------------------------
  // WebSocket / SSE
  // ---------------------------------------------------------------------------

  /// WebSocket endpoint for real-time sensor streams (WSS).
  static const String wsEndpoint = 'wss://agrimotion.id/ws';

  /// Server-Sent Events endpoint for real-time server log streaming.
  static const String sseLogsEndpoint = '$baseUrl/server/logs/sse';

  // ---------------------------------------------------------------------------
  // MQTT Broker (Direct TCP for Hardware/Internal)
  // ---------------------------------------------------------------------------

  /// MQTT broker host address.
  static const String mqttHost = '103.174.114.65';

  /// MQTT broker port.
  static const int mqttPort = 1883;
}
