class WateringLogModel {
  final String id;
  final String deviceId;
  final String? userId;
  final String type;
  final int duration;
  final DateTime createdAt;

  const WateringLogModel({
    required this.id,
    required this.deviceId,
    this.userId,
    required this.type,
    required this.duration,
    required this.createdAt,
  });

  factory WateringLogModel.fromJson(Map<String, dynamic> json) {
    return WateringLogModel(
      id: json['id']?.toString() ?? '',
      deviceId: json['deviceId']?.toString() ?? json['device_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString(),
      type: json['type']?.toString().toUpperCase() ?? 'WATER',
      duration: json['duration'] != null ? (int.tryParse(json['duration'].toString()) ?? 0) : 0,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now())
          : (DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      if (userId != null) 'userId': userId,
      'type': type,
      'duration': duration,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
