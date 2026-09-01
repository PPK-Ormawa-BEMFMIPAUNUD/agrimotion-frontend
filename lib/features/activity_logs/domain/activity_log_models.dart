import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:agrimotion/core/theme/colors.dart';

enum ActivityType { water, fertilizer, pesticide, login, unknown }

/// Represents a single record from `public.user_logins` table.
class UserLoginLog {
  final String id;
  final String userId;
  final String? name;
  final String? email;
  final String? role;
  final DateTime loginAt;
  final String? ipAddress;
  final String? userAgent;

  UserLoginLog({
    required this.id,
    required this.userId,
    this.name,
    this.email,
    this.role,
    required this.loginAt,
    this.ipAddress,
    this.userAgent,
  });

  String? get userName => name;
  String? get userEmail => email;

  factory UserLoginLog.fromJson(Map<String, dynamic> json) {
    String? uName = json['userName']?.toString() ?? json['name']?.toString();
    String? uEmail = json['userEmail']?.toString() ?? json['email']?.toString();
    String? uRole = json['role']?.toString();

    // Check nested user object if populated by backend
    if (json['user'] is Map<String, dynamic>) {
      final u = json['user'] as Map<String, dynamic>;
      uName ??= u['name']?.toString() ?? u['userName']?.toString();
      uEmail ??= u['email']?.toString() ?? u['userEmail']?.toString();
      uRole ??= u['role']?.toString();
    }

    DateTime loginTime = DateTime.now();
    if (json['loginAt'] != null) {
      loginTime = DateTime.tryParse(json['loginAt'].toString())?.toLocal() ?? DateTime.now();
    } else if (json['login_at'] != null) {
      loginTime = DateTime.tryParse(json['login_at'].toString())?.toLocal() ?? DateTime.now();
    } else if (json['createdAt'] != null) {
      loginTime = DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now();
    } else if (json['created_at'] != null) {
      loginTime = DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now();
    }

    return UserLoginLog(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      name: uName,
      email: uEmail,
      role: uRole,
      loginAt: loginTime,
      ipAddress: json['ipAddress']?.toString() ?? json['ip_address']?.toString(),
      userAgent: json['userAgent']?.toString() ?? json['user_agent']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'userName': name,
      'email': email,
      'userEmail': email,
      'role': role,
      'loginAt': loginAt.toIso8601String(),
      'ipAddress': ipAddress,
      'userAgent': userAgent,
    };
  }

  String get formattedLoginTime {
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(loginAt);
  }

  Color get roleBadgeColor {
    final roleUpper = role?.toUpperCase() ?? '';
    switch (roleUpper) {
      case 'ADMIN':
        return AppColors.primaryEmerald;
      case 'KADER_DIGITAL':
      case 'KADER':
        return AppColors.infoBlue;
      case 'OPERATOR':
        return AppColors.warningAmber;
      default:
        return AppColors.textSecondary;
    }
  }
}

/// Represents a single record from `public.watering_logs` table.
class WateringLog {
  final String id;
  final String deviceId;
  final String? deviceCode;
  final String? farmName;
  final String type; // 'WATER', 'FERTILIZER', 'PESTICIDE'
  final String? userId; // Nullable if triggered automatically by system/timer
  final String? operatorName;
  final int duration; // in seconds
  final DateTime createdAt;
  final String? status;
  final String? notes;

  WateringLog({
    required this.id,
    required this.deviceId,
    this.deviceCode,
    this.farmName,
    required this.type,
    this.userId,
    this.operatorName,
    required this.duration,
    required this.createdAt,
    this.status,
    this.notes,
  });

  String? get userName => operatorName;

