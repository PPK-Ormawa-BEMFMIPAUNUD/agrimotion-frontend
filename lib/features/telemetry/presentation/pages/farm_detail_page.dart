import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import 'package:agrimotion/core/theme/colors.dart';
import 'package:agrimotion/core/constants/app_constants.dart';
import 'package:agrimotion/core/constants/api_constants.dart';
import 'package:agrimotion/shared/widgets/status_badge.dart';
import 'package:agrimotion/features/auth/presentation/controllers/auth_controller.dart';
import 'package:agrimotion/core/services/cache_service.dart';

enum _ChartMetricType {
  npk('NPK Tren'),
  moistureTemp('Kelembaban & Suhu'),
  ph('pH Level');

  final String label;
  const _ChartMetricType(this.label);
}

class _DemplotMetadata {
  final int index;
  final String name;
  final String commodity;
  final String icon;
  final String nodeId;
  final String deviceId;
  final String location;
  final String area;
  final String plantAge;

  const _DemplotMetadata({
    required this.index,
    required this.name,
    required this.commodity,
    required this.icon,
    required this.nodeId,
    required this.deviceId,
    required this.location,
    required this.area,
    required this.plantAge,
  });
}

const List<_DemplotMetadata> _demplotsMetadata = [
  _DemplotMetadata(
    index: 0,
    name: 'Demplot 1',
    commodity: 'Bunga Pacah',
    icon: '🌸',
    nodeId: 'node-1a',
    deviceId: '10000000-0000-0000-0000-000000000001',
    location: 'Desa Nyanglan, Banjarangkan, Klungkung',
    area: '400 m²',
    plantAge: 'Tanaman Hias & Upakara',
  ),
  _DemplotMetadata(
    index: 1,
    name: 'Demplot 2',
    commodity: 'Sawi',
    icon: '🥬',
    nodeId: 'node-2a',
    deviceId: '20000000-0000-0000-0000-000000000001',
    location: 'Desa Nyanglan, Banjarangkan, Klungkung',
    area: '500 m²',
    plantAge: 'Sayuran Hijau Organik',
  ),
  _DemplotMetadata(
    index: 2,
    name: 'Demplot 3',
    commodity: 'Cabai',
    icon: '🌶️',
    nodeId: 'node-3a',
    deviceId: '30000000-0000-0000-0000-000000000001',
    location: 'Desa Nyanglan, Banjarangkan, Klungkung',
    area: '350 m²',
    plantAge: 'Hortikultura Unggulan',
  ),
];

class _TelemetryRecord {
  final DateTime timestamp;
  final String nodeId;
  final double moisture;
  final double ph;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double temperature;
  final double humidity;
  final SensorStatus status;

  const _TelemetryRecord({
    required this.timestamp,
    required this.nodeId,
    required this.moisture,
    required this.ph,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.temperature,
    required this.humidity,
    required this.status,
  });

  String get formattedDateTime {
    return DateFormat('dd MMM yyyy, HH:mm').format(timestamp);
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'nodeId': nodeId,
      'soilMoisture': moisture,
      'ph': ph,
      'nitrogen': nitrogen,
      'phosphorus': phosphorus,
      'potassium': potassium,
      'temperature': temperature,
      'humidity': humidity,
      'status': status.label,
    };
  }

  String toCsvRow() {
    return '"${DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp)}",'
        '"$nodeId",'
        '${moisture.toStringAsFixed(1)},'
        '${ph.toStringAsFixed(2)},'
        '${nitrogen.toStringAsFixed(0)},'
        '${phosphorus.toStringAsFixed(0)},'
        '${potassium.toStringAsFixed(0)},'
        '${temperature.toStringAsFixed(1)},'
        '${humidity.toStringAsFixed(1)},'
        '"${status.label}"';
  }
}

class _DailyAverage {
  final DateTime date;
  final double moisture;
  final double ph;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double temperature;
  final double humidity;
  final int totalTransmissions;
  final SensorStatus status;

  const _DailyAverage({
    required this.date,
    required this.moisture,
    required this.ph,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.temperature,
    required this.humidity,
    this.totalTransmissions = 1,
    required this.status,
  });

  String get formattedDate {
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'date': DateFormat('yyyy-MM-dd').format(date),
      'formattedDate': formattedDate,
      'soilMoisture': moisture,
      'ph': ph,
      'nitrogen': nitrogen,
      'phosphorus': phosphorus,
      'potassium': potassium,
      'temperature': temperature,
      'humidity': humidity,
      'totalTransmissions': totalTransmissions,
      'status': status.label,
    };
  }

  String toCsvRow(int no) {
    return '$no,'
        '"$formattedDate",'
        '${moisture.toStringAsFixed(1)},'
        '${ph.toStringAsFixed(2)},'
        '${nitrogen.toStringAsFixed(0)},'
        '${phosphorus.toStringAsFixed(0)},'
        '${potassium.toStringAsFixed(0)},'
        '${temperature.toStringAsFixed(1)},'
        '${humidity.toStringAsFixed(1)},'
        '$totalTransmissions,'
        '"${status.label}"';
  }
}

class _DemplotTelemetryData {
  final int index;
  final String name;
  final String commodity;
  final String icon;
  final String nodeId;
  final String location;
  final String area;
  final String plantAge;

  final double liveMoisture;
  final double livePh;
  final double liveNitrogen;
  final double livePhosphorus;
  final double livePotassium;
  final double liveTemperature;
  final double liveHumidity;
  final DateTime? lastUpdatedTimestamp;

  final List<_TelemetryRecord> tableRecords;
  final Map<TimeRange, List<_ChartPoint>> chartPoints24h;

  _DemplotTelemetryData({
    required this.index,
    required this.name,
    required this.commodity,
    required this.icon,
    required this.nodeId,
    required this.location,
    required this.area,
    required this.plantAge,
    required this.liveMoisture,
    required this.livePh,
    required this.liveNitrogen,
    required this.livePhosphorus,
    required this.livePotassium,
    required this.liveTemperature,
    required this.liveHumidity,
    this.lastUpdatedTimestamp,
    required this.tableRecords,
    required this.chartPoints24h,
  });

  SensorStatus get moistureStatus {
    if (liveMoisture < 25.0) return SensorStatus.danger;
    if (liveMoisture < 40.0 || liveMoisture > 75.0) return SensorStatus.warning;
    return SensorStatus.optimal;
  }

