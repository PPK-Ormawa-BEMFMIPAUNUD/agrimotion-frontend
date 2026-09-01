class TelemetryModel {
  final String id;
  final String deviceId;
  final DateTime timestamp;
  final double ph;
  final double soilMoisture;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double? temperature;
  final double? humidity;
  final double? lux;

  const TelemetryModel({
    required this.id,
    required this.deviceId,
    required this.timestamp,
    required this.ph,
    required this.soilMoisture,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    this.temperature,
    this.humidity,
    this.lux,
  });

  factory TelemetryModel.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    double? parseDoubleNullable(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    DateTime parsedTimestamp = DateTime.now();
    if (json['timestamp'] != null) {
      parsedTimestamp = DateTime.tryParse(json['timestamp'].toString())?.toLocal() ?? DateTime.now();
    } else if (json['createdAt'] != null) {
      parsedTimestamp = DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now();
    } else if (json['created_at'] != null) {
      parsedTimestamp = DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now();
    }

    return TelemetryModel(
      id: json['id']?.toString() ?? '',
      deviceId: json['deviceId']?.toString() ?? json['device_id']?.toString() ?? '',
      timestamp: parsedTimestamp,
      ph: parseDouble(json['ph'] ?? json['pH']),
      soilMoisture: parseDouble(json['soilMoisture'] ?? json['soil_moisture']),
      nitrogen: parseDouble(json['nitrogen'] ?? json['npk_n'] ?? json['npkN']),
      phosphorus: parseDouble(json['phosphorus'] ?? json['npk_p'] ?? json['npkP']),
      potassium: parseDouble(json['potassium'] ?? json['npk_k'] ?? json['npkK']),
      temperature: parseDoubleNullable(json['temperature']),
      humidity: parseDoubleNullable(json['humidity']),
      lux: parseDoubleNullable(json['lux']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'timestamp': timestamp.toIso8601String(),
      'ph': ph,
      'soilMoisture': soilMoisture,
      'nitrogen': nitrogen,
      'phosphorus': phosphorus,
      'potassium': potassium,
      if (temperature != null) 'temperature': temperature,
      if (humidity != null) 'humidity': humidity,
      if (lux != null) 'lux': lux,
    };
  }
}
