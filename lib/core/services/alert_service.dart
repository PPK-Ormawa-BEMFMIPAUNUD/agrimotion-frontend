import '../models/sensor_data.dart';
import '../models/alert_model.dart';
import 'sensor_service.dart';

class AlertService {
  final SensorService _sensorService;

  AlertService(this._sensorService);

  /// Mengambil data dari backend lalu mengevaluasinya
  Future<List<AlertModel>> fetchAndEvaluateAlerts() async {
    try {
      final List<SensorData> telemetryData =
          await _sensorService.fetchAllLatestTelemetry();
      return evaluateAlerts(telemetryData);
    } catch (e) {
      throw Exception('Gagal memuat data untuk dievaluasi: $e');
    }
  }

  /// Mengevaluasi data terhadap ambang batas (threshold)
  List<AlertModel> evaluateAlerts(List<SensorData> telemetryData) {
    final List<AlertModel> alerts = [];

    // Group telemetry berdasarkan node untuk hanya mengevaluasi data terbarunya
    final Map<String, SensorData> latestPerNode = {};
    for (var item in telemetryData) {
      final key = item.deviceCode ?? item.deviceId ?? 'unknown';
      if (!latestPerNode.containsKey(key)) {
        latestPerNode[key] = item;
      } else {
        if (item.timestamp.isAfter(latestPerNode[key]!.timestamp)) {
          latestPerNode[key] = item;
        }
      }
    }

    final now = DateTime.now();

    for (var entry in latestPerNode.entries) {
      final nodeStr = entry.key;
      final data = entry.value;

      // RULE 1: Node Offline (INFO)
      final diff = now.difference(data.timestamp);
      if (diff.inHours >= 1) {
        alerts.add(AlertModel(
          id: 'offline_${data.timestamp.millisecondsSinceEpoch}',
          deviceId: data.deviceId ?? data.deviceCode ?? 'unknown',
          type: 'Node Offline',
          message:
              'Node $nodeStr belum mengirim data selama lebih dari 1 jam. Terakhir aktif: ${data.timestamp.toLocal().toString().split('.')[0]}.',
          status: 'UNRESOLVED',
          createdAt: now,
        ));
      }

      // RULE 2: Moisture Rules
      final moisture = data.soilMoisture;
      if (moisture != null) {
        if (moisture < 25.0) {
          alerts.add(AlertModel(
            id: 'crit_moisture_${data.timestamp.millisecondsSinceEpoch}',
            deviceId: data.deviceId ?? data.deviceCode ?? 'unknown',
            type: 'Kelembaban Tanah Kritis',
            message:
                'Node $nodeStr mendeteksi kelembaban tanah sangat rendah ($moisture%). Segera aktifkan irigasi untuk mencegah kerusakan tanaman.',
            status: 'UNRESOLVED',
            createdAt: data.timestamp,
          ));
        } else if (moisture >= 25.0 && moisture <= 30.0) {
          alerts.add(AlertModel(
            id: 'warn_moisture_${data.timestamp.millisecondsSinceEpoch}',
            deviceId: data.deviceId ?? data.deviceCode ?? 'unknown',
            type: 'Kelembaban Tanah Berkurang',
            message:
                'Node $nodeStr melaporkan kelembaban tanah turun ke angka $moisture%.',
            status: 'UNRESOLVED',
            createdAt: data.timestamp,
          ));
        }
      }

      // RULE 3: Temperature Rules
      final temp = data.temperature;
      if (temp != null) {
        if (temp > 35.0) {
          alerts.add(AlertModel(
            id: 'crit_temp_${data.timestamp.millisecondsSinceEpoch}',
            deviceId: data.deviceId ?? data.deviceCode ?? 'unknown',
            type: 'Suhu Udara Ekstrem',
            message:
                'Node $nodeStr mendeteksi suhu mencapai $temp°C. Suhu ini dapat membahayakan daun. Segera periksa ventilasi.',
            status: 'UNRESOLVED',
            createdAt: data.timestamp,
          ));
        } else if (temp >= 32.0 && temp <= 35.0) {
          alerts.add(AlertModel(
            id: 'warn_temp_${data.timestamp.millisecondsSinceEpoch}',
            deviceId: data.deviceId ?? data.deviceCode ?? 'unknown',
            type: 'Peningkatan Suhu',
            message: 'Node $nodeStr melaporkan suhu meningkat ke $temp°C.',
            status: 'UNRESOLVED',
            createdAt: data.timestamp,
          ));
        }
      }
    }

    // Urutkan alert berdasarkan tingkat keparahan (Critical -> Warning -> Info) lalu berdasarkan waktu
    alerts.sort((a, b) {
      if (a.severity == AlertSeverity.critical &&
          b.severity != AlertSeverity.critical) {
        return -1;
      }
      if (b.severity == AlertSeverity.critical &&
          a.severity != AlertSeverity.critical) {
        return 1;
      }
      if (a.severity == AlertSeverity.warning &&
          b.severity == AlertSeverity.info) {
        return -1;
      }
      if (b.severity == AlertSeverity.warning &&
          a.severity == AlertSeverity.info) {
        return 1;
      }

      return b.timestamp.compareTo(a.timestamp); // Terbaru di atas
    });

    return alerts;
  }
}