  SensorStatus get phStatus {
    if (livePh < 5.5 || livePh > 8.0) return SensorStatus.danger;
    if (livePh < 6.0 || livePh > 7.5) return SensorStatus.warning;
    return SensorStatus.optimal;
  }

  SensorStatus get nitrogenStatus {
    if (liveNitrogen < 15.0 || liveNitrogen > 45.0) return SensorStatus.danger;
    if (liveNitrogen < 20.0 || liveNitrogen > 40.0) return SensorStatus.warning;
    return SensorStatus.optimal;
  }

  SensorStatus get phosphorusStatus {
    if (livePhosphorus < 20.0 || livePhosphorus > 100.0) return SensorStatus.danger;
    if (livePhosphorus < 30.0 || livePhosphorus > 80.0) return SensorStatus.warning;
    return SensorStatus.optimal;
  }

  SensorStatus get potassiumStatus {
    if (livePotassium < 30.0 || livePotassium > 120.0) return SensorStatus.danger;
    if (livePotassium < 40.0 || livePotassium > 100.0) return SensorStatus.warning;
    return SensorStatus.optimal;
  }

  SensorStatus get temperatureStatus {
    if (liveTemperature > 35.0 || liveTemperature < 18.0) return SensorStatus.danger;
    if (liveTemperature > 32.0 || liveTemperature < 20.0) return SensorStatus.warning;
    return SensorStatus.optimal;
  }

  SensorStatus get humidityStatus {
    if (liveHumidity < 55.0 || liveHumidity > 85.0) return SensorStatus.danger;
    if (liveHumidity < 60.0 || liveHumidity > 80.0) return SensorStatus.warning;
    return SensorStatus.optimal;
  }
}

class _ChartPoint {
  final int index;
  final String label;
  final double moisture;
  final double ph;
  final double nitrogen;
  final double phosphorus;
  final double potassium;
  final double temperature;
  final double humidity;

  const _ChartPoint({
    required this.index,
    required this.label,
    required this.moisture,
    required this.ph,
    required this.nitrogen,
    required this.phosphorus,
    required this.potassium,
    required this.temperature,
    required this.humidity,
  });
}

class FarmDetailPage extends ConsumerStatefulWidget {
  const FarmDetailPage({super.key});

  @override
  ConsumerState<FarmDetailPage> createState() => _FarmDetailPageState();
}

class _FarmDetailPageState extends ConsumerState<FarmDetailPage> {
  int _selectedDemplotIndex = 0;
  _ChartMetricType _selectedChartType = _ChartMetricType.npk;
  TimeRange _selectedTimeRange = TimeRange.day24h;

  final TextEditingController _searchController = TextEditingController();
  SensorStatus? _selectedStatusFilter;
  int _currentPage = 1;
  static const int _pageSize = 10;

  DateTime? _lastTelemetryTimestamp;
  Map<String, _DailyAverage> _dailyAveragesMap = {};
  bool _isLoading = true;
  String? _errorMessage;
  _DemplotTelemetryData? _activeData;
  List<_TelemetryRecord> _allFetchedRecords = [];

  @override
  void initState() {
    super.initState();
    _fetchTelemetry(_selectedDemplotIndex);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  String _formatTimestamp(DateTime dt) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (_) {
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    }
  }

  SensorStatus _determineStatus(double m, double p, double t, double h) {
    if (m < 25.0 || p < 5.5 || p > 8.0 || t > 35.0) {
      return SensorStatus.danger;
    } else if (m < 40.0 || m > 75.0 || p < 6.0 || p > 7.5 || t > 32.0 || h < 60.0 || h > 80.0) {
      return SensorStatus.warning;
    }
    return SensorStatus.optimal;
  }

  _TelemetryRecord _parseRecord(Map<String, dynamic> e, String nodeId) {
    DateTime t = DateTime.now();
    if (e['timestamp'] != null) {
      t = DateTime.tryParse(e['timestamp'].toString())?.toLocal() ?? DateTime.now();
    } else if (e['createdAt'] != null) {
      t = DateTime.tryParse(e['createdAt'].toString())?.toLocal() ?? DateTime.now();
    } else if (e['created_at'] != null) {
      t = DateTime.tryParse(e['created_at'].toString())?.toLocal() ?? DateTime.now();
    }

    final m = _parseDouble(e['soilMoisture'] ?? e['soil_moisture']);
    final p = _parseDouble(e['ph'] ?? e['pH']);
    final n = _parseDouble(e['nitrogen'] ?? e['npk_n'] ?? e['npkN']);
    final phos = _parseDouble(e['phosphorus'] ?? e['npk_p'] ?? e['npkP']);
    final k = _parseDouble(e['potassium'] ?? e['npk_k'] ?? e['npkK']);
    final temp = _parseDouble(e['temperature']);
    final h = _parseDouble(e['humidity']);

    return _TelemetryRecord(
      timestamp: t,
      nodeId: nodeId,
      moisture: m,
      ph: p,
      nitrogen: n,
      phosphorus: phos,
      potassium: k,
      temperature: temp,
      humidity: h,
      status: _determineStatus(m, p, temp, h),
    );
  }

  _DailyAverage? _computeDailyAverage(DateTime date, List<dynamic> rawRecords) {
    if (rawRecords.isEmpty) return null;

    double totalMoisture = 0;
    double totalPh = 0;
    double totalN = 0;
    double totalP = 0;
    double totalK = 0;
    double totalTemp = 0;
    double totalHumidity = 0;
    int count = 0;

    for (final item in rawRecords) {
      if (item is Map<String, dynamic>) {
        totalMoisture += _parseDouble(item['soilMoisture'] ?? item['soil_moisture']);
        totalPh += _parseDouble(item['ph'] ?? item['pH']);
        totalN += _parseDouble(item['nitrogen'] ?? item['npk_n'] ?? item['npkN']);
        totalP += _parseDouble(item['phosphorus'] ?? item['npk_p'] ?? item['npkP']);
        totalK += _parseDouble(item['potassium'] ?? item['npk_k'] ?? item['npkK']);
        totalTemp += _parseDouble(item['temperature']);
        totalHumidity += _parseDouble(item['humidity']);
        count++;
      }
    }

    if (count == 0) return null;

    final avgMoisture = double.parse((totalMoisture / count).toStringAsFixed(1));
    final avgPh = double.parse((totalPh / count).toStringAsFixed(2));
    final avgN = double.parse((totalN / count).toStringAsFixed(1));
    final avgP = double.parse((totalP / count).toStringAsFixed(1));
    final avgK = double.parse((totalK / count).toStringAsFixed(1));
    final avgTemp = double.parse((totalTemp / count).toStringAsFixed(1));
    final avgHum = double.parse((totalHumidity / count).toStringAsFixed(1));

    return _DailyAverage(
      date: date,
      moisture: avgMoisture,
      ph: avgPh,
      nitrogen: avgN,
      phosphorus: avgP,
      potassium: avgK,
      temperature: avgTemp,
      humidity: avgHum,
      totalTransmissions: count,
      status: _determineStatus(avgMoisture, avgPh, avgTemp, avgHum),
    );
  }

