/// Application-wide constants for AgriMotion.
class AppConstants {
  AppConstants._();

  /// Name of the application.
  static const String appName = 'AgriMotion';

  /// Application tagline.
  static const String appTagline = 'Smart Agriculture IoT Platform';

  /// Organization / developer team name.
  static const String organizationName = 'PPKO BEM FMIPA Universitas Udayana';

  /// Application semantic version.
  static const String version = '2.0.0';

  // Sensor Thresholds
  /// Minimum optimal soil moisture percentage (%).
  static const double moistureOptimalMin = 40.0;

  /// Maximum optimal soil moisture percentage (%).
  static const double moistureOptimalMax = 70.0;

  /// Minimum warning threshold for soil moisture (%).
  static const double moistureWarningMin = 25.0;

  /// Critical minimum threshold for soil moisture (%).
  static const double moistureCriticalMin = 15.0;

  /// Minimum optimal soil pH value.
  static const double phOptimalMin = 6.0;

  /// Maximum optimal soil pH value.
  static const double phOptimalMax = 7.5;

  /// Minimum warning threshold for soil pH.
  static const double phWarningMin = 5.5;

  /// Maximum warning threshold for soil pH.
  static const double phWarningMax = 8.0;

  /// Minimum optimal ambient temperature in Celsius (°C).
  static const double tempOptimalMin = 20.0;

  /// Maximum optimal ambient temperature in Celsius (°C).
  static const double tempOptimalMax = 32.0;

  /// Maximum warning threshold for ambient temperature in Celsius (°C).
  static const double tempWarningMax = 35.0;

  /// Minimum optimal relative humidity percentage (%).
  static const double humidityOptimalMin = 60.0;

  /// Maximum optimal relative humidity percentage (%).
  static const double humidityOptimalMax = 80.0;

  // Breakpoints
  /// Minimum viewport width considered as desktop screen.
  static const double desktopBreakpoint = 1024.0;

  /// Minimum viewport width considered as tablet screen.
  static const double tabletBreakpoint = 768.0;

  // Sidebar
  /// Width of the navigation sidebar when fully expanded.
  static const double sidebarExpandedWidth = 260.0;

  /// Width of the navigation sidebar when collapsed to icon-only mode.
  static const double sidebarCollapsedWidth = 72.0;
}

/// User roles supported within the AgriMotion ecosystem.
enum UserRole {
  admin('ADMIN'),
  kaderDigital('KADER_DIGITAL'),
  operator_('OPERATOR'),
  user('USER');

  final String value;
  const UserRole(this.value);

  /// Parse a string role identifier into a corresponding [UserRole].
  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.value == value.toUpperCase(),
      orElse: () => UserRole.user,
    );
  }
}

/// Health and operational status of an individual sensor parameter.
enum SensorStatus {
  optimal,
  warning,
  danger,
  offline,
  unknown;

  /// Indonesian display label for the sensor status.
  String get label {
    switch (this) {
      case SensorStatus.optimal:
        return 'Optimal';
      case SensorStatus.warning:
        return 'Peringatan';
      case SensorStatus.danger:
        return 'Bahaya';
      case SensorStatus.offline:
        return 'Offline';
      case SensorStatus.unknown:
        return 'N/A';
    }
  }
}

/// Time range filter presets for charts and telemetry analytics.
enum TimeRange {
  day24h('24 Jam'),
  week7d('7 Hari'),
  month30d('30 Hari');

  final String label;
  const TimeRange(this.label);
}
