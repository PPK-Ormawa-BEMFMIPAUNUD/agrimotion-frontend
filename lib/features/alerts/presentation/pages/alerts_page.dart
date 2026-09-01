import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agrimotion/core/theme/colors.dart';
import 'package:agrimotion/shared/widgets/status_badge.dart';
import 'package:agrimotion/core/network/api_client.dart';
import 'package:agrimotion/core/constants/api_constants.dart';
import 'package:agrimotion/core/services/cache_service.dart';

/// Severity level for system alerts.
enum AlertSeverityType {
  critical,
  warning,
  info;

  String get label {
    switch (this) {
      case AlertSeverityType.critical:
        return 'KRITIS';
      case AlertSeverityType.warning:
        return 'WASPADA';
      case AlertSeverityType.info:
        return 'INFORMASI';
    }
  }

  Color get color {
    switch (this) {
      case AlertSeverityType.critical:
        return AppColors.dangerRose;
      case AlertSeverityType.warning:
        return AppColors.warningAmber;
      case AlertSeverityType.info:
        return AppColors.infoBlue;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case AlertSeverityType.critical:
        return const Color(0xFFFEF2F2);
      case AlertSeverityType.warning:
        return const Color(0xFFFFFBEB);
      case AlertSeverityType.info:
        return const Color(0xFFEFF6FF);
    }
  }

  Color get borderColor {
    switch (this) {
      case AlertSeverityType.critical:
        return const Color(0xFFFCA5A5);
      case AlertSeverityType.warning:
        return const Color(0xFFFCD34D);
      case AlertSeverityType.info:
        return const Color(0xFF93C5FD);
    }
  }

  IconData get icon {
    switch (this) {
      case AlertSeverityType.critical:
        return Icons.error_outline_rounded;
      case AlertSeverityType.warning:
        return Icons.warning_amber_rounded;
      case AlertSeverityType.info:
        return Icons.info_outline_rounded;
    }
  }
}

/// Data model for alert items in the AgriMotion early warning system.
class AlertItemData {
  final String id;
  final String title;
  final String description;
  final AlertSeverityType severity;
  final String deviceId;
  final String location;
  final String? parameterValue;
  final DateTime timestamp;
  final bool isRead;
  final bool isResolved;

  const AlertItemData({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.deviceId,
    required this.location,
    this.parameterValue,
    required this.timestamp,
    this.isRead = false,
    this.isResolved = false,
  });

  AlertItemData copyWith({
    String? id,
    String? title,
    String? description,
    AlertSeverityType? severity,
    String? deviceId,
    String? location,
    String? parameterValue,
    DateTime? timestamp,
    bool? isRead,
    bool? isResolved,
  }) {
    return AlertItemData(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      deviceId: deviceId ?? this.deviceId,
      location: location ?? this.location,
      parameterValue: parameterValue ?? this.parameterValue,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isResolved: isResolved ?? this.isResolved,
    );
  }
}

