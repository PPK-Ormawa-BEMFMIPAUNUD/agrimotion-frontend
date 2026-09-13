import '../models/sensor_data.dart';

enum ActuationType {
  fertilizer('Pupuk Cair', 'g', 'gram'),
  pesticide('Pestisida', 'mL', 'mL'),
  water('Air Bersih', 'L', 'Liter');

  final String label;
  final String shortUnit;
  final String fullUnit;
  const ActuationType(this.label, this.shortUnit, this.fullUnit);
}

class DssRecommendation {
  final double recommendedValue;
  final String reason;
  final String sensorSummary;

  const DssRecommendation({
    required this.recommendedValue,
    required this.reason,
    required this.sensorSummary,
  });
}

class EwsValidationResult {
  final bool isValid;
  final bool isWarning;
  final bool isCritical;
  final String? errorMessage;
  final String? riskDescription;

  const EwsValidationResult.valid()
      : isValid = true,
        isWarning = false,
        isCritical = false,
        errorMessage = null,
        riskDescription = null;

  const EwsValidationResult.warning(this.errorMessage, this.riskDescription)
      : isValid = true,
        isWarning = true,
        isCritical = false;

  const EwsValidationResult.error(this.errorMessage, this.riskDescription)
      : isValid = false,
        isWarning = false,
        isCritical = true;
}

class ActuationCalculator {
  ActuationCalculator._();

  // 1. Konstanta Debit Hardware
  static const double fertilizerFlowRate = 0.125; // gram/s
  static const double pesticideFlowRate = 0.042; // mL/s
  static const double waterFlowRate = 0.05; // L/s

  // 2. Kompensasi Pembilasan Pipa (Flushing Dead Volume)
  static double getFlushDelay(int demplotIndex) {
    switch (demplotIndex) {
      case 0:
        return 2.0; // Demplot 1 (Pacah)
      case 1:
        return 3.5; // Demplot 2 (Sayur)
      case 2:
        return 5.0; // Demplot 3 (Cabai)
      default:
        return 2.0;
    }
  }

  // 3. Fungsi Konversi Fisik ke Detik Pompa
  static int calculateDurationSeconds(
      int demplotIndex, ActuationType type, double value) {
    if (value <= 0) return 0;
    final flushDelay = getFlushDelay(demplotIndex);
    switch (type) {
      case ActuationType.fertilizer:
        return ((value / fertilizerFlowRate) + flushDelay).round();
      case ActuationType.pesticide:
        return ((value / pesticideFlowRate) + flushDelay).round();
      case ActuationType.water:
        return (value / waterFlowRate).round(); // no flush delay for water
    }
  }

  static String formatDuration(int totalSeconds) {
    if (totalSeconds < 60) return '$totalSeconds detik';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (seconds == 0) return '$minutes menit';
    return '$minutes menit $seconds detik';
  }

