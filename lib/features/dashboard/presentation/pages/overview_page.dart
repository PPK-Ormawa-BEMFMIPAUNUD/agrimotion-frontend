import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:agrimotion/shared/widgets/metric_card.dart';
import 'package:agrimotion/shared/widgets/status_badge.dart';
import 'package:agrimotion/core/theme/colors.dart';
import 'package:agrimotion/core/constants/app_constants.dart';
import 'package:agrimotion/core/router/app_router.dart';
import 'package:agrimotion/core/network/api_client.dart';
import 'package:agrimotion/core/constants/api_constants.dart';
import 'package:agrimotion/core/services/cache_service.dart';

/// Data model for dashboard quick navigation actions.
class _QuickActionItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String route;

  const _QuickActionItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.route,
  });
}

/// Main Admin Overview Dashboard page for AgriMotion.
///
/// Route: `/admin/overview`
///
/// Presents a high-level operational overview of the smart agriculture system,
/// including KPI metric counters, quick navigation shortcuts, live Demplot
/// soil conditions, and recent system activities.
class OverviewPage extends ConsumerStatefulWidget {
  const OverviewPage({super.key});

  @override
  ConsumerState<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends ConsumerState<OverviewPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;

  int _totalDemplots = 0;
  int _totalTransmissions = 0;
  int _activeDevices = 0;
  String _serverStatus = 'Loading';

