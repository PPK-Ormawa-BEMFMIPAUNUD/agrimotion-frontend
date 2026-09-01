class DeviceModel {
  final String id;
  final String deviceCode;
  final String espSerial;
  final String farmId;
  final String status;
  final DateTime? lastOnline;
  final double? battery;
  final int? signal;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DeviceModel({
    required this.id,
    required this.deviceCode,
    required this.espSerial,
    required this.farmId,
    required this.status,
    this.lastOnline,
    this.battery,
    this.signal,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString());
    }

    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      return DateTime.tryParse(val.toString())?.toLocal() ?? DateTime.now();
    }

    return DeviceModel(
      id: json['id']?.toString() ?? '',
      deviceCode: json['deviceCode']?.toString() ?? json['device_code']?.toString() ?? '',
      espSerial: json['espSerial']?.toString() ?? json['esp_serial']?.toString() ?? '',
      farmId: json['farmId']?.toString() ?? json['farm_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OFFLINE',
      lastOnline: json['lastOnline'] != null
          ? DateTime.tryParse(json['lastOnline'].toString())?.toLocal()
          : (json['last_online'] != null ? DateTime.tryParse(json['last_online'].toString())?.toLocal() : null),
      battery: parseDouble(json['battery']),
      signal: parseInt(json['signal']),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceCode': deviceCode,
      'espSerial': espSerial,
      'farmId': farmId,
      'status': status,
      if (lastOnline != null) 'lastOnline': lastOnline!.toIso8601String(),
      if (battery != null) 'battery': battery,
      if (signal != null) 'signal': signal,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
