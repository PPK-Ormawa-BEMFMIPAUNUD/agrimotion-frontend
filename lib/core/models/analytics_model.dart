class AnalyticsOverviewModel {
  final int demplotId;
  final String period;
  final int totalSamples;
  final double avgSoilMoisture;
  final double avgTemperature;
  final double avgHumidity;
  final double avgPh;
  final double avgNpkIndex;
  final int activeSensors;

  AnalyticsOverviewModel({
    required this.demplotId,
    required this.period,
    required this.totalSamples,
    required this.avgSoilMoisture,
    required this.avgTemperature,
    required this.avgHumidity,
    required this.avgPh,
    required this.avgNpkIndex,
    required this.activeSensors,
  });

  factory AnalyticsOverviewModel.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'] ?? {};
    return AnalyticsOverviewModel(
      demplotId: int.tryParse(json['demplotId']?.toString() ?? '0') ?? 0,
      period: json['period'] ?? 'week',
      totalSamples: json['totalSamples'] ?? 0,
      avgSoilMoisture: (metrics['avgSoilMoisture'] ?? 0).toDouble(),
      avgTemperature: (metrics['avgTemperature'] ?? 0).toDouble(),
      avgHumidity: (metrics['avgHumidity'] ?? 0).toDouble(),
      avgPh: (metrics['avgPh'] ?? 0).toDouble(),
      avgNpkIndex: (metrics['avgNpkIndex'] ?? 0).toDouble(),
      activeSensors: json['activeSensors'] ?? 0,
    );
  }
}

class CorrelationPointModel {
  final String label;
  final double temperature;
  final double humidity;
  final double soilMoisture;

  CorrelationPointModel({
    required this.label,
    required this.temperature,
    required this.humidity,
    required this.soilMoisture,
  });

  factory CorrelationPointModel.fromJson(Map<String, dynamic> json) {
    return CorrelationPointModel(
      label: json['label']?.toString() ?? '',
      temperature: (json['temperature'] ?? 0).toDouble(),
      humidity: (json['humidity'] ?? 0).toDouble(),
      soilMoisture: (json['soilMoisture'] ?? 0).toDouble(),
    );
  }
}

class WaterUsageDemplotModel {
  final int demplotIndex;
  final String name;
  final String commodity;
  final int totalDurationSeconds;
  final double estimatedLiters;
  final String status;

  WaterUsageDemplotModel({
    required this.demplotIndex,
    required this.name,
    required this.commodity,
    required this.totalDurationSeconds,
    required this.estimatedLiters,
    required this.status,
  });

  factory WaterUsageDemplotModel.fromJson(Map<String, dynamic> json) {
    return WaterUsageDemplotModel(
      demplotIndex: json['demplotIndex'] ?? 0,
      name: json['name'] ?? '',
      commodity: json['commodity'] ?? '',
      totalDurationSeconds: json['totalDurationSeconds'] ?? 0,
      estimatedLiters: (json['estimatedLiters'] ?? 0).toDouble(),
      status: json['status'] ?? '',
    );
  }
}

class WaterUsageAnalyticsModel {
  final String period;
  final double totalLiters;
  final List<WaterUsageDemplotModel> demplots;

  WaterUsageAnalyticsModel({
    required this.period,
    required this.totalLiters,
    required this.demplots,
  });

  factory WaterUsageAnalyticsModel.fromJson(Map<String, dynamic> json) {
    var list = json['demplots'] as List? ?? [];
    return WaterUsageAnalyticsModel(
      period: json['period'] ?? 'week',
      totalLiters: (json['totalLiters'] ?? 0).toDouble(),
      demplots: list.map((i) => WaterUsageDemplotModel.fromJson(i)).toList(),
    );
  }
}