  // 4. Logika Rekomendasi DSS Berdasarkan Sensor
  static DssRecommendation getRecommendation(
      int demplotIndex, ActuationType type, SensorData? sensor) {
    // Baseline Defaults
    double baselineFertilizer;
    double baselinePesticide;
    double baselineWater;

    switch (demplotIndex) {
      case 0: // Pacah
        baselineFertilizer = 20.0;
        baselinePesticide = 0.0;
        baselineWater = 8.0;
        break;
      case 1: // Sayur
        baselineFertilizer = 35.0;
        baselinePesticide = 1.0;
        baselineWater = 10.0;
        break;
      case 2: // Cabai
      default:
        baselineFertilizer = 30.0;
        baselinePesticide = 1.5;
        baselineWater = 7.0;
        break;
    }

    final moisture = sensor?.soilMoisture;
    final temp = sensor?.temperature;
    final humidity = sensor?.humidity;
    final npkN = sensor?.npkN;
    final npkP = sensor?.npkP;
    final npkK = sensor?.npkK;

    String sensorSummary = 'N/A';
    if (sensor != null) {
      final mStr = moisture != null ? '${moisture.toStringAsFixed(1)}%' : '-';
      final tStr = temp != null ? '${temp.toStringAsFixed(1)}°C' : '-';
      final nStr = sensor.npkDisplay;
      sensorSummary = 'Air: $mStr | Suhu: $tStr | NPK: $nStr';
    }

    if (type == ActuationType.water) {
      if (moisture != null) {
        if (moisture > 80.0) {
          return DssRecommendation(
            recommendedValue: 0.0,
            reason: 'Tanah sudah sangat basah (Kelembapan > 80%). Penyiraman ditunda.',
            sensorSummary: sensorSummary,
          );
        } else if (moisture >= 65.0) {
          double rec = baselineWater * 0.6;
          return DssRecommendation(
            recommendedValue: double.parse(rec.toStringAsFixed(1)),
            reason: 'Kelembapan tanah cukup optimal. Penyiraman ringan disarankan.',
            sensorSummary: sensorSummary,
          );
        } else if (moisture < 40.0) {
          double rec = baselineWater * 1.25;
          return DssRecommendation(
            recommendedValue: double.parse(rec.toStringAsFixed(1)),
            reason: 'Kelembapan tanah rendah. Penambahan volume air disarankan.',
            sensorSummary: sensorSummary,
          );
        }
      }
      return DssRecommendation(
        recommendedValue: baselineWater,
        reason: 'Menggunakan dosis penyiraman standar.',
        sensorSummary: sensorSummary,
      );
    }

    if (type == ActuationType.fertilizer) {
      if (npkN != null || npkP != null || npkK != null) {
        final n = npkN ?? 50.0; // default normal if null
        final p = npkP ?? 50.0;
        final k = npkK ?? 50.0;

        if (n < 30 || p < 30 || k < 30) {
          double rec = (baselineFertilizer * 1.15).clamp(0.0, 60.0);
          return DssRecommendation(
            recommendedValue: double.parse(rec.toStringAsFixed(1)),
            reason: 'Kandungan hara NPK di bawah ambang ideal. Peningkatan nutrisi terkontrol disarankan.',
            sensorSummary: sensorSummary,
          );
        } else if (n > 120 && p > 120 && k > 120) {
          double rec = baselineFertilizer * 0.8;
          return DssRecommendation(
            recommendedValue: double.parse(rec.toStringAsFixed(1)),
            reason: 'Kandungan hara NPK masih melimpah di tanah. Dosis pemupukan minimal disarankan.',
            sensorSummary: sensorSummary,
          );
        }
      }
      return DssRecommendation(
        recommendedValue: baselineFertilizer,
        reason: 'Kondisi NPK tanah normal. Disarankan pemupukan berkala standar.',
        sensorSummary: sensorSummary,
      );
    }

    if (type == ActuationType.pesticide) {
      if (humidity != null && humidity > 80.0 && temp != null && temp > 28.0) {
        double rec = baselinePesticide == 0.0 ? 0.8 : baselinePesticide + 0.5;
        rec = rec.clamp(0.5, 3.0);
        return DssRecommendation(
          recommendedValue: double.parse(rec.toStringAsFixed(1)),
          reason: 'Kelembapan udara tinggi & suhu hangat memicu risiko jamur/OPT. Disarankan semprot proteksi.',
          sensorSummary: sensorSummary,
        );
      }
      return DssRecommendation(
        recommendedValue: baselinePesticide,
        reason: 'Kondisi mikroklimat stabil. Gunakan dosis proteksi preventif jadwal rutin.',
        sensorSummary: sensorSummary,
      );
    }

    return DssRecommendation(
      recommendedValue: 0.0,
      reason: '-',
      sensorSummary: sensorSummary,
    );
  }

  // 5. Guardrail Validasi Batas Aman (EWS)
  static EwsValidationResult validateActuation(
      ActuationType type, double value, SensorData? sensor) {
    if (type == ActuationType.fertilizer) {
      if (value < 5.0) {
        return const EwsValidationResult.error(
            'Dosis terlalu rendah (< 5.0 gram)',
            'Dosis di bawah ambang serapan tidak memberikan dampak nutrisi yang signifikan pada tanaman.');
      } else if (value > 60.0) {
        return const EwsValidationResult.error(
            'Bahaya Overdosis Nutrisi (> 60.0 gram)!',
            'Konsentrasi garam pupuk yang terlalu tinggi berisiko membakar akar (fertilizer burn), menyebabkan plasmolisis, dan merusak kesuburan media tanam.');
      }
    } else if (type == ActuationType.pesticide) {
      if (value == 0.0) {
        return const EwsValidationResult.error(
            'Volume tidak valid (0.0 mL)',
            'Dosis 0.0 mL tidak memerlukan aktuasi pompa. Masukkan minimal 0.5 mL jika ingin menyemprot.');
      } else if (value > 0.0 && value < 0.5) {
        return const EwsValidationResult.error(
            'Dosis di bawah batas efektif (< 0.5 mL)',
            'Kurang efektif untuk mengendalikan populasi organisme pengganggu tanaman (OPT).');
      } else if (value > 3.0) {
        return const EwsValidationResult.error(
            'Bahaya Fitotoksisitas (> 3.0 mL)!',
            'Paparan pestisida berlebih dapat menyebabkan daun hangus, klorosis, stres oksidatif, dan residu kimia tinggi.');
      }
    } else if (type == ActuationType.water) {
      if (sensor?.soilMoisture != null && sensor!.soilMoisture! > 80.0) {
        return EwsValidationResult.error(
            'Penyiraman Ditolak! Tanah Sangat Basah.',
            'Kelembapan tanah saat ini (${sensor.soilMoisture!.toStringAsFixed(1)}%) sudah melebihi 80% (jenuh air). Melanjutkan penyiraman akan memicu waterlogging, anoksia perakaran, dan pembusukan jamur patogen.');
      }
      if (value < 2.0) {
        return const EwsValidationResult.error(
            'Volume air terlalu sedikit (< 2.0 Liter)',
            'Tidak cukup untuk membasahi zona perakaran tanaman secara merata.');
      } else if (value > 25.0) {
        return const EwsValidationResult.error(
            'Bahaya Volume Berlebih (> 25.0 Liter)!',
            'Volume air melebihi kapasitas infiltrasi tanah berisiko menyebabkan erosi permukaan, pencucian hara pupuk (leaching), dan pembusukan akar.');
      }
    }

    return const EwsValidationResult.valid();
  }
}