  List<dynamic> _farms = [];
  List<dynamic> _latestTelemetry = [];
  List<dynamic> _recentActivities = [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const List<_QuickActionItem> _quickActions = [
    _QuickActionItem(
      title: 'Monitoring Lahan',
      description: 'Pantau sensor real-time & kontrol aktuator demplot',
      icon: Icons.analytics_outlined,
      color: AppColors.primaryEmerald,
      route: AppRoutes.farms,
    ),
    _QuickActionItem(
      title: 'Lihat Peringatan',
      description: 'Tinjau telemetri anomali & log status bahaya',
      icon: Icons.notifications_active_outlined,
      color: AppColors.warningAmber,
      route: AppRoutes.alerts,
    ),
    _QuickActionItem(
      title: 'Server Monitor',
      description: 'Inspeksi koneksi MQTT broker, SSE & database',
      icon: Icons.dns_outlined,
      color: AppColors.secondary,
      route: AppRoutes.serverMonitor,
    ),
    _QuickActionItem(
      title: 'Kelola Kader',
      description: 'Kelola akun kader digital & operator lapangan',
      icon: Icons.people_outline_rounded,
      color: Color(0xFF8B5CF6),
      route: AppRoutes.users,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(_pulseController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    
    final cacheService = ref.read(cacheServiceProvider);
    
    // Load from cache first
    final cachedFarms = cacheService.getCacheData('overview_farms');
    final cachedDevices = cacheService.getCacheData('overview_devices');
    final cachedTelemetryHist = cacheService.getCacheData('overview_telemetryHist');
    final cachedHealth = cacheService.getCacheData('overview_health');
    final cachedLatestTelemetry = cacheService.getCacheData('overview_latestTelemetry');

    if (cachedFarms != null || cachedDevices != null || cachedTelemetryHist != null) {
      setState(() {
        List fList = [];
        if (cachedFarms is List) {
          fList = cachedFarms;
        } else if (cachedFarms is Map && cachedFarms['data'] is List) {
          fList = cachedFarms['data'] as List;
        }
        _farms = fList;
        _totalDemplots = _farms.isNotEmpty ? _farms.length : 3;

        int activeDevs = 0;
        if (cachedDevices is Map) {
          activeDevs = cachedDevices['online'] ?? 0;
        } else if (cachedDevices is List) {
          activeDevs = cachedDevices.where((d) => d is Map && d['status'] == 'ONLINE').length;
        }
        _activeDevices = activeDevs;

        int totalTx = 0;
        List recentAct = [];
        if (cachedTelemetryHist is Map) {
          totalTx = cachedTelemetryHist['meta']?['total'] ?? 0;
          recentAct = cachedTelemetryHist['data'] as List? ?? [];
        } else if (cachedTelemetryHist is List) {
          totalTx = cachedTelemetryHist.length;
          recentAct = cachedTelemetryHist;
        }
        _totalTransmissions = totalTx;
        _recentActivities = recentAct;

        bool cachedOnline = false;
        if (cachedHealth is Map) {
          if (cachedHealth['status'] == 'ok' ||
              cachedHealth['data']?['status'] == 'ok' ||
              cachedHealth['success'] == true) {
            cachedOnline = true;
          }
        }
        _serverStatus = cachedOnline ? 'Online' : 'Offline';

        List latestList = [];
        if (cachedLatestTelemetry is List) {
          latestList = cachedLatestTelemetry;
        } else if (cachedLatestTelemetry is Map && cachedLatestTelemetry['data'] is List) {
          latestList = cachedLatestTelemetry['data'] as List;
        }
        _latestTelemetry = latestList;

        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final apiClient = ref.read(apiClientProvider);

      final farmsFuture = apiClient.get(Uri.parse(ApiConstants.farmsEndpoint)).catchError((_) => http.Response('{"data":[]}', 200));
      final devicesFuture = apiClient.get(Uri.parse(ApiConstants.devicesStatusEndpoint)).catchError((_) => http.Response('{"online":0}', 200));
      final telemetryHistFuture = apiClient.get(Uri.parse('${ApiConstants.telemetryHistoryEndpoint}?limit=5&sort=desc'), requiresAuth: false).catchError((_) => http.Response('{"meta":{"total":0},"data":[]}', 200));
      final healthFuture = apiClient.get(Uri.parse(ApiConstants.healthEndpoint), requiresAuth: false).catchError((_) => http.Response('{"status":"error"}', 200));
      final latestTelemetryFuture = apiClient.get(Uri.parse(ApiConstants.latestTelemetryEndpoint), requiresAuth: false).catchError((_) => http.Response('{"data":[]}', 200));

      final results = await Future.wait([
        farmsFuture,
        devicesFuture,
        telemetryHistFuture,
        healthFuture,
        latestTelemetryFuture,
      ]);

      List farmsList = [];
      try {
        final parsed = apiClient.parseJson(results[0]);
        if (parsed is List) {
          farmsList = parsed;
        } else if (parsed is Map && parsed['data'] is List) {
          farmsList = parsed['data'] as List;
        }
      } catch (_) {}

      // Fallback: Use Ground Truth 3 demplots if server returned empty
      if (farmsList.isEmpty) {
        farmsList = [
          {
            'id': '11111111-1111-1111-1111-111111111111',
            'name': 'Demplot 1',
            'commodity': 'Bunga Pacah',
            'emoji': '🌸',
            'location': 'Desa Nyanglan, Banjarangkan, Klungkung',
            'devices': [
              {
                'id': '10000000-0000-0000-0000-000000000001',
                'deviceCode': 'node-1a',
                'status': 'ONLINE',
              }
            ]
          },
          {
            'id': '22222222-2222-2222-2222-222222222222',
            'name': 'Demplot 2',
            'commodity': 'Sawi',
            'emoji': '🥬',
            'location': 'Desa Nyanglan, Banjarangkan, Klungkung',
            'devices': [
              {
                'id': '20000000-0000-0000-0000-000000000001',
                'deviceCode': 'node-2a',
                'status': 'ONLINE',
              }
            ]
          },
          {
            'id': '33333333-3333-3333-3333-333333333333',
            'name': 'Demplot 3',
            'commodity': 'Cabai',
            'emoji': '🌶️',
            'location': 'Desa Nyanglan, Banjarangkan, Klungkung',
            'devices': [
              {
                'id': '30000000-0000-0000-0000-000000000001',
                'deviceCode': 'node-3a',
                'status': 'ONLINE',
              }
            ]
          },
        ];
      }

      dynamic devicesData = {'online': 0};
      try {
        final parsed = apiClient.parseJson(results[1]);
        if (parsed is Map) {
          devicesData = parsed;
        } else if (parsed is List) {
          final onlineCount = parsed.where((d) => d is Map && d['status'] == 'ONLINE').length;
          devicesData = {'online': onlineCount, 'total': parsed.length};
        }
      } catch (_) {}

      dynamic telemetryHistData = {'meta': {'total': 0}, 'data': []};
      try {
        final parsed = apiClient.parseJson(results[2]);
        if (parsed is Map) {
          telemetryHistData = parsed;
        } else if (parsed is List) {
          telemetryHistData = {'meta': {'total': parsed.length}, 'data': parsed};
        }
      } catch (_) {}

      dynamic healthData = {'status': 'error'};
      try {
        final parsed = apiClient.parseJson(results[3]);
        if (parsed is Map) healthData = parsed;
      } catch (_) {}

      List latestTelemetryList = [];
      try {
        final parsed = apiClient.parseJson(results[4]);
        if (parsed is List) {
          latestTelemetryList = parsed;
        } else if (parsed is Map && parsed['data'] is List) {
          latestTelemetryList = parsed['data'] as List;
        }
      } catch (_) {}

      // Update Cache
      await cacheService.setCacheData('overview_farms', farmsList);
      await cacheService.setCacheData('overview_devices', devicesData);
      await cacheService.setCacheData('overview_telemetryHist', telemetryHistData);
      await cacheService.setCacheData('overview_health', healthData);
      await cacheService.setCacheData('overview_latestTelemetry', latestTelemetryList);

      if (!mounted) return;

      setState(() {
        _farms = farmsList;
        _totalDemplots = _farms.length;

        _activeDevices = devicesData is Map ? (devicesData['online'] ?? 0) : 0;

        _totalTransmissions = telemetryHistData is Map ? (telemetryHistData['meta']?['total'] ?? 0) : 0;
        _recentActivities = telemetryHistData is Map ? (telemetryHistData['data'] as List? ?? []) : [];

        bool isServerOnline = false;
        if (healthData is Map) {
          if (healthData['status'] == 'ok' ||
              healthData['data']?['status'] == 'ok' ||
              healthData['success'] == true) {
            isServerOnline = true;
          }
        }
        _serverStatus = isServerOnline ? 'Online' : 'Offline';

        _latestTelemetry = latestTelemetryList;

        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (cachedFarms == null && cachedDevices == null && cachedTelemetryHist == null) {
          _errorMessage = 'Gagal memuat data: ${e.toString()}';
        }
      });
    }
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    try {
      final formatter = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
      return formatter.format(now);
    } catch (_) {
      return DateFormat('dd MMM yyyy, HH:mm').format(now);
    }
  }

  String _getRelativeTime(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      final diff = DateTime.now().difference(date);
      if (diff.inSeconds < 60) {
        return 'Baru saja';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes} menit lalu';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} jam lalu';
      } else {
        return '${diff.inDays} hari lalu';
      }
    } catch (_) {
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= AppConstants.desktopBreakpoint;
            final horizontalPadding = isDesktop ? 32.0 : 16.0;

            if (_errorMessage != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.dangerRose,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _fetchData,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryEmerald,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Section
                  _buildHeader(context, isDark, isDesktop),
                  const SizedBox(height: 24.0),

                  // 2. KPI Summary Cards Grid
                  _buildKpiGrid(context, constraints, isDark),
                  const SizedBox(height: 32.0),

                  // 3. Quick Actions Row
                  _buildQuickActions(context, constraints, isDark),
                  const SizedBox(height: 32.0),

                  // 4 & 5. Main Content: Kondisi Lahan + Aktivitas Terkini
                  _buildMainContent(context, constraints, isDark),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Header Widget
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context, bool isDark, bool isDesktop) {
    final formattedDate = _formatCurrentDate();

    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ringkasan Dashboard',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Selamat datang kembali, Admin!',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          _buildDateTimeBadge(isDark, formattedDate),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan Dashboard',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Selamat datang kembali, Admin!',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        _buildDateTimeBadge(isDark, formattedDate),
      ],
    );
  }

  Widget _buildDateTimeBadge(bool isDark, String formattedDate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primaryEmerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: AppColors.primaryEmerald,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formattedDate,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.textDarkSecondary : AppColors.textTertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _serverStatus == 'Online' ? AppColors.optimalGreen : AppColors.dangerRose,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isLoading ? 'Menghubungkan...' : (_serverStatus == 'Online' ? 'Sistem Normal' : 'Sistem Bermasalah'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _serverStatus == 'Online' ? AppColors.optimalGreen : AppColors.dangerRose,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Skeleton Loader Widget
  // ---------------------------------------------------------------------------
  Widget _buildSkeletonBlock(double width, double height, double borderRadius, bool isDark) {
    return FadeTransition(
      opacity: _pulseAnimation,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[300],
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. KPI Summary Cards Grid
  // ---------------------------------------------------------------------------

  Widget _buildKpiGrid(
    BuildContext context,
    BoxConstraints constraints,
    bool isDark,
  ) {
    final bool isDesktop = constraints.maxWidth >= 900;

    final kpiCards = [
      MetricCard(
        title: 'Total Demplot',
        value: '$_totalDemplots',
        trendText: 'Semua operasional',
        isPositiveTrend: true,
        icon: Icons.grass_rounded,
        iconColor: AppColors.primaryEmerald,
        onTap: () => context.go(AppRoutes.farms),
      ),
      MetricCard(
        title: 'Total Transmisi',
        value: NumberFormat.decimalPattern('id').format(_totalTransmissions),
        trendText: 'Telemetri masuk',
        isPositiveTrend: true,
        icon: Icons.cloud_upload_rounded,
        iconColor: AppColors.secondary,
        onTap: () => context.go(AppRoutes.serverMonitor),
      ),
      MetricCard(
        title: 'Perangkat Aktif',
        value: '$_activeDevices',
        trendText: 'Online saat ini',
        isPositiveTrend: _activeDevices > 0,
        icon: Icons.sensors_rounded,
        iconColor: AppColors.infoBlue,
        onTap: () => context.go(AppRoutes.farms),
      ),
      MetricCard(
        title: 'Status Server',
        value: _serverStatus,
        trendText: _serverStatus == 'Online' ? 'Uptime stabil' : 'Koneksi terputus',
        isPositiveTrend: _serverStatus == 'Online',
        icon: Icons.dns_rounded,
        iconColor: _serverStatus == 'Online' ? AppColors.optimalGreen : AppColors.dangerRose,
        onTap: () => context.go(AppRoutes.serverMonitor),
      ),
    ];

    if (_isLoading) {
      if (isDesktop) {
        return Row(
          children: List.generate(4, (index) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index < 3 ? 16 : 0),
              child: _buildSkeletonBlock(double.infinity, 120, 16, isDark),
            ),
          )),
        );
      } else {
        final double cardWidth = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: List.generate(4, (index) => _buildSkeletonBlock(cardWidth, 120, 16, isDark)),
        );
      }
    }

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: kpiCards[0]),
          const SizedBox(width: 16),
          Expanded(child: kpiCards[1]),
          const SizedBox(width: 16),
          Expanded(child: kpiCards[2]),
          const SizedBox(width: 16),
          Expanded(child: kpiCards[3]),
        ],
      );
    }

