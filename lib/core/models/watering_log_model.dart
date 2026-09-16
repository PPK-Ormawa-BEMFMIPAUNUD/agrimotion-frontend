import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:agrimotion/core/config/demplot_config.dart';
import 'package:agrimotion/core/theme/app_theme.dart';

class WateringLogModel {
  final String id;
  final String deviceId;
  final String? userId;
  final String type;
  final int duration;
  final DateTime createdAt;

  const WateringLogModel({
    required this.id,
    required this.deviceId,
    this.userId,
    required this.type,
    required this.duration,
    required this.createdAt,
  });

  factory WateringLogModel.fromJson(Map<String, dynamic> json) {
    return WateringLogModel(
      id: json['id']?.toString() ?? '',
      deviceId: json['deviceId']?.toString() ?? json['device_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString(),
      type: json['type']?.toString().toUpperCase() ?? 'WATER',
      duration: json['duration'] != null ? (int.tryParse(json['duration'].toString()) ?? 0) : 0,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now())
          : (DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      if (userId != null) 'userId': userId,
      'type': type,
      'duration': duration,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // --- UI Helper Getters ---

  /// Label tipe penyemprotan
  String get typeLabel {
    final t = type.toLowerCase();
    if (t.contains('fertilizer') || t.contains('pupuk')) {
      return 'Pupuk Cair';
    } else if (t.contains('pesticide') || t.contains('pesti')) {
      return 'Pestisida';
    } else {
      return 'Siram Air';
    }
  }

  /// Nama demplot yang di-resolve dari deviceId
  String get demplotName {
    for (final demplot in DemplotConfig.demplots) {
      for (final device in demplot.devices) {
        if (device.deviceId.toLowerCase() == deviceId.toLowerCase()) {
          return '${demplot.name} (${demplot.commodity})';
        }
      }
    }
    return 'Demplot Terkait';
  }

  /// Format waktu log yang user-friendly
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Baru saja';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} mnt lalu';
    } else if (now.year == createdAt.year &&
        now.month == createdAt.month &&
        now.day == createdAt.day) {
      return 'Hari ini ${DateFormat('HH:mm').format(createdAt)}';
    } else if (now.year == createdAt.year &&
        now.month == createdAt.month &&
        now.day - createdAt.day == 1) {
      return 'Kemarin ${DateFormat('HH:mm').format(createdAt)}';
    } else {
      // Ensure 'id_ID' is initialized in app or use default
      return DateFormat('dd MMM, HH:mm').format(createdAt);
    }
  }

  /// Icon log
  IconData get logIcon {
    final t = type.toLowerCase();
    if (t.contains('fertilizer') || t.contains('pupuk')) {
      return Icons.eco_rounded;
    } else if (t.contains('pesticide') || t.contains('pesti')) {
      return Icons.shield_outlined;
    } else {
      return Icons.water_drop_rounded;
    }
  }

  /// Warna log
  Color get logColor {
    final t = type.toLowerCase();
    if (t.contains('fertilizer') || t.contains('pupuk')) {
      return AppTheme.primaryColor;
    } else if (t.contains('pesticide') || t.contains('pesti')) {
      return const Color(0xFFD97706);
    } else {
      return const Color(0xFF0284C7);
    }
  }
}
