enum AlertSeverity { critical, warning, info }

class AlertModel {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final AlertSeverity severity;
  final String? deviceId;

  AlertModel({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.severity,
    this.deviceId,
  });
}