    final double cardWidth = (constraints.maxWidth - 16) / 2;
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: kpiCards.map((card) => SizedBox(width: cardWidth, child: card)).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Quick Actions Row
  // ---------------------------------------------------------------------------

  Widget _buildQuickActions(
    BuildContext context,
    BoxConstraints constraints,
    bool isDark,
  ) {
    final bool isDesktop = constraints.maxWidth >= 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.bolt_rounded,
              size: 18,
              color: AppColors.primaryEmerald,
            ),
            const SizedBox(width: 6),
            Text(
              'Aksi Cepat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Pintasan navigasi modul utama',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        if (isDesktop)
          Row(
            children: [
              Expanded(child: _buildQuickActionCard(context, _quickActions[0], isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildQuickActionCard(context, _quickActions[1], isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildQuickActionCard(context, _quickActions[2], isDark)),
              const SizedBox(width: 16),
              Expanded(child: _buildQuickActionCard(context, _quickActions[3], isDark)),
            ],
          )
        else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: _quickActions.map((action) {
              final double cardWidth = constraints.maxWidth >= 600
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return SizedBox(
                width: cardWidth,
                child: _buildQuickActionCard(context, action, isDark),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    _QuickActionItem action,
    bool isDark,
  ) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.go(action.route),
        borderRadius: BorderRadius.circular(12),
        hoverColor: action.color.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  action.icon,
                  color: action.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            action.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textDarkPrimary
                                  : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: isDark
                              ? AppColors.textDarkSecondary
                              : AppColors.textTertiary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textDarkSecondary
                            : AppColors.textSecondary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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

  // ---------------------------------------------------------------------------
  // 4 & 5. Main Content: Kondisi Lahan + Aktivitas Terkini
  // ---------------------------------------------------------------------------

  Widget _buildMainContent(
    BuildContext context,
    BoxConstraints constraints,
    bool isDark,
  ) {
    final isDesktop = constraints.maxWidth >= AppConstants.desktopBreakpoint;

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Kondisi Lahan (Flex 3)
          Expanded(
            flex: 3,
            child: _buildDemplotSection(context, isDark),
          ),
          const SizedBox(width: 24.0),
          // Right: Aktivitas Terkini (Flex 2)
          Expanded(
            flex: 2,
            child: _buildActivitySection(context, isDark),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDemplotSection(context, isDark),
        const SizedBox(height: 24.0),
        _buildActivitySection(context, isDark),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Kondisi Lahan Section
  // ---------------------------------------------------------------------------

  Widget _buildDemplotSection(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryEmerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.landscape_rounded,
                      color: AppColors.primaryEmerald,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kondisi Lahan Demplot',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textDarkPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Status telemetri $_totalDemplots Demplot aktif',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textDarkSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => context.go(AppRoutes.farms),
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text('Lihat Detail'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Demplot Cards List
          if (_isLoading)
            Column(
              children: List.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildSkeletonBlock(double.infinity, 150, 12, isDark),
                ),
              ),
            )
          else if (_farms.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Belum ada data demplot',
                  style: TextStyle(
                    color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _farms.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final farm = _farms[index];
                return _buildDemplotCard(context, farm, isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDemplotCard(
    BuildContext context,
    dynamic farm,
    bool isDark,
  ) {
    final emoji = farm['emoji'] ?? (farm['name']?.toString().contains('1') == true ? '🌸' : (farm['name']?.toString().contains('2') == true ? '🥬' : '🌶️'));
    final devices = farm['devices'] as List? ?? [];
    String nodeCode = '-';
    Map<String, dynamic>? latestData;

    if (devices.isNotEmpty) {
      final dev = devices[0];
      nodeCode = dev['deviceCode'] ?? dev['device_code'] ?? dev['name'] ?? '-';
      final deviceId = dev['id'];
      
      try {
        latestData = _latestTelemetry.firstWhere((t) => t is Map && (t['deviceId'] == deviceId || t['device_id'] == deviceId), orElse: () => null);
      } catch (e) {
        latestData = null;
      }
    }

    double parseDouble(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    final moisture = parseDouble(latestData?['soilMoisture'] ?? latestData?['soil_moisture']);
    final temperature = parseDouble(latestData?['temperature']);
    final ph = parseDouble(latestData?['ph'] ?? latestData?['pH']);
    final timestamp = latestData?['timestamp']?.toString();

    SensorStatus calcStatus = SensorStatus.unknown;
    if (latestData != null) {
      if (moisture < 30 || moisture > 80 || ph < 5.5 || ph > 7.5) {
        calcStatus = SensorStatus.warning;
      } else {
        calcStatus = SensorStatus.optimal;
      }
    }

    return InkWell(
      onTap: () => context.go(AppRoutes.farms),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Name, Commodity, Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      emoji,
                      style: TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          farm['name'] ?? 'Demplot',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textDarkPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Node: $nodeCode',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textDarkSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                StatusBadge(status: calcStatus),
              ],
            ),
            const SizedBox(height: 16),
            // Row 2: Sensor Metrics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSensorMetric(
                  icon: Icons.water_drop_outlined,
                  value: '${moisture.toStringAsFixed(1)}%',
                  label: 'Kelembaban',
                  color: AppColors.infoBlue,
                  isDark: isDark,
                ),
                _buildSensorMetric(
                  icon: Icons.thermostat_outlined,
                  value: '${temperature.toStringAsFixed(1)}°C',
                  label: 'Suhu',
                  color: AppColors.warningAmber,
                  isDark: isDark,
                ),
                _buildSensorMetric(
                  icon: Icons.science_outlined,
                  value: ph.toStringAsFixed(1),
                  label: 'pH Tanah',
                  color: AppColors.secondary,
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 3: Last Updated
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: isDark ? AppColors.textDarkSecondary : AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  timestamp != null ? 'Pembaruan terakhir: ${_getRelativeTime(timestamp)}' : 'Belum ada data',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textDarkSecondary : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorMetric({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Aktivitas Terkini Section
  // ---------------------------------------------------------------------------

  Widget _buildActivitySection(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: AppColors.secondary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aktivitas Terkini',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textDarkPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Log peristiwa sistem terbaru',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textDarkSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Activity Timeline
          if (_isLoading)
            Column(
              children: List.generate(
                4,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      _buildSkeletonBlock(32, 32, 16, isDark),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSkeletonBlock(double.infinity, 40, 8, isDark)),
                    ],
                  ),
                ),
              ),
            )
          else if (_recentActivities.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Belum ada aktivitas',
                  style: TextStyle(
                    color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentActivities.length,
              itemBuilder: (context, index) {
                final activityData = _recentActivities[index];
                
                // Construct activity item from telemetry
                final timestamp = activityData['timestamp'] ?? '';
                final moisture = activityData['soilMoisture'] ?? 0;
                
                String category = 'Telemetri';
                Color accentColor = AppColors.infoBlue;
                IconData icon = Icons.sensors_rounded;
                
                if (moisture < 30 || moisture > 80) {
                   category = 'Peringatan';
                   accentColor = AppColors.warningAmber;
                   icon = Icons.warning_amber_rounded;
                }

                return _buildActivityTile(
                  title: 'Data masuk dari perangkat',
                  time: _getRelativeTime(timestamp),
                  category: category,
                  icon: icon,
                  accentColor: accentColor,
                  isDark: isDark,
                  isLast: index == _recentActivities.length - 1,
                );
              },
            ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go(AppRoutes.alerts),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                'Lihat Semua Log',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile({
    required String title,
    required String time,
    required String category,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Indicator
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: accentColor,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textDarkSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textDarkSecondary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
