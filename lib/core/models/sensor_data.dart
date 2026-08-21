/// Data model representing a single aggregated sensor telemetry reading
/// from the NestJS backend.
///
/// Maps directly to the JSON response of `GET /telemetry/latest`
/// which returns telemetry data from ESP32 nodes:
/// ```json
/// {
///   "id": "...",
///   "deviceId": "...",
///   "timestamp": "2026-08-03T08:31:14.495Z",
///   "nitrogen": 23,
///   "phosphorus": 99,
///   "potassium": 92,
///   "ph": 6.5,
///   "soilMoisture": 70.5,
///   "temperature": 29.19,
///   "humidity": 75.79,
///   "lux": 22.5,
///   "device": {
///     "id": "...",
///     "deviceCode": "node-1a",
///     "farmId": "11111111-1111-1111-1111-111111111111",
///     "status": "ONLINE",
///     "battery": 95,
///     "signal": -68,
///     "lastOnline": "2026-08-03T08:31:14.493Z",
///     ...
///   }
/// }
/// ```
class SensorData {
  final String? id;
  final String? deviceId;
  final String? deviceCode;
  final String? deviceName;
  final String? deviceStatus;
  final String? farmId;
  final double? battery;
  final int? signal;
  final DateTime? lastOnline;

  // Sensor values — nullable to handle backend returning `null`
  // (e.g., Demplot 3 node-3a may return nitrogen/phosphorus/potassium/lux as null)
  final double? lux;
  final double? temperature;
  final double? humidity;
  final double? soilMoisture;
  final double? ph;
  final double? npkN;
  final double? npkP;
  final double? npkK;
  final DateTime timestamp;

  const SensorData({
    this.id,
    this.deviceId,
    this.deviceCode,
    this.deviceName,
    this.deviceStatus,
    this.farmId,
    this.battery,
    this.signal,
    this.lastOnline,
    this.lux,
    this.temperature,
    this.humidity,
    this.soilMoisture,
    this.ph,
    this.npkN,
    this.npkP,
    this.npkK,
    required this.timestamp,
  });

  /// Creates a [SensorData] from the NestJS API JSON response.
  factory SensorData.fromJson(Map<String, dynamic> json) {
    final device = json['device'] as Map<String, dynamic>?;

    final String? parsedDeviceId = json['deviceId']?.toString() ??
        json['device_id']?.toString() ??
        device?['id']?.toString();

    final String? parsedDeviceCode = device?['deviceCode'] as String? ??
        device?['code'] as String? ??
        parsedDeviceId;

    final String? parsedDeviceName =
        device?['name'] as String? ?? device?['deviceName'] as String?;

    final String? parsedFarmId = device?['farmId']?.toString();

    final DateTime? parsedLastOnline =
        device != null ? _parseTimestampNullable(device['lastOnline']) : null;

    return SensorData(
      id: json['id']?.toString(),
      deviceId: parsedDeviceId,
      deviceCode: parsedDeviceCode,
      deviceName: parsedDeviceName,
      deviceStatus: device?['status'] as String?,
      farmId: parsedFarmId,
      battery: device != null ? _toDoubleNullable(device['battery']) : null,
      signal: device?['signal'] as int?,
      lastOnline: parsedLastOnline,
      lux: _toDoubleNullable(json['lux']),
      temperature: _toDoubleNullable(json['temperature']),
      humidity: _toDoubleNullable(json['humidity']),
      soilMoisture:
          _toDoubleNullable(json['soilMoisture'] ?? json['soil_moisture']),
      ph: _toDoubleNullable(json['ph']),
      npkN:
          _toDoubleNullable(json['nitrogen'] ?? json['npk_n'] ?? json['npkN']),
      npkP: _toDoubleNullable(
          json['phosphorus'] ?? json['npk_p'] ?? json['npkP']),
      npkK:
          _toDoubleNullable(json['potassium'] ?? json['npk_k'] ?? json['npkK']),
      timestamp: _parseTimestamp(json['timestamp'] ?? json['createdAt']),
    );
  }

  /// Empty sensor data — used only as initial state before API response.
  factory SensorData.empty() {
    return SensorData(
      id: null,
      deviceId: null,
      deviceCode: null,
      deviceName: null,
      deviceStatus: null,
      farmId: null,
      battery: null,
      signal: null,
      lastOnline: null,
      lux: null,
      temperature: null,
      humidity: null,
      soilMoisture: null,
      ph: null,
      npkN: null,
      npkP: null,
      npkK: null,
      timestamp: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static double? _toDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  static DateTime? _parseTimestampNullable(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  // ---------------------------------------------------------------------------
  // Display getters
  // ---------------------------------------------------------------------------

  /// Formatted NPK index string for display (e.g., "12 / 45 / 35").
  /// Returns "N/A" if all NPK values are null.
  String get npkDisplay {
    final n = npkN != null ? npkN!.toStringAsFixed(0) : '-';
    final p = npkP != null ? npkP!.toStringAsFixed(0) : '-';
    final k = npkK != null ? npkK!.toStringAsFixed(0) : '-';
    if (npkN == null && npkP == null && npkK == null) return 'N/A';
    return '$n / $p / $k';
  }

  /// Formatted timestamp string in local time (e.g., "26 Jul 2026, 14:49:52").
  String get formattedTimestamp {
    final local = timestamp.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    final month = monthNames[local.month - 1];
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute:$second';
  }

  /// Human-readable "time ago" string calculated against local timezone.
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(timestamp.toLocal());

    if (diff.isNegative || diff.inSeconds < 10) return 'Baru saja';
    if (diff.inSeconds < 60) return '${diff.inSeconds} detik lalu';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  /// Human-readable "time ago" string for [lastOnline] timestamp.
  String get lastOnlineAgo {
    if (lastOnline == null) return 'N/A';
    final now = DateTime.now();
    final diff = now.difference(lastOnline!.toLocal());

    if (diff.isNegative || diff.inSeconds < 10) return 'Baru saja';
    if (diff.inSeconds < 60) return '${diff.inSeconds} detik lalu';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  /// Whether the device reports ONLINE status.
  bool get isDeviceOnline => deviceStatus?.toUpperCase() == 'ONLINE';

  /// Safe display value for a nullable double sensor reading.
  /// Returns formatted string or 'N/A' if null.
  static String formatValue(double? value, {int decimals = 1}) {
    if (value == null) return 'N/A';
    return value.toStringAsFixed(decimals);
  }
}
