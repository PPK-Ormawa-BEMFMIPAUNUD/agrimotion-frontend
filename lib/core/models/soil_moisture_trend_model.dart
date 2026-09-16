class SoilMoistureTrendModel {
  final DateTime date;
  final String dayName;
  final double avgSoilMoisture;

  const SoilMoistureTrendModel({
    required this.date,
    required this.dayName,
    required this.avgSoilMoisture,
  });

  factory SoilMoistureTrendModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate = DateTime.now();
    if (json['date'] != null) {
      parsedDate = DateTime.tryParse(json['date'].toString()) ?? DateTime.now();
    }

    double parsedMoisture = 0.0;
    final rawMoisture = json['avgSoilMoisture'] ?? json['avg_soil_moisture'];
    if (rawMoisture is num) {
      parsedMoisture = rawMoisture.toDouble();
    } else if (rawMoisture != null) {
      parsedMoisture = double.tryParse(rawMoisture.toString()) ?? 0.0;
    }

    return SoilMoistureTrendModel(
      date: parsedDate,
      dayName: json['dayName']?.toString() ?? '',
      avgSoilMoisture: parsedMoisture,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T').first,
      'dayName': dayName,
      'avgSoilMoisture': avgSoilMoisture,
    };
  }
}
