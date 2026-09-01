class FarmModel {
  final String id;
  final String name;
  final String commodity;
  final String location;
  final double? area;
  final String ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FarmModel({
    required this.id,
    required this.name,
    required this.commodity,
    required this.location,
    this.area,
    required this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FarmModel.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      return DateTime.tryParse(val.toString())?.toLocal() ?? DateTime.now();
    }

    return FarmModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      commodity: json['commodity']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      area: parseDouble(json['area']),
      ownerId: json['ownerId']?.toString() ?? json['owner_id']?.toString() ?? '',
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'commodity': commodity,
      'location': location,
      if (area != null) 'area': area,
      'ownerId': ownerId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
