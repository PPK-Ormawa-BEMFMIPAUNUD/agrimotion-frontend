class EwsStatusModel {
  final int demplotId;
  final String commodity;
  final int hst;
  final int riskLevel;
  final String riskLabel;
  final double confidence;
  final String actionRecommendation;
  final bool pesticideAllowed;
  final String source;
  final Map<String, dynamic>? microclimateMetrics;

  const EwsStatusModel({
    required this.demplotId,
    required this.commodity,
    required this.hst,
    required this.riskLevel,
    required this.riskLabel,
    required this.confidence,
    required this.actionRecommendation,
    required this.pesticideAllowed,
    required this.source,
    this.microclimateMetrics,
  });

  bool get isSafe => riskLevel == 0;
  bool get isWarning => riskLevel == 1;
  bool get isDanger => riskLevel == 2;
  bool get isAiSource => source == 'ml_model';

  double? get temperature =>
      (microclimateMetrics?['temperature'] as num?)?.toDouble();
  double? get humidity =>
      (microclimateMetrics?['humidity'] as num?)?.toDouble();
  int? get consecutiveHoursIdeal =>
      (microclimateMetrics?['consecutiveHoursIdeal'] as num?)?.toInt();

  factory EwsStatusModel.fromJson(Map<String, dynamic> json) {
    // Handle NestJS TransformInterceptor wrapper (data inside 'data' key)
    final data = (json['data'] != null && json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    return EwsStatusModel(
      demplotId: (data['demplotId'] as num?)?.toInt() ?? 0,
      commodity: data['commodity'] as String? ?? 'Tidak Diketahui',
      hst: (data['hst'] as num?)?.toInt() ?? 1,
      riskLevel: (data['riskLevel'] as num?)?.toInt() ?? 0,
      riskLabel: data['riskLabel'] as String? ?? 'Aman',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 1.0,
      actionRecommendation: data['actionRecommendation'] as String? ??
          'Kondisi iklim aman dari potensi ledakan ulat.',
      pesticideAllowed: data['pesticideAllowed'] as bool? ?? true,
      source: data['source'] as String? ?? 'fallback',
      microclimateMetrics: data['microclimateMetrics'] as Map<String, dynamic>?,
    );
  }

  factory EwsStatusModel.fallback(int demplotId,
      {String? commodity, int? hst}) {
    // Basic offline calculation for Sawi if HST is provided
    bool isSawiHarvestLock = false;
    if (demplotId == 1 && hst != null && hst >= 35) {
      isSawiHarvestLock = true;
    }

    return EwsStatusModel(
      demplotId: demplotId,
      commodity: commodity ?? 'Tidak Diketahui',
      hst: hst ?? 1,
      riskLevel: 0,
      riskLabel: 'Aman',
      confidence: 1.0,
      actionRecommendation: isSawiHarvestLock
          ? 'Masa panen tiba. Penyemprotan pestisida kimia dilarang demi keamanan konsumsi.'
          : 'Sistem sedang offline. Rekomendasi didasarkan pada perhitungan keamanan standar.',
      pesticideAllowed: !isSawiHarvestLock,
      source: 'offline_fallback',
      microclimateMetrics: null,
    );
  }
}
