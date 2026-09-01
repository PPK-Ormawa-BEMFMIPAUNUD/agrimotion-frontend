enum AlertSeverity {
  info,
  warning,
  critical,
}

class AlertModel {
  final String id;
  final String deviceId;
  final String type;
  final String message;
  final String status;
  final DateTime createdAt;

  const AlertModel({
    required this.id,
    required this.deviceId,
    required this.type,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  String get title => type;
  String get description => message;
  DateTime get timestamp => createdAt;

  AlertSeverity get severity {
    final t = '$type $message'.toLowerCase();
    if (t.contains('crit') || t.contains('ekstrem') || t.contains('kritis')) {
      return AlertSeverity.critical;
    }
    if (t.contains('warn') || t.contains('tinggi') || t.contains('berkurang') || t.contains('peringatan')) {
      return AlertSeverity.warning;
    }
    return AlertSeverity.info;
  }

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      type: json['type'] as String,
      message: json['message'] as String,
      status: json['status'] as String? ?? 'UNRESOLVED',
      createdAt: DateTime.parse(json['createdAt'].toString()).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'type': type,
      'message': message,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
