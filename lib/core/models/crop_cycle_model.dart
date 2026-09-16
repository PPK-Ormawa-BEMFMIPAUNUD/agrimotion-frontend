import 'package:intl/intl.dart';

class CropCycleModel {
  final String id;
  final int demplotId;
  final String commodityName;
  final DateTime plantingDate;
  final DateTime? targetHarvestDate;
  final DateTime? harvestDate;
  final double? yieldKg;
  final String? notes;
  final String status; // "ACTIVE" or "COMPLETED"
  
  // Analytics / Computed fields from backend
  final int hst;
  final String phase;
  final String? phaseDescription;
  final double? progressPercentage;
  final int? daysToHarvest;
  final int? durationDays;

  const CropCycleModel({
    required this.id,
    required this.demplotId,
    required this.commodityName,
    required this.plantingDate,
    this.targetHarvestDate,
    this.harvestDate,
    this.yieldKg,
    this.notes,
    required this.status,
    required this.hst,
    required this.phase,
    this.phaseDescription,
    this.progressPercentage,
    this.daysToHarvest,
    this.durationDays,
  });

  bool get isActive => status == 'ACTIVE';

  String get formattedPlantingDate {
    return DateFormat('dd MMM yyyy').format(plantingDate);
  }

  String get formattedTargetHarvestDate {
    if (targetHarvestDate == null) return '-';
    return DateFormat('dd MMM yyyy').format(targetHarvestDate!);
  }

  String get formattedHarvestDate {
    if (harvestDate == null) return '-';
    return DateFormat('dd MMM yyyy').format(harvestDate!);
  }

  factory CropCycleModel.fromJson(Map<String, dynamic> json) {
    return CropCycleModel(
      id: json['id'] ?? '',
      demplotId: json['demplotId'] ?? 0,
      commodityName: json['commodityName'] ?? '',
      plantingDate: DateTime.parse(json['plantingDate']).toLocal(),
      targetHarvestDate: json['targetHarvestDate'] != null
          ? DateTime.parse(json['targetHarvestDate']).toLocal()
          : null,
      harvestDate: json['harvestDate'] != null
          ? DateTime.parse(json['harvestDate']).toLocal()
          : null,
      yieldKg: json['yieldKg'] != null ? (json['yieldKg'] as num).toDouble() : null,
      notes: json['notes'],
      status: json['status'] ?? 'ACTIVE',
      hst: json['hst'] ?? 0,
      phase: json['phase'] ?? '',
      phaseDescription: json['phaseDescription'],
      progressPercentage: json['progressPercentage'] != null
          ? (json['progressPercentage'] as num).toDouble()
          : null,
      daysToHarvest: json['daysToHarvest'],
      durationDays: json['durationDays'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'demplotId': demplotId,
      'commodityName': commodityName,
      'plantingDate': plantingDate.toIso8601String(),
      'targetHarvestDate': targetHarvestDate?.toIso8601String(),
      'harvestDate': harvestDate?.toIso8601String(),
      'yieldKg': yieldKg,
      'notes': notes,
      'status': status,
      'hst': hst,
      'phase': phase,
      'phaseDescription': phaseDescription,
      'progressPercentage': progressPercentage,
      'daysToHarvest': daysToHarvest,
      'durationDays': durationDays,
    };
  }
}