/// System alerts page at `/admin/alerts` for monitoring IoT farm telemetry anomalies.
class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  List<AlertItemData> _alerts = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _selectedFilter = 'ALL'; // 'ALL', 'CRITICAL', 'WARNING', 'INFO'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final cacheService = ref.read(cacheServiceProvider);
    final cachedAlerts = cacheService.getCacheData('alerts_list');

    if (cachedAlerts != null && cachedAlerts is List) {
      if (mounted) {
        setState(() {
          _alerts = cachedAlerts.map((e) => AlertItemData(
            id: e['id']?.toString() ?? '',
            title: e['title'] ?? 'Peringatan',
            description: e['description'] ?? '',
            severity: _parseSeverity(e['severity']),
            deviceId: e['deviceId'] ?? 'Unknown',
            location: e['location'] ?? 'Sistem',
            parameterValue: e['parameterValue']?.toString(),
            timestamp: e['timestamp'] != null
                ? (DateTime.tryParse(e['timestamp'].toString()) ?? DateTime.now())
                : DateTime.now(),
            isRead: e['isRead'] ?? false,
            isResolved: e['isResolved'] ?? false,
          )).toList();
          _isLoading = false;
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

    try {
      final apiClient = ref.read(apiClientProvider);
      List<AlertItemData> fetchedAlerts = [];

      // 1. Fetch /alerts (Auth required)
      try {
        final alertsResponse = await apiClient.get(Uri.parse(ApiConstants.alertsEndpoint));
        final alertsJson = apiClient.parseJson(alertsResponse);
        if (alertsJson['success'] == true && alertsJson['data'] != null) {
          final data = alertsJson['data'] as List;
          for (var item in data) {
            fetchedAlerts.add(AlertItemData(
              id: item['id']?.toString() ?? '',
              title: item['title'] ?? 'Peringatan',
              description: item['description'] ?? '',
              severity: _parseSeverity(item['severity']),
              deviceId: item['deviceId'] ?? 'Unknown',
              location: item['location'] ?? 'Sistem',
              parameterValue: item['parameterValue']?.toString(),
              timestamp: item['timestamp'] != null
                  ? (DateTime.tryParse(item['timestamp'].toString()) ?? DateTime.now())
                  : DateTime.now(),
              isRead: item['isRead'] ?? false,
              isResolved: item['isResolved'] ?? false,
            ));
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch /alerts: $e');
      }

      // 2. Fetch /telemetry/latest (Public) and evaluate thresholds
      try {
        final telemetryResponse = await apiClient.get(Uri.parse(ApiConstants.latestTelemetryEndpoint), requiresAuth: false);
        final telemetryJson = apiClient.parseJson(telemetryResponse);
        if (telemetryJson['success'] == true && telemetryJson['data'] != null) {
          final data = telemetryJson['data'] as List;
          for (var item in data) {
            final deviceId = item['deviceId']?.toString() ?? 'Unknown';
            final double? moisture = item['soilMoisture'] != null ? double.tryParse(item['soilMoisture'].toString()) : null;
            final double? ph = item['ph'] != null ? double.tryParse(item['ph'].toString()) : null;
            final double? temp = item['temperature'] != null ? double.tryParse(item['temperature'].toString()) : null;
            
            final timestampStr = item['timestamp']?.toString();
            final ts = timestampStr != null
                ? (DateTime.tryParse(timestampStr) ?? DateTime.now())
                : DateTime.now();
            
            // Check Moisture
            if (moisture != null) {
              if (moisture < 25) {
                fetchedAlerts.add(_createTelemetryAlert('Kelembaban Kritis', 'Kelembaban tanah di bawah 25%.', AlertSeverityType.critical, deviceId, 'Kelembaban: $moisture%', ts));
              } else if (moisture < 40) {
                fetchedAlerts.add(_createTelemetryAlert('Kelembaban Rendah', 'Kelembaban tanah menurun di bawah 40%.', AlertSeverityType.warning, deviceId, 'Kelembaban: $moisture%', ts));
              }
            }
            
            // Check pH
            if (ph != null) {
              if (ph < 5.5 || ph > 8.0) {
                fetchedAlerts.add(_createTelemetryAlert('pH Kritis', 'pH tanah di luar batas aman (5.5 - 8.0).', AlertSeverityType.critical, deviceId, 'pH: $ph', ts));
              } else if (ph < 6.0 || ph > 7.5) {
                fetchedAlerts.add(_createTelemetryAlert('pH Tidak Optimal', 'pH tanah mendekati batas peringatan.', AlertSeverityType.warning, deviceId, 'pH: $ph', ts));
              }
            }
            
            // Check Temperature
            if (temp != null) {
              if (temp > 35) {
                fetchedAlerts.add(_createTelemetryAlert('Suhu Kritis', 'Suhu lingkungan sangat tinggi (> 35°C).', AlertSeverityType.critical, deviceId, 'Suhu: $temp°C', ts));
              } else if (temp > 32) {
                fetchedAlerts.add(_createTelemetryAlert('Suhu Tinggi', 'Suhu lingkungan meningkat (> 32°C).', AlertSeverityType.warning, deviceId, 'Suhu: $temp°C', ts));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to fetch /telemetry/latest: $e');
      }

      // Deduplicate alerts: keep only the single most recent alert per unique (deviceId + title + severity)
      final Map<String, AlertItemData> dedupedMap = {};
      for (final alert in fetchedAlerts) {
        final key = '${alert.deviceId}_${alert.title}_${alert.severity.name}';
        if (!dedupedMap.containsKey(key)) {
          dedupedMap[key] = alert;
        } else {
          if (alert.timestamp.isAfter(dedupedMap[key]!.timestamp)) {
            dedupedMap[key] = alert;
          }
        }
      }

      final List<AlertItemData> finalAlerts = dedupedMap.values.toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Cache the fetched alerts
      final cacheJson = finalAlerts.map((a) => {
        'id': a.id,
        'title': a.title,
        'description': a.description,
        'severity': a.severity.toString().split('.').last,
        'deviceId': a.deviceId,
        'location': a.location,
        'parameterValue': a.parameterValue,
        'timestamp': a.timestamp.toIso8601String(),
        'isRead': a.isRead,
        'isResolved': a.isResolved,
      }).toList();
      await cacheService.setCacheData('alerts_list', cacheJson);

      if (mounted) {
        setState(() {
          _alerts = finalAlerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_alerts.isEmpty) {
            _errorMessage = e.toString();
          }
          _isLoading = false;
        });
      }
    }
  }

  AlertSeverityType _parseSeverity(dynamic val) {
    if (val == null) return AlertSeverityType.info;
    final str = val.toString().toLowerCase();
    if (str.contains('critical')) return AlertSeverityType.critical;
    if (str.contains('warning')) return AlertSeverityType.warning;
    return AlertSeverityType.info;
  }
  
  AlertItemData _createTelemetryAlert(String title, String desc, AlertSeverityType severity, String deviceId, String paramValue, DateTime ts) {
    return AlertItemData(
      id: 'TEL-${ts.millisecondsSinceEpoch}-${deviceId.hashCode}-${title.hashCode}',
      title: title,
      description: desc,
      severity: severity,
      deviceId: deviceId,
      location: _getLocationForDevice(deviceId),
      parameterValue: paramValue,
      timestamp: ts,
    );
  }

  String _getLocationForDevice(String deviceId) {
    if (deviceId.contains('10000000') || deviceId.toLowerCase().contains('node-1')) return 'Demplot 1 (Bunga Pacah)';
    if (deviceId.contains('20000000') || deviceId.toLowerCase().contains('node-2')) return 'Demplot 2 (Sawi Organik)';
    if (deviceId.contains('30000000') || deviceId.toLowerCase().contains('node-3')) return 'Demplot 3 (Cabai Rawit)';
    return 'Demplot Nyanglan';
  }

  void _refreshAlerts() {
    _fetchData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 10),
            Text('Daftar peringatan berhasil disegarkan dari server.'),
          ],
        ),
        backgroundColor: AppColors.primaryEmerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _markAllAsRead() {
    if (_alerts.isEmpty) return;
    setState(() {
      _alerts = _alerts.map((a) => a.copyWith(isRead: true)).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.done_all_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Semua peringatan telah ditandai sebagai dibaca.'),
          ],
        ),
        backgroundColor: AppColors.primaryEmerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _dismissAlert(AlertItemData alert) {
    final int index = _alerts.indexWhere((a) => a.id == alert.id);
    if (index == -1) return;

    setState(() {
      _alerts.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Peringatan "${alert.title}" diabaikan.'),
        action: SnackBarAction(
          label: 'Urungkan',
          textColor: Colors.amberAccent,
          onPressed: () {
            setState(() {
              _alerts.insert(index, alert);
            });
          },
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _handleFollowUpAction(AlertItemData alert) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _AlertActionDialog(
          alert: alert,
          onActionTaken: (actionName) async {
            // Resolve on backend if it is a real alert ID (not generated from telemetry)
            if (!alert.id.startsWith('TEL-')) {
              try {
                final apiClient = ref.read(apiClientProvider);
                await apiClient.patch(Uri.parse('${ApiConstants.alertsEndpoint}/${alert.id}/resolve'));
              } catch (e) {
                debugPrint('Failed to resolve alert: $e');
              }
            }

            if (!mounted) return;

            setState(() {
              final idx = _alerts.indexWhere((a) => a.id == alert.id);
              if (idx != -1) {
                _alerts[idx] =
                    _alerts[idx].copyWith(isResolved: true, isRead: true);
              }
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Tindakan "$actionName" berhasil dieksekusi untuk ${alert.deviceId}.',
                ),
                backgroundColor: AppColors.primaryEmerald,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  Widget _buildShimmer(bool isDark) {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 140,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800]!.withValues(alpha: 0.5) : Colors.grey[300]!.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.dangerRose.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.dangerRose,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Gagal Memuat Peringatan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Terjadi kesalahan sistem saat memuat data dari server.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Coba Lagi'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryEmerald,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final int criticalCount = _alerts
        .where((a) => a.severity == AlertSeverityType.critical && !a.isResolved)
        .length;
    final int warningCount = _alerts
        .where((a) => a.severity == AlertSeverityType.warning && !a.isResolved)
        .length;
    final int infoCount = _alerts
        .where((a) => a.severity == AlertSeverityType.info && !a.isResolved)
        .length;

    // Filter alerts based on selection and search
    final filteredAlerts = _alerts.where((alert) {
      if (_selectedFilter == 'CRITICAL' &&
          alert.severity != AlertSeverityType.critical) {
        return false;
      }
      if (_selectedFilter == 'WARNING' &&
          alert.severity != AlertSeverityType.warning) {
        return false;
      }
      if (_selectedFilter == 'INFO' &&
          alert.severity != AlertSeverityType.info) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = alert.title.toLowerCase().contains(query);
        final matchDesc = alert.description.toLowerCase().contains(query);
        final matchDevice = alert.deviceId.toLowerCase().contains(query);
        final matchLocation = alert.location.toLowerCase().contains(query);
        return matchTitle || matchDesc || matchDevice || matchLocation;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              _buildHeader(context, isDark, criticalCount, warningCount),
              const SizedBox(height: 20),

              // Summary Cards
              _buildSummaryCards(
                context,
                isDark,
                criticalCount,
                warningCount,
                infoCount,
              ),
              const SizedBox(height: 24),

              // Filter Tabs & Search Bar
              _buildFilterAndSearchRow(context, isDark),
              const SizedBox(height: 16),

              // Content Area
              if (_isLoading)
                _buildShimmer(isDark)
              else if (_errorMessage != null)
                _buildErrorState(isDark)
              else if (filteredAlerts.isEmpty)
                _buildEmptyState(context, isDark)
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredAlerts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final alert = filteredAlerts[index];
                    return _buildAlertCard(context, alert, isDark);
                  },
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    int criticalCount,
    int warningCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 650;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primaryEmerald,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Sistem Peringatan Dini',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textDarkPrimary
                        : AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              criticalCount > 0 || warningCount > 0
                  ? 'Terdeteksi $criticalCount peringatan kritis dan $warningCount peringatan waspada yang membutuhkan perhatian.'
                  : 'Semua sistem telemetri sensor dan irigasi beroperasi dalam kondisi optimal.',
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textDarkSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        );

        final actionButtons = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: _refreshAlerts,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Segarkan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark
                    ? AppColors.textDarkPrimary
                    : AppColors.textPrimary,
                side: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _alerts.isEmpty ? null : _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Tandai Semua Dibaca'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryEmerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 16),
              actionButtons,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            actionButtons,
          ],
        );
      },
    );
  }

  Widget _buildSummaryCards(
    BuildContext context,
    bool isDark,
    int criticalCount,
    int warningCount,
    int infoCount,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool useGrid = width < 720;

        if (useGrid) {
          return Column(
            children: [
              _buildSummaryCardItem(
                title: 'Peringatan Kritis',
                count: criticalCount,
                subtitle: 'Membutuhkan tindakan darurat',
                color: AppColors.dangerRose,
                icon: Icons.error_rounded,
                isDark: isDark,
                onTap: () => setState(() => _selectedFilter = 'CRITICAL'),
                isSelected: _selectedFilter == 'CRITICAL',
              ),
              const SizedBox(height: 12),
              _buildSummaryCardItem(
                title: 'Peringatan Waspada',
                count: warningCount,
                subtitle: 'Perlu pemantauan berkala',
                color: AppColors.warningAmber,
                icon: Icons.warning_rounded,
                isDark: isDark,
                onTap: () => setState(() => _selectedFilter = 'WARNING'),
                isSelected: _selectedFilter == 'WARNING',
              ),
              const SizedBox(height: 12),
              _buildSummaryCardItem(
                title: 'Informasi Sistem',
                count: infoCount,
                subtitle: 'Pemberitahuan & log rutin',
                color: AppColors.infoBlue,
                icon: Icons.info_rounded,
                isDark: isDark,
                onTap: () => setState(() => _selectedFilter = 'INFO'),
                isSelected: _selectedFilter == 'INFO',
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildSummaryCardItem(
                title: 'Peringatan Kritis',
                count: criticalCount,
                subtitle: 'Membutuhkan tindakan darurat',
                color: AppColors.dangerRose,
                icon: Icons.error_rounded,
                isDark: isDark,
                onTap: () => setState(() => _selectedFilter = 'CRITICAL'),
                isSelected: _selectedFilter == 'CRITICAL',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCardItem(
                title: 'Peringatan Waspada',
                count: warningCount,
                subtitle: 'Perlu pemantauan berkala',
                color: AppColors.warningAmber,
                icon: Icons.warning_rounded,
                isDark: isDark,
                onTap: () => setState(() => _selectedFilter = 'WARNING'),
                isSelected: _selectedFilter == 'WARNING',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCardItem(
                title: 'Informasi Sistem',
                count: infoCount,
                subtitle: 'Pemberitahuan & log rutin',
                color: AppColors.infoBlue,
                icon: Icons.info_rounded,
                isDark: isDark,
                onTap: () => setState(() => _selectedFilter = 'INFO'),
                isSelected: _selectedFilter == 'INFO',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCardItem({
    required String title,
    required int count,
    required String subtitle,
    required Color color,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isSelected ? 0.12 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textDarkSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Aktif',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textDarkSecondary.withValues(alpha: 0.7)
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterAndSearchRow(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isStacked = constraints.maxWidth < 700;

        final filterChips = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip('ALL', 'Semua', null, isDark),
            _buildFilterChip(
              'CRITICAL',
              'Kritis',
              AppColors.dangerRose,
              isDark,
            ),
            _buildFilterChip(
              'WARNING',
              'Waspada',
              AppColors.warningAmber,
              isDark,
            ),
            _buildFilterChip('INFO', 'Informasi', AppColors.infoBlue, isDark),
          ],
        );

        final searchField = SizedBox(
          width: isStacked ? double.infinity : 280,
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Cari peringatan atau ID node...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textDarkSecondary
                    : AppColors.textTertiary,
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              filled: true,
              fillColor:
                  isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.primaryEmerald,
                  width: 1.5,
                ),
              ),
            ),
          ),
        );

        if (isStacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              filterChips,
              const SizedBox(height: 12),
              searchField,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            filterChips,
            searchField,
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(
    String filterKey,
    String label,
    Color? accentColor,
    bool isDark,
  ) {
    final bool isSelected = _selectedFilter == filterKey;
    final Color activeBg = accentColor ?? AppColors.primaryEmerald;

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected
            ? Colors.white
            : (isDark
                ? AppColors.textDarkPrimary
                : AppColors.textPrimary),
      ),
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      selectedColor: activeBg,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected
            ? activeBg
            : (isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = filterKey;
        });
      },
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    AlertItemData alert,
    bool isDark,
  ) {
    final Color severityColor = alert.severity.color;
    final Color borderColor = isDark
        ? severityColor.withValues(alpha: 0.5)
        : alert.severity.borderColor;
    final Color cardBackground = isDark
        ? AppColors.surfaceDark
        : (alert.isRead
            ? AppColors.surfaceLight
            : alert.severity.backgroundColor.withValues(alpha: 0.5));

    return Container(
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: alert.severity == AlertSeverityType.critical ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: severityColor.withValues(
              alpha: alert.severity == AlertSeverityType.critical ? 0.08 : 0.03,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Severity Badge, Device Info, Time Ago
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              StatusBadge.custom(
                label: alert.severity.label,
                color: severityColor,
                fontSize: 11,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.elevatedDark
                      : AppColors.borderLight.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  alert.deviceId,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textDarkSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: isDark
                    ? AppColors.textDarkSecondary
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                _formatTimeAgo(alert.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textDarkSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title & Description
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                alert.severity.icon,
                color: severityColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textDarkPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.description,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: isDark
                            ? AppColors.textDarkSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Metadata Row: Location & Parameter Value
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.elevatedDark.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? AppColors.borderDark
                    : AppColors.borderLight.withValues(alpha: 0.8),
              ),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: isDark
                          ? AppColors.textDarkSecondary
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      alert.location,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textDarkSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (alert.parameterValue != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.sensors_rounded,
                        size: 14,
                        color: severityColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Nilai: ${alert.parameterValue!}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: severityColor,
                        ),
                      ),
                    ],
                  ),
                if (alert.isResolved)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.optimalGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Telah Ditangani',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.optimalGreen,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _dismissAlert(alert),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Abaikan'),
                style: TextButton.styleFrom(
                  foregroundColor: isDark
                      ? AppColors.textDarkSecondary
                      : AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (alert.severity == AlertSeverityType.critical ||
                  alert.severity == AlertSeverityType.warning)
                FilledButton.icon(
                  onPressed: () => _handleFollowUpAction(alert),
                  icon: const Icon(Icons.bolt_rounded, size: 16),
                  label: const Text('Tindak Lanjut'),
                  style: FilledButton.styleFrom(
                    backgroundColor: alert.severity == AlertSeverityType.critical
                        ? AppColors.dangerRose
                        : AppColors.warningAmber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.optimalGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: AppColors.optimalGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada peringatan aktif saat ini',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textDarkPrimary
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty || _selectedFilter != 'ALL'
                ? 'Tidak ada peringatan yang cocok dengan filter atau kata kunci pencarian.'
                : 'Semua sensor, aktuator irigasi, dan node IoT berfungsi normal.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textDarkSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          if (_searchQuery.isNotEmpty || _selectedFilter != 'ALL')
            OutlinedButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _selectedFilter = 'ALL';
                });
              },
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Reset Filter'),
            ),
        ],
      ),
    );
  }
}

/// Modal dialog for selecting follow-up actions on critical and warning alerts.
class _AlertActionDialog extends StatefulWidget {
  final AlertItemData alert;
  final ValueChanged<String> onActionTaken;

  const _AlertActionDialog({
    required this.alert,
    required this.onActionTaken,
  });

  @override
  State<_AlertActionDialog> createState() => _AlertActionDialogState();
}

class _AlertActionDialogState extends State<_AlertActionDialog> {
  String _selectedAction = 'irrigate_auto';
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor:
          isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.alert.severity.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.bolt_rounded,
              color: widget.alert.severity.color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tindak Lanjut Peringatan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.alert.title,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.alert.severity.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pilih langkah respons darurat atau instruksi lapangan untuk perangkat telemetri ${widget.alert.deviceId}:',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textDarkSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            _buildActionOption(
              value: 'irrigate_auto',
              title: 'Aktifkan Pompa Irigasi Otomatis (10 Menit)',
              subtitle:
                  'Mengirim sinyal aktuasi pompa air ke zona bedeng terkait melalui MQTT.',
              icon: Icons.water_drop_rounded,
              color: AppColors.infoBlue,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildActionOption(
              value: 'notify_cadre',
              title: 'Broadcast WhatsApp ke Kader Lapangan',
              subtitle:
                  'Kirim pesan alert instan kepada tim kader digital yang bertugas di demplot.',
              icon: Icons.chat_rounded,
              color: AppColors.optimalGreen,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildActionOption(
              value: 'schedule_visit',
              title: 'Jadwalkan Kunjungan Tim Teknis',
              subtitle:
                  'Buat tiket inspeksi fisik perangkat sensor dan pengecekan pipa saluran.',
              icon: Icons.calendar_today_rounded,
              color: AppColors.warningAmber,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            _buildActionOption(
              value: 'resolve_manual',
              title: 'Tandai Selesai / Ditangani Manual',
              subtitle:
                  'Tutup status peringatan setelah penanganan manual di lapangan selesai.',
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.textSecondary,
              isDark: isDark,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _isProcessing ? null : _submitAction,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryEmerald,
          ),
          icon: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded, size: 16),
          label: Text(_isProcessing ? 'Memproses...' : 'Kirim Tindakan'),
        ),
      ],
    );
  }

  Widget _buildActionOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final bool isSelected = _selectedAction == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedAction = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.2 : 0.08)
                : (isDark
                    ? AppColors.elevatedDark.withValues(alpha: 0.3)
                    : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2, right: 8),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? color
                        : (isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        ),
                      )
                    : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 16, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textDarkPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? AppColors.textDarkSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitAction() {
    setState(() => _isProcessing = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      String actionLabel = 'Aktivasi Irigasi Otomatis';
      if (_selectedAction == 'notify_cadre') {
        actionLabel = 'Broadcast WhatsApp';
      } else if (_selectedAction == 'schedule_visit') {
        actionLabel = 'Jadwal Kunjungan';
      } else if (_selectedAction == 'resolve_manual') {
        actionLabel = 'Penanganan Selesai';
      }

      Navigator.of(context).pop();
      widget.onActionTaken(actionLabel);
    });
  }
}
