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

class FarmActivityModel {
  final String id;
  final int demplotId;
  final String? cropCycleId;
  final String type;
  final double? volumeLiter;
  final String? substanceName;
  final String? dosage;
  final String? notes;
  final DateTime executedAt;

  FarmActivityModel({
    required this.id,
    required this.demplotId,
    this.cropCycleId,
    required this.type,
    this.volumeLiter,
    this.substanceName,
    this.dosage,
    this.notes,
    required this.executedAt,
  });

  factory FarmActivityModel.fromJson(Map<String, dynamic> json) {
    return FarmActivityModel(
      id: json['id'] ?? '',
      demplotId: json['demplotId'] ?? 0,
      cropCycleId: json['cropCycleId'],
      type: json['type'] ?? '',
      volumeLiter: json['volumeLiter'] != null ? (json['volumeLiter'] as num).toDouble() : null,
      substanceName: json['substanceName'],
      dosage: json['dosage'],
      notes: json['notes'],
      executedAt: json['executedAt'] != null ? DateTime.parse(json['executedAt']) : DateTime.now(),
    );
  }
}

class FarmActivitySummaryModel {
  final double totalWateringLiters7d;
  final double totalWateringLiters30d;
  final int fertilizationCount;
  final DateTime? lastFertilizationDate;
  final int sprayingCount;
  final DateTime? lastSprayingDate;

  FarmActivitySummaryModel({
    required this.totalWateringLiters7d,
    required this.totalWateringLiters30d,
    required this.fertilizationCount,
    this.lastFertilizationDate,
    required this.sprayingCount,
    this.lastSprayingDate,
  });

  factory FarmActivitySummaryModel.fromJson(Map<String, dynamic> json) {
    return FarmActivitySummaryModel(
      totalWateringLiters7d: (json['totalWateringLiters7d'] ?? 0).toDouble(),
      totalWateringLiters30d: (json['totalWateringLiters30d'] ?? 0).toDouble(),
      fertilizationCount: json['fertilizationCount'] ?? 0,
      lastFertilizationDate: json['lastFertilizationDate'] != null ? DateTime.parse(json['lastFertilizationDate']) : null,
      sprayingCount: json['sprayingCount'] ?? 0,
      lastSprayingDate: json['lastSprayingDate'] != null ? DateTime.parse(json['lastSprayingDate']) : null,
    );
  }
}

class DemplotAnalyticsModel {
  final int soilHealthScore;
  final String soilHealthStatus;
  final Map<String, dynamic> extremes;
  final Map<String, dynamic> npkTrends;
  final Map<String, dynamic> waterUsage;

  DemplotAnalyticsModel({
    required this.soilHealthScore,
    required this.soilHealthStatus,
    required this.extremes,
    required this.npkTrends,
    required this.waterUsage,
  });

  factory DemplotAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return DemplotAnalyticsModel(
      soilHealthScore: json['soilHealthScore'] ?? 0,
      soilHealthStatus: json['soilHealthStatus'] ?? 'Unknown',
      extremes: json['extremes'] ?? {},
      npkTrends: json['npkTrends'] ?? {},
      waterUsage: json['waterUsage'] ?? {},
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
