class DemplotReportData {
  final DemplotReportHeader header;
  final DemplotReportSummary summary;
  final List<DailyReportItem> dailyRecords;

  DemplotReportData({
    required this.header,
    required this.summary,
    required this.dailyRecords,
  });

  factory DemplotReportData.fromJson(Map<String, dynamic> json) {
    return DemplotReportData(
      header: DemplotReportHeader.fromJson(json['header']),
      summary: DemplotReportSummary.fromJson(json['summary']),
      dailyRecords: (json['dailyRecords'] as List)
          .map((item) => DailyReportItem.fromJson(item))
          .toList(),
    );
  }
}

class DemplotReportHeader {
  final int demplotId;
  final String demplotName;
  final String commodity;
  final String plantingDate;
  final int hst;
  final String phase;
  final String periodLabel;
  final String startDate;
  final String endDate;

  DemplotReportHeader({
    required this.demplotId,
    required this.demplotName,
    required this.commodity,
    required this.plantingDate,
    required this.hst,
    required this.phase,
    required this.periodLabel,
    required this.startDate,
    required this.endDate,
  });

  factory DemplotReportHeader.fromJson(Map<String, dynamic> json) {
    return DemplotReportHeader(
      demplotId: json['demplotId'],
      demplotName: json['demplotName'],
      commodity: json['commodity'],
      plantingDate: json['plantingDate'],
      hst: json['hst'],
      phase: json['phase'],
      periodLabel: json['periodLabel'],
      startDate: json['startDate'],
      endDate: json['endDate'],
    );
  }
}

class DemplotReportSummary {
  final double avgTemp;
  final double avgMoisture;
  final double avgHumidity;
  final double avgPh;
  final int soilHealthScore;
  final double totalWaterLiters;
  final int fertilizationCount;
  final int sprayingCount;

  DemplotReportSummary({
    required this.avgTemp,
    required this.avgMoisture,
    required this.avgHumidity,
    required this.avgPh,
    required this.soilHealthScore,
    required this.totalWaterLiters,
    required this.fertilizationCount,
    required this.sprayingCount,
  });

  factory DemplotReportSummary.fromJson(Map<String, dynamic> json) {
    return DemplotReportSummary(
      avgTemp: (json['avgTemp'] as num).toDouble(),
      avgMoisture: (json['avgMoisture'] as num).toDouble(),
      avgHumidity: (json['avgHumidity'] as num).toDouble(),
      avgPh: (json['avgPh'] as num).toDouble(),
      soilHealthScore: json['soilHealthScore'] ?? 0,
      totalWaterLiters: (json['totalWaterLiters'] as num).toDouble(),
      fertilizationCount: json['fertilizationCount'] ?? 0,
      sprayingCount: json['sprayingCount'] ?? 0,
    );
  }
}

class DailyReportItem {
  final String date;
  final String dayName;
  final double avgTemp;
  final double minTemp;
  final double maxTemp;
  final double avgMoisture;
  final double minMoisture;
  final double maxMoisture;
  final double avgHumidity;
  final double minHumidity;
  final double maxHumidity;
  final double avgPh;
  final double avgN;
  final double avgP;
  final double avgK;
  final List<String> activities;

  DailyReportItem({
    required this.date,
    required this.dayName,
    required this.avgTemp,
    required this.minTemp,
    required this.maxTemp,
    required this.avgMoisture,
    required this.minMoisture,
    required this.maxMoisture,
    required this.avgHumidity,
    required this.minHumidity,
    required this.maxHumidity,
    required this.avgPh,
    required this.avgN,
    required this.avgP,
    required this.avgK,
    required this.activities,
  });

  factory DailyReportItem.fromJson(Map<String, dynamic> json) {
    return DailyReportItem(
      date: json['date'],
      dayName: json['dayName'],
      avgTemp: (json['avgTemp'] as num).toDouble(),
      minTemp: (json['minTemp'] as num).toDouble(),
      maxTemp: (json['maxTemp'] as num).toDouble(),
      avgMoisture: (json['avgMoisture'] as num).toDouble(),
      minMoisture: (json['minMoisture'] as num).toDouble(),
      maxMoisture: (json['maxMoisture'] as num).toDouble(),
      avgHumidity: (json['avgHumidity'] as num).toDouble(),
      minHumidity: (json['minHumidity'] as num).toDouble(),
      maxHumidity: (json['maxHumidity'] as num).toDouble(),
      avgPh: (json['avgPh'] as num).toDouble(),
      avgN: (json['avgN'] as num).toDouble(),
      avgP: (json['avgP'] as num).toDouble(),
      avgK: (json['avgK'] as num).toDouble(),
      activities: List<String>.from(json['activities'] ?? []),
    );
  }
}