  Future<void> _fetchTelemetry(int index) async {
    final meta = _demplotsMetadata[index];
    final deviceId = meta.deviceId;
    
    final cacheService = ref.read(cacheServiceProvider);
    final cacheKeyLatest = 'farm_latest_$deviceId';
    final cacheKeyHistory = 'farm_history_$deviceId';
    
    final cachedLatest = cacheService.getCacheData(cacheKeyLatest);
    final cachedHistory = cacheService.getCacheData(cacheKeyHistory);
    
    if (cachedLatest != null && cachedHistory != null) {
      if (mounted) {
        setState(() {
          _processTelemetryData(cachedLatest, cachedHistory, meta);
          _isLoading = false; // Only stop loading if we have cache
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }
    }
    
    final authState = ref.read(authProvider);
    final token = authState.session?.accessToken;
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    try {
      final latestUrl = Uri.parse('${ApiConstants.latestTelemetryEndpoint}?deviceId=$deviceId');
      final historyUrl = Uri.parse('${ApiConstants.telemetryHistoryEndpoint}?deviceId=$deviceId&limit=100&sort=desc');

      final responses = await Future.wait([
        http.get(latestUrl, headers: headers).timeout(ApiConstants.requestTimeout).catchError((_) => http.Response('{"data":[]}', 200)),
        http.get(historyUrl, headers: headers).timeout(ApiConstants.requestTimeout).catchError((_) => http.Response('{"data":[]}', 200)),
      ]);

      dynamic latestJson = {'data': []};
      dynamic historyJson = {'data': []};

      try {
        if (responses[0].statusCode == 200) {
          latestJson = jsonDecode(responses[0].body);
        }
      } catch (_) {}

      try {
        if (responses[1].statusCode == 200) {
          historyJson = jsonDecode(responses[1].body);
        }
      } catch (_) {}

      // Fallback: Check /api prefix if history is empty
      bool isHistoryEmpty = false;
      if (historyJson is Map && (historyJson['data'] as List?)?.isEmpty == true) isHistoryEmpty = true;
      if (historyJson is List && historyJson.isEmpty) isHistoryEmpty = true;

      if (isHistoryEmpty) {
        try {
          final fallbackHistoryUrl = Uri.parse('${ApiConstants.baseUrl}/api/telemetry/history?deviceId=$deviceId&limit=100&sort=desc');
          final fallbackRes = await http.get(fallbackHistoryUrl, headers: headers).timeout(ApiConstants.requestTimeout);
          if (fallbackRes.statusCode == 200) {
            historyJson = jsonDecode(fallbackRes.body);
          }
        } catch (_) {}
      }

      await cacheService.setCacheData(cacheKeyLatest, latestJson);
      await cacheService.setCacheData(cacheKeyHistory, historyJson);
      
      if (mounted) {
        setState(() {
          _processTelemetryData(latestJson, historyJson, meta);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // If we had cache, we keep the UI and don't show full screen error
          if (cachedLatest == null && cachedHistory == null) {
            _isLoading = false;
            _errorMessage = "Gagal mengambil data dari server. Periksa koneksi Anda.";
          }
        });
      }
    }
  }

  void _processTelemetryData(dynamic latestRaw, dynamic historyRaw, _DemplotMetadata meta) {
    List latestData = [];
    if (latestRaw is Map) {
      if (latestRaw['data'] is List) {
        latestData = latestRaw['data'] as List;
      } else if (latestRaw['data'] is Map) {
        latestData = [latestRaw['data']];
      }
    } else if (latestRaw is List) {
      latestData = latestRaw;
    }

    List historyData = [];
    if (historyRaw is Map) {
      if (historyRaw['data'] is List) {
        historyData = historyRaw['data'] as List;
      } else if (historyRaw['rows'] is List) {
        historyData = historyRaw['rows'] as List;
      }
    } else if (historyRaw is List) {
      historyData = historyRaw;
    }

    final List<_TelemetryRecord> records = historyData
        .whereType<Map<String, dynamic>>()
        .map((e) => _parseRecord(e, meta.nodeId))
        .toList();

    // Calculate daily averages from the loaded history records
    final Map<String, _DailyAverage> dailyMap = {};
    final Map<String, List<dynamic>> groupedByDate = {};
    for (final record in historyData) {
       if (record is Map && record['timestamp'] != null) {
          final dateStr = record['timestamp'].toString().substring(0, 10);
          groupedByDate.putIfAbsent(dateStr, () => []).add(record);
       }
    }

    groupedByDate.forEach((dateStr, list) {
       final dt = DateTime.tryParse(dateStr);
       if (dt != null) {
          final avg = _computeDailyAverage(dt, list);
          if (avg != null) {
             dailyMap[dateStr] = avg;
          }
       }
    });

    DateTime? latestTimestamp;
    if (latestData.isNotEmpty) {
      final first = latestData.first;
      if (first is Map && first['timestamp'] != null) {
        latestTimestamp = DateTime.tryParse(first['timestamp'].toString())?.toLocal();
      }
    } else if (records.isNotEmpty) {
      latestTimestamp = records.first.timestamp;
    }

    _DemplotTelemetryData data;
    if (latestData.isEmpty && historyData.isEmpty) {
      data = _DemplotTelemetryData(
        index: meta.index,
        name: meta.name,
        commodity: meta.commodity,
        icon: meta.icon,
        nodeId: meta.nodeId,
        location: meta.location,
        area: meta.area,
        plantAge: meta.plantAge,
        liveMoisture: 0,
        livePh: 0,
        liveNitrogen: 0,
        livePhosphorus: 0,
        livePotassium: 0,
        liveTemperature: 0,
        liveHumidity: 0,
        lastUpdatedTimestamp: null,
        tableRecords: [],
        chartPoints24h: {},
      );
    } else {
      final latest = latestData.isNotEmpty ? latestData.first : historyData.first;

      data = _DemplotTelemetryData(
        index: meta.index,
        name: meta.name,
        commodity: meta.commodity,
        icon: meta.icon,
        nodeId: meta.nodeId,
        location: meta.location,
        area: meta.area,
        plantAge: meta.plantAge,
        liveMoisture: _parseDouble(latest['soilMoisture'] ?? latest['soil_moisture']),
        livePh: _parseDouble(latest['ph'] ?? latest['pH']),
        liveNitrogen: _parseDouble(latest['nitrogen'] ?? latest['npk_n'] ?? latest['npkN']),
        livePhosphorus: _parseDouble(latest['phosphorus'] ?? latest['npk_p'] ?? latest['npkP']),
        livePotassium: _parseDouble(latest['potassium'] ?? latest['npk_k'] ?? latest['npkK']),
        liveTemperature: _parseDouble(latest['temperature']),
        liveHumidity: _parseDouble(latest['humidity']),
        lastUpdatedTimestamp: latestTimestamp,
        tableRecords: records,
        chartPoints24h: {},
      );
    }

    _activeData = data;
    _allFetchedRecords = records;
    _dailyAveragesMap = dailyMap;
    _lastTelemetryTimestamp = latestTimestamp;
    _updateChartPoints();
  }

  void _updateChartPoints() {
    if (_activeData == null) return;

    final Map<TimeRange, List<_ChartPoint>> map = {
      TimeRange.day24h: _buildChartPoints24h(_allFetchedRecords),
      TimeRange.week7d: _buildChartPointsAggregated(TimeRange.week7d),
      TimeRange.month30d: _buildChartPointsAggregated(TimeRange.month30d),
    };

    _activeData!.chartPoints24h.clear();
    _activeData!.chartPoints24h.addAll(map);
  }

    List<_ChartPoint> _buildChartPoints24h(List<_TelemetryRecord> records) {
    if (records.isEmpty) return [];
    
    // Strictly filter points from last 24 hours relative to current real time
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 24));
    
    final filtered = records.where((r) => r.timestamp.isAfter(cutoff)).toList();
    
    // Sort chronological ascending
    final chronological = filtered..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return chronological.asMap().entries.map((entry) {
      final i = entry.key;
      final r = entry.value;
      return _ChartPoint(
        index: i,
        label: DateFormat('HH:mm').format(r.timestamp),
        moisture: r.moisture,
        ph: r.ph,
        nitrogen: r.nitrogen,
        phosphorus: r.phosphorus,
        potassium: r.potassium,
        temperature: r.temperature,
        humidity: r.humidity,
      );
    }).toList();
  }