  factory WateringLog.fromJson(Map<String, dynamic> json) {
    final devId = json['deviceId']?.toString() ?? json['device_id']?.toString() ?? '';
    
    // Check nested device/farm if populated by backend
    String? devCode = json['deviceCode']?.toString() ?? json['device_code']?.toString();
    String? fName = json['farmName']?.toString() ?? json['farm_name']?.toString();
    if (json['device'] is Map<String, dynamic>) {
      final dev = json['device'] as Map<String, dynamic>;
      devCode ??= dev['deviceCode']?.toString() ?? dev['device_code']?.toString();
      if (dev['farm'] is Map<String, dynamic>) {
        fName ??= (dev['farm'] as Map<String, dynamic>)['name']?.toString();
      }
    }

    // Infer device code and farm name from UUID if missing
    if (devCode == null || devCode.isEmpty) {
      if (devId.contains('10000000-0000-0000-0000-000000000001')) {
        devCode = 'node-1a';
        fName ??= 'Demplot 1';
      } else if (devId.contains('20000000-0000-0000-0000-000000000001')) {
        devCode = 'node-2a';
        fName ??= 'Demplot 2';
      } else if (devId.contains('30000000-0000-0000-0000-000000000001')) {
        devCode = 'node-3a';
        fName ??= 'Demplot 3';
      }
    }

    String? opName = json['userName']?.toString() ?? json['operatorName']?.toString() ?? json['operator_name']?.toString();
    if (json['user'] is Map<String, dynamic>) {
      final u = json['user'] as Map<String, dynamic>;
      opName ??= u['name']?.toString() ?? u['userName']?.toString();
    }

    DateTime createdDate = DateTime.now();
    if (json['createdAt'] != null) {
      createdDate = DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now();
    } else if (json['created_at'] != null) {
      createdDate = DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now();
    } else if (json['timestamp'] != null) {
      createdDate = DateTime.tryParse(json['timestamp'].toString())?.toLocal() ?? DateTime.now();
    }

    final int durationVal = json['duration'] != null
        ? (int.tryParse(json['duration'].toString()) ?? 0)
        : 0;

    return WateringLog(
      id: json['id']?.toString() ?? '',
      deviceId: devId,
      deviceCode: devCode,
      farmName: fName,
      type: json['type']?.toString().toUpperCase() ?? 'WATER',
      userId: json['userId']?.toString() ?? json['user_id']?.toString(),
      operatorName: opName,
      duration: durationVal,
      createdAt: createdDate,
      status: json['status']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'deviceCode': deviceCode,
      'farmName': farmName,
      'type': type,
      'userId': userId,
      'userName': operatorName,
      'operatorName': operatorName,
      'duration': duration,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'notes': notes,
    };
  }

  /// Whether this log was triggered automatically by schedule/sensor without a human user.
  bool get isAutomatic => userId == null || userId!.trim().isEmpty;

  String get actuationType => type;
  int get durationSeconds => duration;

  /// Formatted duration string, e.g. "15 Detik"
  String get formattedDuration => '$duration Detik';

  /// Formatted date string, e.g. "26 Agu 2026, 16:26"
  String get formattedTimestamp {
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(createdAt);
  }

  /// User-facing actor name. If automated, returns "Sistem Otomatis (ESP32)".
  String get actorName => (operatorName != null && operatorName!.trim().isNotEmpty)
      ? operatorName!
      : 'Sistem Otomatis (ESP32)';

  String get operatorDisplayName => actorName;

  /// User-friendly label according to actuation type.
  String get activityTitle {
    final t = type.toUpperCase();
    switch (t) {
      case 'WATER':
      case 'AIR':
        return isAutomatic ? 'Penyiraman Otomatis' : 'Penyiraman Air';
      case 'FERTILIZER':
      case 'PUPUK':
        return 'Pemupukan / Nutrisi';
      case 'PESTICIDE':
      case 'PESTISIDA':
        return 'Pemberantasan Hama / Pestisida';
      default:
        return 'Aktivitas Irigasi';
    }
  }

  String get actuationTypeLabel => activityTitle;

  /// Visual icon corresponding to the actuation type.
  IconData get actuationTypeIcon {
    final t = type.toUpperCase();
    switch (t) {
      case 'WATER':
      case 'AIR':
        return Icons.water_drop_rounded;
      case 'FERTILIZER':
      case 'PUPUK':
        return Icons.eco_rounded;
      case 'PESTICIDE':
      case 'PESTISIDA':
        return Icons.shield_outlined;
      default:
        return Icons.settings_remote_rounded;
    }
  }

  /// Theme color for badges and visual accents.
  Color get actuationTypeColor {
    final t = type.toUpperCase();
    switch (t) {
      case 'WATER':
      case 'AIR':
        return AppColors.infoBlue;
      case 'FERTILIZER':
      case 'PUPUK':
        return AppColors.primaryEmerald;
      case 'PESTICIDE':
      case 'PESTISIDA':
        return const Color(0xFFF97316); // Vibrant Orange for Pesticide
      default:
        return AppColors.textSecondary;
    }
  }
}

typedef WateringLogItem = WateringLog;