  List<_ChartPoint> _buildChartPointsAggregated(TimeRange range) {
    final int daysCount = range == TimeRange.week7d ? 7 : 30;
    final now = DateTime.now();

    // Strictly check each calendar day in the last 7 or 30 days from now
    final List<_DailyAverage> existingAverages = [];
    for (int i = daysCount - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      final avg = _dailyAveragesMap[dateStr];
      if (avg != null) {
        existingAverages.add(avg);
      }
    }

    if (existingAverages.isEmpty) return [];

    // Sort chronologically ascending
    existingAverages.sort((a, b) => a.date.compareTo(b.date));

    return existingAverages.asMap().entries.map((entry) {
      final i = entry.key;
      final avg = entry.value;
      String label;
      try {
        label = DateFormat('dd MMM', 'id_ID').format(avg.date);
      } catch (_) {
        label = DateFormat('dd MMM').format(avg.date);
      }

      return _ChartPoint(
        index: i,
        label: label,
        moisture: avg.moisture,
        ph: avg.ph,
        nitrogen: avg.nitrogen,
        phosphorus: avg.phosphorus,
        potassium: avg.potassium,
        temperature: avg.temperature,
        humidity: avg.humidity,
      );
    }).toList();
  }

  Future<void> _exportCsv() async {
    if (_activeData == null) return;
    final active = _activeData!;
    final records = _getFilteredDailyAverages();

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('"No","Tanggal","Rata-rata Kelembaban Tanah (%)","Rata-rata pH","Nitrogen (mg/kg)","Fosfor (mg/kg)","Kalium (mg/kg)","Suhu (°C)","Kelembaban Udara (%)","Total Transmisi","Status"');
    for (int i = 0; i < records.length; i++) {
      buffer.writeln(records[i].toCsvRow(i + 1));
    }

    final String csvContent = buffer.toString();
    final String fileName = 'agrimotion_riwayat_harian_${active.name.toLowerCase().replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

    try {
      final Uint8List bytes = Uint8List.fromList(utf8.encode(csvContent));
      final path = await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: 'csv',
        mimeType: MimeType.csv,
      );

      if (mounted) {
        _showExportSuccessDialog(
          title: 'Ekspor CSV Berhasil',
          fileName: '$fileName.csv',
          recordCount: records.length,
          savedPath: path,
          rawPreview: csvContent.split('\n').take(6).join('\n'),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor CSV: $e'),
            backgroundColor: AppColors.dangerRose,
          ),
        );
      }
    }
  }

  Future<void> _exportJson() async {
    if (_activeData == null) return;
    final active = _activeData!;
    final records = _getFilteredDailyAverages();

    final exportData = {
      'demplot': {
        'id': active.index + 1,
        'name': active.name,
        'commodity': active.commodity,
        'nodeId': active.nodeId,
        'location': active.location,
      },
      'exportedAt': DateTime.now().toIso8601String(),
      'totalDays': records.length,
      'dailyAverages': records.map((r) => r.toJson()).toList(),
    };

    final String jsonContent = const JsonEncoder.withIndent('  ').convert(exportData);
    final String fileName = 'agrimotion_riwayat_harian_${active.name.toLowerCase().replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';

    try {
      final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonContent));
      final path = await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: 'json',
        mimeType: MimeType.json,
      );

      if (mounted) {
        _showExportSuccessDialog(
          title: 'Ekspor JSON Berhasil',
          fileName: '$fileName.json',
          recordCount: records.length,
          savedPath: path,
          rawPreview: jsonContent.split('\n').take(12).join('\n'),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor JSON: $e'),
            backgroundColor: AppColors.dangerRose,
          ),
        );
      }
    }
  }

  void _showExportSuccessDialog({
    required String title,
    required String fileName,
    required int recordCount,
    required String savedPath,
    required String rawPreview,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.file_download_done_rounded, color: AppColors.primaryEmerald, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File "$fileName" ($recordCount baris data) siap digunakan.',
                style: TextStyle(fontSize: 13, color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary),
              ),
              if (savedPath.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.elevatedDark : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Lokasi: $savedPath',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'Pratinjau Data:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Text(
                  rawPreview,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: rawPreview));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Teks disalin ke papan klip!'), duration: Duration(seconds: 2)),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Salin Pratinjau'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryEmerald,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(context, isDark),
            const SizedBox(height: 20),
            _buildDemplotSelector(context, isDark),
            const SizedBox(height: 24),
            
            if (_isLoading)
              _buildShimmerSection(isDark)
            else if (_errorMessage != null)
              _buildErrorSection(isDark)
            else if (_activeData != null && _activeData!.tableRecords.isEmpty)
              _buildEmptyState(isDark)
            else if (_activeData != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLiveMetricsSection(context, isDark, _activeData!),
                  const SizedBox(height: 28),
                  _buildChartSection(context, isDark, _activeData!),
                  const SizedBox(height: 28),
                  _buildDataTableSection(context, isDark, _activeData!),
                ],
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _ShimmerPlaceholder(width: 250, height: 20),
            const Spacer(),
            _ShimmerPlaceholder(width: 120, height: 16),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: List.generate(4, (i) => _ShimmerPlaceholder(width: 280, height: 120, borderRadius: BorderRadius.circular(14))),
        ),
        const SizedBox(height: 28),
        _ShimmerPlaceholder(width: double.infinity, height: 350, borderRadius: BorderRadius.circular(16)),
        const SizedBox(height: 28),
        _ShimmerPlaceholder(width: double.infinity, height: 400, borderRadius: BorderRadius.circular(16)),
      ],
    );
  }

  Widget _buildErrorSection(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.dangerRose),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Terjadi kesalahan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _fetchTelemetry(_selectedDemplotIndex),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Coba Lagi'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryEmerald),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_rounded,
            size: 64,
            color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada data telemetri untuk node ini',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader(BuildContext context, bool isDark) {
    final String lastUpdatedStr = _lastTelemetryTimestamp != null
        ? _formatTimestamp(_lastTelemetryTimestamp!)
        : 'Belum ada data';
        
    final bool isOffline = _lastTelemetryTimestamp != null &&
        DateTime.now().difference(_lastTelemetryTimestamp!) > const Duration(minutes: 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primaryEmerald.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.sensors_rounded, size: 14, color: AppColors.primaryEmerald),
                  SizedBox(width: 6),
                  Text(
                    'TELEMETRI & IOT DEMPLOT REAL-TIME',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryEmerald,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (isOffline)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.dangerRose.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.dangerRose.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.wifi_off_rounded, size: 12, color: AppColors.dangerRose),
                    SizedBox(width: 6),
                    Text(
                      'OFFLINE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dangerRose,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _lastTelemetryTimestamp != null
                          ? (isOffline ? AppColors.warningAmber : AppColors.optimalGreen)
                          : AppColors.textTertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Data Terakhir: $lastUpdatedStr',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              onPressed: _isLoading ? null : () => _fetchTelemetry(_selectedDemplotIndex),
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? AppColors.elevatedDark : AppColors.primaryEmerald.withValues(alpha: 0.1),
                foregroundColor: AppColors.primaryEmerald,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: _isLoading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryEmerald))
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                _isLoading ? 'Memperbarui...' : 'Segarkan',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monitoring Telemetri Demplot',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pemantauan status tanah, unsur hara NPK, dan iklim mikro pertanian secara presisi',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDemplotSelector(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
              ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;
          if (isNarrow) {
            return Column(
              children: List.generate(_demplotsMetadata.length, (idx) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: _buildDemplotTabItem(
                    meta: _demplotsMetadata[idx],
                    isSelected: _selectedDemplotIndex == idx,
                    isDark: isDark,
                    onTap: () {
                      if (_selectedDemplotIndex != idx) {
                        setState(() => _selectedDemplotIndex = idx);
                        _fetchTelemetry(idx);
                      }
                    },
                  ),
                );
              }),
            );
          }
          return Row(
            children: List.generate(_demplotsMetadata.length, (idx) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildDemplotTabItem(
                    meta: _demplotsMetadata[idx],
                    isSelected: _selectedDemplotIndex == idx,
                    isDark: isDark,
                    onTap: () {
                      if (_selectedDemplotIndex != idx) {
                        setState(() => _selectedDemplotIndex = idx);
                        _fetchTelemetry(idx);
                      }
                    },
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildDemplotTabItem({
    required _DemplotMetadata meta,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final primaryColor = AppColors.primaryEmerald;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? primaryColor.withValues(alpha: 0.22) : primaryColor.withValues(alpha: 0.1)) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? primaryColor : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? primaryColor.withValues(alpha: 0.15) : (isDark ? AppColors.elevatedDark : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(meta.icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        meta.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? (isDark ? Colors.white : primaryColor) : (isDark ? AppColors.textDarkPrimary : AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor.withValues(alpha: 0.2) : (isDark ? AppColors.elevatedDark : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          meta.nodeId,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: isSelected ? primaryColor : (isDark ? AppColors.textDarkSecondary : AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${meta.commodity} • ${meta.plantAge}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMetricsSection(BuildContext context, bool isDark, _DemplotTelemetryData activeDemplot) {
    final String lastUpdatedText = _lastTelemetryTimestamp != null
        ? 'Update: ${_formatTimestamp(_lastTelemetryTimestamp!)}'
        : 'Update: Belum ada data';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.dashboard_customize_outlined, size: 18, color: AppColors.primaryEmerald),
            const SizedBox(width: 8),
            Text(
              'Metrik Sensor Terkini (${activeDemplot.name} - ${activeDemplot.commodity})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${activeDemplot.location} (${activeDemplot.area})',
              style: TextStyle(fontSize: 12, color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth;
            int crossAxisCount = width < 640 ? 1 : width < 960 ? 2 : 3;

            final List<_SensorCardData> cards = [
              _SensorCardData(
                title: 'Kelembaban Tanah',
                value: '${activeDemplot.liveMoisture.toStringAsFixed(1)} %',
                unit: '%',
                status: activeDemplot.moistureStatus,
                icon: Icons.water_drop_rounded,
                iconColor: const Color(0xFF0284C7),
                optimalRange: 'Optimal: 40 - 70 %',
                updateTime: lastUpdatedText,
                trendText: '',
                isPositive: activeDemplot.moistureStatus == SensorStatus.optimal,
              ),
              _SensorCardData(
                title: 'pH Tanah',
                value: activeDemplot.livePh.toStringAsFixed(2),
                unit: 'pH',
                status: activeDemplot.phStatus,
                icon: Icons.science_rounded,
                iconColor: const Color(0xFF8B5CF6),
                optimalRange: 'Optimal: 6.0 - 7.5',
                updateTime: lastUpdatedText,
                trendText: '',
                isPositive: activeDemplot.phStatus == SensorStatus.optimal,
              ),
              _SensorCardData(
                title: 'Nitrogen (N)',
                value: '${activeDemplot.liveNitrogen.toStringAsFixed(0)} mg/kg',
                unit: 'mg/kg',
                status: activeDemplot.nitrogenStatus,
                icon: Icons.eco_rounded,
                iconColor: AppColors.leafGreen,
                optimalRange: 'Target: 20 - 40 mg/kg',
                updateTime: lastUpdatedText,
                trendText: '',
                isPositive: activeDemplot.nitrogenStatus == SensorStatus.optimal,
              ),
              _SensorCardData(
                title: 'Fosfor (P)',
                value: '${activeDemplot.livePhosphorus.toStringAsFixed(0)} mg/kg',
                unit: 'mg/kg',
                status: activeDemplot.phosphorusStatus,
                icon: Icons.grain_rounded,
                iconColor: const Color(0xFF3B82F6),
                optimalRange: 'Target: 30 - 80 mg/kg',
                updateTime: lastUpdatedText,
                trendText: '',
                isPositive: activeDemplot.phosphorusStatus == SensorStatus.optimal,
              ),
              _SensorCardData(
                title: 'Kalium (K)',
                value: '${activeDemplot.livePotassium.toStringAsFixed(0)} mg/kg',
                unit: 'mg/kg',
                status: activeDemplot.potassiumStatus,
                icon: Icons.local_florist_rounded,
                iconColor: const Color(0xFFF59E0B),
                optimalRange: 'Target: 40 - 100 mg/kg',
                updateTime: lastUpdatedText,
                trendText: '',
                isPositive: activeDemplot.potassiumStatus == SensorStatus.optimal,
              ),
              _SensorCardData(
                title: 'Suhu Lingkungan',
                value: '${activeDemplot.liveTemperature.toStringAsFixed(1)} °C',
                unit: '°C',
                status: activeDemplot.temperatureStatus,
                icon: Icons.thermostat_rounded,
                iconColor: const Color(0xFFF97316),
                optimalRange: 'Optimal: 20 - 32 °C',
                updateTime: lastUpdatedText,
                trendText: '',
                isPositive: activeDemplot.temperatureStatus == SensorStatus.optimal,
              ),
              _SensorCardData(
                title: 'Kelembaban Udara',
                value: '${activeDemplot.liveHumidity.toStringAsFixed(1)} %',
                unit: '%',
                status: activeDemplot.humidityStatus,
                icon: Icons.cloud_queue_rounded,
                iconColor: const Color(0xFF06B6D4),
                optimalRange: 'Optimal: 60 - 80 %',
                updateTime: lastUpdatedText,
                trendText: '',
                isPositive: activeDemplot.humidityStatus == SensorStatus.optimal,
              ),
            ];

            final double cardSpacing = 14;
            final double cardWidth = (width - ((crossAxisCount - 1) * cardSpacing)) / crossAxisCount;

            return Wrap(
              spacing: cardSpacing,
              runSpacing: cardSpacing,
              children: cards.map((card) {
                return SizedBox(
                  width: cardWidth,
                  child: _buildSensorMetricCardWidget(card: card, isDark: isDark),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSensorMetricCardWidget({required _SensorCardData card, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  card.title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: card.iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(card.icon, size: 16, color: card.iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    card.value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: card.status, fontSize: 10),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.borderLight),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  card.optimalRange,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                card.updateTime,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? AppColors.textDarkSecondary.withValues(alpha: 0.7) : AppColors.textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(BuildContext context, bool isDark, _DemplotTelemetryData activeDemplot) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 720;
              final metricTabs = SegmentedButton<_ChartMetricType>(
                segments: _ChartMetricType.values.map((type) => ButtonSegment(value: type, label: Text(type.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))).toList(),
                selected: {_selectedChartType},
                onSelectionChanged: (newSel) => setState(() => _selectedChartType = newSel.first),
                style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              );

              final timeRangeTabs = SegmentedButton<TimeRange>(
                segments: TimeRange.values.map((range) => ButtonSegment(value: range, label: Text(range.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))).toList(),
                selected: {_selectedTimeRange},
                onSelectionChanged: (newSel) {
                  setState(() {
                    _selectedTimeRange = newSel.first;
                    _updateChartPoints();
                  });
                },
                style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Analisis Tren Sensor Telemetri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(scrollDirection: Axis.horizontal, child: metricTabs),
                    const SizedBox(height: 8),
                    SingleChildScrollView(scrollDirection: Axis.horizontal, child: timeRangeTabs),
                  ],
                );
              }

              return Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Analisis Tren Sensor Telemetri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Grafik interaktif observasi berkala', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary)),
                    ],
                  ),
                  const Spacer(),
                  metricTabs,
                  const SizedBox(width: 12),
                  timeRangeTabs,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _buildChartLegend(isDark),
          const SizedBox(height: 16),
          SizedBox(height: 320, child: _buildLineChartWidget(context, isDark, activeDemplot)),
        ],
      ),
    );
  }

  Widget _buildChartLegend(bool isDark) {
    switch (_selectedChartType) {
      case _ChartMetricType.npk:
        return Wrap(spacing: 16, runSpacing: 8, children: const [
          _LegendPill(label: 'Nitrogen (N)', unit: 'mg/kg', color: AppColors.leafGreen),
          _LegendPill(label: 'Fosfor (P)', unit: 'mg/kg', color: Color(0xFF3B82F6)),
          _LegendPill(label: 'Kalium (K)', unit: 'mg/kg', color: Color(0xFFF59E0B)),
        ]);
      case _ChartMetricType.moistureTemp:
        return Wrap(spacing: 16, runSpacing: 8, children: const [
          _LegendPill(label: 'Kelembaban Tanah (0-100%)', unit: '%', color: Color(0xFF0284C7)),
          _LegendPill(label: 'Suhu Lingkungan (15-45°C)', unit: '°C', color: Color(0xFFF97316)),
        ]);
      case _ChartMetricType.ph:
        return Wrap(spacing: 16, runSpacing: 8, children: const [
          _LegendPill(label: 'Kadar pH Tanah', unit: 'pH', color: Color(0xFF8B5CF6)),
          _LegendPill(label: 'Zona Optimal (6.0 - 7.5)', unit: 'Acuan', color: AppColors.optimalGreen, isDashed: true),
        ]);
    }
  }

  Widget _buildLineChartWidget(BuildContext context, bool isDark, _DemplotTelemetryData activeDemplot) {
    final points = activeDemplot.chartPoints24h[_selectedTimeRange] ?? [];
    if (points.isEmpty) {
      return const Center(child: Text('Tidak ada data grafik dalam rentang waktu ini'));
    }

    double minY = 0;
    double maxY = 100;
    double yInterval = 20;
    List<LineChartBarData> lineBars = [];

    switch (_selectedChartType) {
      case _ChartMetricType.npk:
        maxY = 140;
        lineBars = [
          _createLineBarData(spots: points.map((p) => FlSpot(p.index.toDouble(), p.nitrogen)).toList(), color: AppColors.leafGreen),
          _createLineBarData(spots: points.map((p) => FlSpot(p.index.toDouble(), p.phosphorus)).toList(), color: const Color(0xFF3B82F6)),
          _createLineBarData(spots: points.map((p) => FlSpot(p.index.toDouble(), p.potassium)).toList(), color: const Color(0xFFF59E0B)),
        ];
        break;
      case _ChartMetricType.moistureTemp:
        lineBars = [
          _createLineBarData(spots: points.map((p) => FlSpot(p.index.toDouble(), p.moisture)).toList(), color: const Color(0xFF0284C7)),
          _createLineBarData(spots: points.map((p) => FlSpot(p.index.toDouble(), p.temperature)).toList(), color: const Color(0xFFF97316)),
        ];
        break;
      case _ChartMetricType.ph:
        minY = 0.0;
        maxY = 14.0;
        yInterval = 2.0;
        lineBars = [
          _createLineBarData(spots: points.map((p) => FlSpot(p.index.toDouble(), p.ph)).toList(), color: const Color(0xFF8B5CF6)),
        ];
        break;
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final int idx = spot.x.toInt().clamp(0, points.length - 1);
                final pt = points[idx];
                String text = '';
                if (_selectedChartType == _ChartMetricType.npk) {
                  if (spot.barIndex == 0) {
                    text = 'N: ${pt.nitrogen} mg/kg';
                  } else if (spot.barIndex == 1) {
                    text = 'P: ${pt.phosphorus} mg/kg';
                  } else {
                    text = 'K: ${pt.potassium} mg/kg';
                  }
                } else if (_selectedChartType == _ChartMetricType.moistureTemp) {
                  if (spot.barIndex == 0) {
                    text = 'Kelembaban: ${pt.moisture}%';
                  } else {
                    text = 'Suhu: ${pt.temperature}°C';
                  }
                } else {
                  text = 'pH: ${pt.ph}';
                }
                return LineTooltipItem('${pt.label}\n$text', const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600, height: 1.3));
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: isDark ? AppColors.borderDark.withValues(alpha: 0.4) : AppColors.borderLight.withValues(alpha: 0.8),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    _selectedChartType == _ChartMetricType.ph ? value.toStringAsFixed(1) : value.toInt().toString(),
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: (points.length / 6).ceil().toDouble().clamp(1, double.infinity),
              getTitlesWidget: (value, meta) {
                final int idx = value.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(points[idx].label, style: TextStyle(fontSize: 10.5, color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            left: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            top: BorderSide.none,
            right: BorderSide.none,
          ),
        ),
        extraLinesData: _selectedChartType == _ChartMetricType.ph
            ? ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(y: 6.0, color: AppColors.optimalGreen.withValues(alpha: 0.8), strokeWidth: 1.5, dashArray: [6, 4]),
                  HorizontalLine(y: 7.5, color: AppColors.optimalGreen.withValues(alpha: 0.8), strokeWidth: 1.5, dashArray: [6, 4]),
                ],
              )
            : null,
        rangeAnnotations: _selectedChartType == _ChartMetricType.ph
            ? RangeAnnotations(horizontalRangeAnnotations: [HorizontalRangeAnnotation(y1: 6.0, y2: 7.5, color: AppColors.optimalGreen.withValues(alpha: 0.08))])
            : null,
        lineBarsData: lineBars,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  LineChartBarData _createLineBarData({required List<FlSpot> spots, required Color color}) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }

    List<_DailyAverage> _getFilteredDailyAverages() {
    final search = _searchController.text.trim().toLowerCase();
    final list = _dailyAveragesMap.values.toList()..sort((a, b) => b.date.compareTo(a.date));

    return list.where((avg) {
      if (_selectedStatusFilter != null && avg.status != _selectedStatusFilter) {
        return false;
      }
      if (search.isNotEmpty) {
        final dateFormatted = avg.formattedDate.toLowerCase();
        final rawDate = DateFormat('yyyy-MM-dd').format(avg.date).toLowerCase();
        if (!dateFormatted.contains(search) && !rawDate.contains(search)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Widget _buildDataTableSection(BuildContext context, bool isDark, _DemplotTelemetryData activeDemplot) {
    final filtered = _getFilteredDailyAverages();
    final int totalRecords = filtered.length;
    final int totalPages = (totalRecords / _pageSize).ceil().clamp(1, 999);
    if (_currentPage > totalPages) _currentPage = totalPages;
    final int startIndex = ((_currentPage - 1) * _pageSize).clamp(0, totalRecords);
    final int endIndex = (startIndex + _pageSize).clamp(0, totalRecords);
    final List<_DailyAverage> pageRecords = totalRecords > 0 ? filtered.sublist(startIndex, endIndex) : [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4)),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final searchField = SizedBox(
                width: isNarrow ? double.infinity : 240,
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() => _currentPage = 1),
                  decoration: InputDecoration(
                    hintText: 'Cari tanggal (cth: 24 Agu)...',
                    hintStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { _searchController.clear(); setState(() => _currentPage = 1); })
                        : null,
                    filled: true,
                    fillColor: isDark ? AppColors.elevatedDark : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight)),
                  ),
                  style: const TextStyle(fontSize: 12.5),
                ),
              );

              final statusDropdown = Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.elevatedDark : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SensorStatus?>(
                    value: _selectedStatusFilter,
                    hint: const Text('Semua Status', style: TextStyle(fontSize: 12)),
                    isDense: true,
                    dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary),
                    items: [
                      const DropdownMenuItem<SensorStatus?>(value: null, child: Text('Semua Status')),
                      ...[SensorStatus.optimal, SensorStatus.warning, SensorStatus.danger].map((status) => DropdownMenuItem<SensorStatus?>(value: status, child: Text(status.label))),
                    ],
                    onChanged: (val) { setState(() { _selectedStatusFilter = val; _currentPage = 1; }); },
                  ),
                ),
              );

              final exportButtons = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: _exportCsv,
                    icon: const Icon(Icons.table_chart_outlined, size: 16),
                    label: const Text('Ekspor CSV', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
                      side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _exportJson,
                    icon: const Icon(Icons.code_rounded, size: 16),
                    label: const Text('Ekspor JSON', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryEmerald,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Riwayat Data Telemetri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text('Rekapitulasi rata-rata parameter sensor per hari', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    searchField,
                    const SizedBox(height: 8),
                    Row(children: [statusDropdown, const Spacer(), exportButtons]),
                  ],
                );
              }

              return Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Riwayat Data Telemetri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Rekapitulasi rata-rata parameter sensor per hari', style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary)),
                    ],
                  ),
                  const Spacer(),
                  searchField,
                  const SizedBox(width: 8),
                  statusDropdown,
                  const SizedBox(width: 8),
                  exportButtons,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 860),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(isDark ? AppColors.elevatedDark : const Color(0xFFF8FAFC)),
                    dataRowColor: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.hovered)) return isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF1F5F9);
                      return null;
                    }),
                    columnSpacing: 18,
                    horizontalMargin: 16,
                    headingTextStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary, letterSpacing: 0.3),
                    dataTextStyle: TextStyle(fontSize: 12, color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary),
                    columns: const [
                      DataColumn(label: Text('NO')),
                      DataColumn(label: Text('TANGGAL')),
                      DataColumn(label: Text('RATA2 KELEMBABAN'), numeric: true),
                      DataColumn(label: Text('RATA2 pH'), numeric: true),
                      DataColumn(label: Text('N-P-K (mg/kg)'), numeric: true),
                      DataColumn(label: Text('RATA2 SUHU'), numeric: true),
                      DataColumn(label: Text('RATA2 HUMIDITY'), numeric: true),
                      DataColumn(label: Text('TRANSMISI'), numeric: true),
                      DataColumn(label: Text('STATUS')),
                    ],
                    rows: pageRecords.isEmpty
                        ? [
                            DataRow(cells: [
                              DataCell(Text('Tidak ada data', style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary, fontStyle: FontStyle.italic))),
                              const DataCell(Text('-')), const DataCell(Text('-')), const DataCell(Text('-')), const DataCell(Text('-')), const DataCell(Text('-')), const DataCell(Text('-')), const DataCell(Text('-')), const DataCell(Text('-')),
                            ])
                          ]
                        : pageRecords.asMap().entries.map((entry) {
                            final idx = startIndex + entry.key + 1;
                            final record = entry.value;
                            return DataRow(
                              cells: [
                                DataCell(Text('$idx', style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.primaryEmerald),
                                      const SizedBox(width: 6),
                                      Text(record.formattedDate, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                DataCell(Text('${record.moisture.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.w600, color: record.moisture < 40.0 ? AppColors.warningAmber : null))),
                                DataCell(Text(record.ph.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w600))),
                                DataCell(Text('${record.nitrogen.toStringAsFixed(0)} / ${record.phosphorus.toStringAsFixed(0)} / ${record.potassium.toStringAsFixed(0)}')),
                                DataCell(Text('${record.temperature.toStringAsFixed(1)}°C', style: TextStyle(color: record.temperature > 32.0 ? AppColors.warningAmber : null))),
                                DataCell(Text('${record.humidity.toStringAsFixed(1)}%')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: isDark ? AppColors.elevatedDark : const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                                    child: Text('${record.totalTransmissions} data', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                                DataCell(StatusBadge(status: record.status, fontSize: 10)),
                              ],
                            );
                          }).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Menampilkan $startIndex-$endIndex dari $totalRecords hari', style: TextStyle(fontSize: 12, color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left, size: 20), onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null),
                  ...List.generate(totalPages, (i) {
                    final pageNum = i + 1;
                    final isCurrent = pageNum == _currentPage;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: TextButton(
                          onPressed: () => setState(() => _currentPage = pageNum),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: isCurrent ? AppColors.primaryEmerald : Colors.transparent,
                            foregroundColor: isCurrent ? Colors.white : (isDark ? AppColors.textDarkPrimary : AppColors.textPrimary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text('$pageNum', style: TextStyle(fontSize: 12, fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500)),
                        ),
                      ),
                    );
                  }),
                  IconButton(icon: const Icon(Icons.chevron_right, size: 20), onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SensorCardData {
  final String title;
  final String value;
  final String unit;
  final SensorStatus status;
  final IconData icon;
  final Color iconColor;
  final String optimalRange;
  final String updateTime;
  final String trendText;
  final bool isPositive;

  const _SensorCardData({
    required this.title,
    required this.value,
    required this.unit,
    required this.status,
    required this.icon,
    required this.iconColor,
    required this.optimalRange,
    required this.updateTime,
    required this.trendText,
    required this.isPositive,
  });
}

class _LegendPill extends StatelessWidget {
  final String label;
  final String unit;
  final Color color;
  final bool isDashed;

  const _LegendPill({
    required this.label,
    required this.unit,
    required this.color,
    this.isDashed = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDashed ? 0.3 : 1.0),
            borderRadius: BorderRadius.circular(3),
            border: isDashed ? Border.all(color: color, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ShimmerPlaceholder extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  const _ShimmerPlaceholder({this.width, this.height, this.borderRadius});
  @override
  State<_ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<_ShimmerPlaceholder> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 0.8).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[300],
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}
