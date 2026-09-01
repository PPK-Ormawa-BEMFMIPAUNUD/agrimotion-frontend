import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:agrimotion/core/theme/colors.dart';
import 'package:agrimotion/core/constants/app_constants.dart';
import 'package:agrimotion/core/constants/api_constants.dart';
import 'package:agrimotion/core/network/sse_client.dart';
import 'package:agrimotion/features/auth/presentation/controllers/auth_controller.dart';
import 'package:agrimotion/core/services/cache_service.dart';

/// Available log severity levels in the AgriMotion server runtime.
enum ServerLogLevel {
  all('ALL', 'Semua', Color(0xFFE6EDF3), Color(0xFF30363D), Icons.list_alt_rounded),
  info('INFO', 'Info', Color(0xFF3FB950), Color(0x263FB950), Icons.info_outline_rounded),
  warn('WARN', 'Peringatan', Color(0xFFD29922), Color(0x26D29922), Icons.warning_amber_rounded),
  error('ERROR', 'Error', Color(0xFFF85149), Color(0x26F85149), Icons.error_outline_rounded),
  debug('DEBUG', 'Debug', Color(0xFF58A6FF), Color(0x2658A6FF), Icons.bug_report_outlined),
  http('HTTP', 'HTTP', Color(0xFF39C5CF), Color(0x2639C5CF), Icons.http_rounded),
  mqtt('MQTT', 'MQTT', Color(0xFFBC8CFF), Color(0x26BC8CFF), Icons.hub_outlined);

  final String label;
  final String indonesianLabel;
  final Color color;
  final Color bgHighlight;
  final IconData icon;

  const ServerLogLevel(
    this.label,
    this.indonesianLabel,
    this.color,
    this.bgHighlight,
    this.icon,
  );
}

/// Model representing an individual server log entry.
class ServerLogEntry {
  final String id;
  final DateTime timestamp;
  final ServerLogLevel level;
  final String message;
  final String source;

  const ServerLogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.message,
    required this.source,
  });

  /// Formats the timestamp to HH:mm:ss for terminal display.
  String get formattedTime {
    final DateFormat formatter = DateFormat('HH:mm:ss');
    return formatter.format(timestamp);
  }

  /// Full formatted terminal string representation.
  String get formattedLine => '[$formattedTime] [${level.label}] $message';
}

/// Model holding real-time system performance metrics for the AgriMotion server.
class SystemMetricsData {
  final String cpuModel;
  final int cpuCores;
  final int memoryUsedMb;
  final int memoryTotalMb;
  final double memoryPercent;
  final String dbStatus;
  final String mqttStatus;
  final int uptimeSeconds;
  final String appVersion;

  const SystemMetricsData({
    required this.cpuModel,
    required this.cpuCores,
    required this.memoryUsedMb,
    required this.memoryTotalMb,
    required this.memoryPercent,
    required this.dbStatus,
    required this.mqttStatus,
    required this.uptimeSeconds,
    required this.appVersion,
  });

  /// Formatted human-readable server uptime string.
  String get formattedUptime {
    final int days = uptimeSeconds ~/ 86400;
    final int hours = (uptimeSeconds % 86400) ~/ 3600;
    final int minutes = (uptimeSeconds % 3600) ~/ 60;
    final int seconds = uptimeSeconds % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m ${seconds}s';
    }
    return '${hours}h ${minutes}m ${seconds}s';
  }

  /// Creates a copy with optionally mutated field values.
  SystemMetricsData copyWith({
    String? cpuModel,
    int? cpuCores,
    int? memoryUsedMb,
    int? memoryTotalMb,
    double? memoryPercent,
    String? dbStatus,
    String? mqttStatus,
    int? uptimeSeconds,
    String? appVersion,
  }) {
    return SystemMetricsData(
      cpuModel: cpuModel ?? this.cpuModel,
      cpuCores: cpuCores ?? this.cpuCores,
      memoryUsedMb: memoryUsedMb ?? this.memoryUsedMb,
      memoryTotalMb: memoryTotalMb ?? this.memoryTotalMb,
      memoryPercent: memoryPercent ?? this.memoryPercent,
      dbStatus: dbStatus ?? this.dbStatus,
      mqttStatus: mqttStatus ?? this.mqttStatus,
      uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
      appVersion: appVersion ?? this.appVersion,
    );
  }
}

/// Server Monitor Page with live hardware metrics and real-time terminal log viewer.
class ServerMonitorPage extends ConsumerStatefulWidget {
  const ServerMonitorPage({super.key});

  @override
  ConsumerState<ServerMonitorPage> createState() => _ServerMonitorPageState();
}

class _ServerMonitorPageState extends ConsumerState<ServerMonitorPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _terminalScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;

  Timer? _pollingTimer;

  bool _isLoading = true;
  String _connectionState = 'connected'; // 'connected', 'reconnecting', 'offline'

  // Realtime state
  SystemMetricsData _metrics = const SystemMetricsData(
    cpuModel: '-',
    cpuCores: 0,
    memoryUsedMb: 0,
    memoryTotalMb: 0,
    memoryPercent: 0,
    dbStatus: 'down',
    mqttStatus: 'down',
    uptimeSeconds: 0,
    appVersion: '1.0.0',
  );

  final List<ServerLogEntry> _logs = <ServerLogEntry>[];
  ServerLogLevel _selectedFilterLevel = ServerLogLevel.all;
  String _searchQuery = '';
  bool _isAutoScrollEnabled = true;
  bool _isStreamPaused = false;
  int _logSequenceCounter = 0;

  @override
  void initState() {
    super.initState();

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _fetchData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchData());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _terminalScrollController.dispose();
    _searchController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final cacheService = ref.read(cacheServiceProvider);
    final cachedInfo = cacheService.getCacheData('server_monitor_info');
    final cachedHealth = cacheService.getCacheData('server_monitor_health');

    if (cachedInfo != null && cachedHealth != null) {
      if (mounted) {
        setState(() {
          _metrics = SystemMetricsData(
            cpuModel: cachedInfo['system']?['cpu']?['model'] ?? 'Unknown CPU',
            cpuCores: cachedInfo['system']?['cpu']?['cores'] ?? 0,
            memoryUsedMb: (cachedInfo['system']?['memory']?['used'] ?? 0).toInt(),
            memoryTotalMb: (cachedInfo['system']?['memory']?['total'] ?? 0).toInt(),
            memoryPercent: (cachedInfo['system']?['memory']?['percentage'] ?? 0).toDouble(),
            dbStatus: cachedHealth['info']?['database']?['status'] ?? 'down',
            mqttStatus: cachedHealth['info']?['mqtt']?['status'] ?? 'down',
            uptimeSeconds: cachedInfo['app']?['uptimeSeconds'] ?? 0,
            appVersion: cachedInfo['app']?['version'] ?? '1.0.0',
          );
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    }

    try {
      final authState = ref.read(authProvider);
      final token = authState.session?.accessToken;
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final http.Response infoRes = await http.get(Uri.parse(ApiConstants.systemInfoEndpoint), headers: headers).timeout(ApiConstants.requestTimeout);
      final http.Response healthRes = await http.get(Uri.parse(ApiConstants.healthEndpoint), headers: headers).timeout(ApiConstants.requestTimeout);

      if (infoRes.statusCode == 200 && healthRes.statusCode == 200) {
        final Map<String, dynamic> infoData = jsonDecode(infoRes.body);
        final Map<String, dynamic> healthData = jsonDecode(healthRes.body);

        await cacheService.setCacheData('server_monitor_info', infoData);
        await cacheService.setCacheData('server_monitor_health', healthData);

        if (mounted) {
          setState(() {
            _metrics = SystemMetricsData(
              cpuModel: infoData['system']?['cpu']?['model'] ?? 'Unknown CPU',
              cpuCores: infoData['system']?['cpu']?['cores'] ?? 0,
              memoryUsedMb: (infoData['system']?['memory']?['used'] ?? 0).toInt(),
              memoryTotalMb: (infoData['system']?['memory']?['total'] ?? 0).toInt(),
              memoryPercent: (infoData['system']?['memory']?['percentage'] ?? 0).toDouble(),
              dbStatus: healthData['info']?['database']?['status'] ?? 'down',
              mqttStatus: healthData['info']?['mqtt']?['status'] ?? 'down',
              uptimeSeconds: infoData['app']?['uptimeSeconds'] ?? 0,
              appVersion: infoData['app']?['version'] ?? '1.0.0',
            );
            _isLoading = false;
            _connectionState = 'connected';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _connectionState = 'reconnecting';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionState = 'reconnecting'; // Display reconnecting/offline instead of showing a full page error
          _isLoading = false;
        });
      }
    }
  }

  /// Smoothly scrolls the terminal log container to the bottom.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_terminalScrollController.hasClients) {
        _terminalScrollController.animateTo(
          _terminalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Filters logs based on the active level and search string query.
  List<ServerLogEntry> get _filteredLogs {
    return _logs.where((ServerLogEntry log) {
      final bool matchesLevel = _selectedFilterLevel == ServerLogLevel.all ||
          log.level == _selectedFilterLevel;
      final bool matchesQuery = _searchQuery.isEmpty ||
          log.message.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log.level.label.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          log.source.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesLevel && matchesQuery;
    }).toList();
  }

  /// Calculates counts per log level for badge counters.
  Map<ServerLogLevel, int> get _levelCounts {
    final Map<ServerLogLevel, int> counts = <ServerLogLevel, int>{
      ServerLogLevel.all: _logs.length,
      ServerLogLevel.info: 0,
      ServerLogLevel.warn: 0,
      ServerLogLevel.error: 0,
      ServerLogLevel.debug: 0,
      ServerLogLevel.http: 0,
      ServerLogLevel.mqtt: 0,
    };

    for (final ServerLogEntry log in _logs) {
      counts[log.level] = (counts[log.level] ?? 0) + 1;
    }
    return counts;
  }

  /// Copies all currently visible filtered logs to the system clipboard.
  void _copyFilteredLogsToClipboard() {
    final List<ServerLogEntry> currentLogs = _filteredLogs;
    if (currentLogs.isEmpty) return;

    final String exportText = currentLogs.map((e) => e.formattedLine).join('\n');
    Clipboard.setData(ClipboardData(text: exportText));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${currentLogs.length} baris log berhasil disalin ke clipboard.',
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        backgroundColor: AppColors.primaryEmerald,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Clears current terminal logs.
  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Terminal logs telah dibersihkan.',
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFF334155),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Sends a simulated high-priority test log.
  void _sendManualTestLog() {
    _logSequenceCounter++;
    final ServerLogEntry testEntry = ServerLogEntry(
      id: 'log-$_logSequenceCounter',
      timestamp: DateTime.now(),
      level: ServerLogLevel.warn,
      message: '[MANUAL_TEST] Operator triggering simulated alert diagnostics on all Demplot nodes',
      source: 'AdminConsole',
    );
    setState(() {
      _logs.add(testEntry);
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<LogEntry>>(serverLogStreamProvider, (AsyncValue<LogEntry>? previous, AsyncValue<LogEntry> next) {
      if (next is AsyncData<LogEntry> && !_isStreamPaused) {
        final LogEntry entry = next.value;
        _logSequenceCounter++;
        
        ServerLogLevel mapLevel(LogLevel l) {
          switch (l) {
            case LogLevel.info: return ServerLogLevel.info;
            case LogLevel.warn: return ServerLogLevel.warn;
            case LogLevel.error: return ServerLogLevel.error;
            case LogLevel.debug: return ServerLogLevel.debug;
            case LogLevel.http: return ServerLogLevel.http;
            case LogLevel.mqtt: return ServerLogLevel.mqtt;
          }
        }
        
        final ServerLogEntry newEntry = ServerLogEntry(
          id: 'log-$_logSequenceCounter',
          timestamp: entry.timestamp,
          level: mapLevel(entry.level),
          message: entry.message,
          source: entry.source ?? 'Unknown',
        );
        
        if (mounted) {
          setState(() {
            _logs.add(newEntry);
            if (_logs.length > 200) _logs.removeAt(0);
          });
          if (_isAutoScrollEnabled) _scrollToBottom();
        }
      }
    });

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isDesktop = MediaQuery.of(context).size.width >= AppConstants.desktopBreakpoint;

    Widget bodyContent;
    
    if (_isLoading) {
      bodyContent = _buildShimmerLoading(isDark);
    } else {
      bodyContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildPageHeader(isDark),
          const SizedBox(height: 20),
          _buildServiceStatusRow(isDark),
          const SizedBox(height: 20),
          _buildMetricsGrid(isDesktop, isDark),
          const SizedBox(height: 24),
          _buildTerminalLogViewer(isDark),
          const SizedBox(height: 24),
        ],
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: bodyContent,
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return FadeTransition(
      opacity: _pulseAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: List<Widget>.generate(
              4,
              (int index) => Expanded(
                child: Container(
                  height: 140,
                  margin: EdgeInsets.only(right: index < 3 ? 12 : 0),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 400,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the top page header with breadcrumbs and fast action buttons.
  Widget _buildPageHeader(bool isDark) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isCompact = constraints.maxWidth < 650;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryEmerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 14,
                        color: AppColors.primaryEmerald,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ADMINISTRATOR CONSOLE',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryEmerald,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Server Monitor',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            'Monitor Server & Log Terminal',
                            style: GoogleFonts.inter(
                              fontSize: isCompact ? 20 : 24,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _connectionState == 'connected'
                                  ? AppColors.primaryAccent.withValues(alpha: 0.15)
                                  : _connectionState == 'reconnecting'
                                      ? AppColors.warningAmber.withValues(alpha: 0.15)
                                      : AppColors.dangerRose.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _connectionState == 'connected'
                                    ? AppColors.primaryAccent.withValues(alpha: 0.3)
                                    : _connectionState == 'reconnecting'
                                        ? AppColors.warningAmber.withValues(alpha: 0.3)
                                        : AppColors.dangerRose.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                FadeTransition(
                                  opacity: _pulseAnimation,
                                  child: Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _connectionState == 'connected'
                                          ? const Color(0xFF22C55E)
                                          : _connectionState == 'reconnecting'
                                              ? AppColors.warningAmber
                                              : AppColors.dangerRose,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _connectionState == 'connected'
                                      ? 'LIVE'
                                      : _connectionState == 'reconnecting'
                                          ? 'RECONNECTING'
                                          : 'OFFLINE',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: _connectionState == 'connected'
                                        ? const Color(0xFF22C55E)
                                        : _connectionState == 'reconnecting'
                                            ? AppColors.warningAmber
                                            : AppColors.dangerRose,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pemantauan performa infrastruktur server NestJS, MQTT broker, dan stream terminal log waktu nyata.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isCompact) ...<Widget>[
                  OutlinedButton.icon(
                    onPressed: _sendManualTestLog,
                    icon: const Icon(Icons.bug_report_outlined, size: 16),
                    label: Text(
                      'Kirim Log Uji',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
                      side: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                      });
                      _fetchData();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      'Segarkan Metrik',
                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryEmerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  /// Builds the horizontal service status row with status pills.
  Widget _buildServiceStatusRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: isDark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isNarrow = constraints.maxWidth < 720;

          final List<Widget> items = <Widget>[
            _buildServiceStatusPill(
              title: 'NestJS API',
              status: 'Online',
              version: 'v${_metrics.appVersion} (Port 3001)',
              isOnline: true,
              isDark: isDark,
            ),
            _buildServiceStatusPill(
              title: 'MQTT Broker',
              status: _metrics.mqttStatus == 'up' ? 'Online' : 'Offline',
              version: 'EMQX (Port 1883)',
              isOnline: _metrics.mqttStatus == 'up',
              isDark: isDark,
            ),
            _buildServiceStatusPill(
              title: 'PostgreSQL',
              status: _metrics.dbStatus == 'up' ? 'Online' : 'Offline',
              version: 'v16.2',
              isOnline: _metrics.dbStatus == 'up',
              isDark: isDark,
            ),
            _buildServiceStatusPill(
              title: 'Server Uptime',
              status: _metrics.formattedUptime,
              version: 'Host: Gateway Bali',
              isOnline: true,
              iconOverride: Icons.access_time_rounded,
              isDark: isDark,
            ),
          ];

          if (isNarrow) {
            return Wrap(
              spacing: 16,
              runSpacing: 12,
              children: items,
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: items.map((w) => Expanded(child: w)).toList(),
          );
        },
      ),
    );
  }

  /// Builds a single service status pill widget.
  Widget _buildServiceStatusPill({
    required String title,
    required String status,
    required String version,
    required bool isOnline,
    required bool isDark,
    IconData? iconOverride,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: (isOnline ? AppColors.optimalGreen : AppColors.dangerRose)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: iconOverride != null
                ? Icon(
                    iconOverride,
                    size: 16,
                    color: AppColors.primaryEmerald,
                  )
                : Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? const Color(0xFF22C55E) : AppColors.dangerRose,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: (isOnline ? const Color(0xFF22C55E) : AppColors.dangerRose)
                              .withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              version,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the 4 system metrics cards (CPU, Memory, DB Connections, Data Rate).
  Widget _buildMetricsGrid(bool isDesktop, bool isDark) {
    final List<Widget> cards = <Widget>[
      _buildCpuMetricCard(isDark),
      _buildMemoryMetricCard(isDark),
      _buildDbConnectionsMetricCard(isDark),
      _buildDataRateMetricCard(isDark),
    ];

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cards
            .map((Widget card) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: card,
                  ),
                ))
            .toList(),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth > 550) {
          // 2x2 grid for tablet
          return Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(child: cards[2]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }

        // Single column for small mobile
        return Column(
          children: cards
              .map((Widget card) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: card,
                  ))
                  .toList(),
        );
      },
    );
  }

  /// Card 1: CPU Load with circular gauge indicator.
  Widget _buildCpuMetricCard(bool isDark) {
    Color statusColor = const Color(0xFF16A34A);

    return _buildMetricCardContainer(
      isDark: isDark,
      title: 'SPESIFIKASI CPU',
      icon: Icons.memory_rounded,
      iconColor: statusColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${_metrics.cpuCores} Cores',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_outline,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Beban Normal',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _metrics.cpuModel,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                CircularProgressIndicator(
                  value: 0.0,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  backgroundColor: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
                Icon(
                  Icons.developer_board_rounded,
                  size: 20,
                  color: statusColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Card 2: Memory Usage with linear progress bar.
  Widget _buildMemoryMetricCard(bool isDark) {
    final int usedMb = _metrics.memoryUsedMb;
    final int totalMb = _metrics.memoryTotalMb;
    final double memPercent = _metrics.memoryPercent;

    Color barColor = const Color(0xFF0284C7);
    if (memPercent > 80.0) {
      barColor = const Color(0xFFEF4444);
    } else if (memPercent > 65.0) {
      barColor = const Color(0xFFF59E0B);
    }

    return _buildMetricCardContainer(
      isDark: isDark,
      title: 'PENGGUNAAN MEMORI',
      icon: Icons.storage_rounded,
      iconColor: barColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                '${usedMb}MB',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                '/ ${totalMb}MB',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: memPercent / 100.0,
              minHeight: 8,
              backgroundColor: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Heap: ${memPercent.toStringAsFixed(1)}%',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: barColor,
                ),
              ),
              Text(
                'Tersedia: ${totalMb - usedMb} MB',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Card 3: DB Status.
  Widget _buildDbConnectionsMetricCard(bool isDark) {
    final bool isUp = _metrics.dbStatus == 'up';
    final Color statusColor = isUp ? const Color(0xFF8B5CF6) : AppColors.dangerRose;

    return _buildMetricCardContainer(
      isDark: isDark,
      title: 'STATUS KONEKSI DATABASE',
      icon: Icons.dns_rounded,
      iconColor: statusColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                isUp ? 'Sehat' : 'Terputus',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PostgreSQL',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(
                isUp ? Icons.check_circle_outline : Icons.error_outline,
                size: 14,
                color: statusColor,
              ),
              const SizedBox(width: 4),
              Text(
                isUp ? 'Terhubung dengan aman' : 'Menunggu pemulihan koneksi...',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Node: Gateway Bali (Primary)',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  /// Card 4: MQTT Status.
  Widget _buildDataRateMetricCard(bool isDark) {
    final bool isUp = _metrics.mqttStatus == 'up';
    final Color statusColor = isUp ? const Color(0xFF10B981) : AppColors.dangerRose;

    return _buildMetricCardContainer(
      isDark: isDark,
      title: 'STATUS BROKER MQTT',
      icon: Icons.hub_outlined,
      iconColor: statusColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                isUp ? 'Aktif' : 'Terputus',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              if (isUp)
                FadeTransition(
                  opacity: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: statusColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(
                isUp ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                size: 14,
                color: statusColor,
              ),
              const SizedBox(width: 4),
              Text(
                isUp ? 'Menerima Telemetri' : 'Menunggu broker hidup...',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Ingesti LoRaWAN + MQTT QoS 1',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  /// Base container helper for all metric cards.
  Widget _buildMetricCardContainer({
    required bool isDark,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: isDark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  /// Main Live Terminal Log Viewer Widget.
  Widget _buildTerminalLogViewer(bool isDark) {
    final List<ServerLogEntry> visibleLogs = _filteredLogs;
    final Map<ServerLogLevel, int> counts = _levelCounts;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.terminalBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.terminalBorder, width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          _buildTerminalHeaderBar(counts),
          _buildTerminalControlsBar(),
          _buildTerminalLogsBody(visibleLogs),
          _buildTerminalFooterBar(visibleLogs.length),
        ],
      ),
    );
  }

  /// Terminal Header Bar with macOS-style window controls, title, and stream status indicator.
  Widget _buildTerminalHeaderBar(Map<ServerLogLevel, int> counts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.terminalSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
        border: Border(
          bottom: BorderSide(color: AppColors.terminalBorder, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isCompact = constraints.maxWidth < 680;

          return Row(
            children: <Widget>[
              // Mac-style window action dots
              Row(
                children: <Widget>[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFF5F56),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFBD2E),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF27C93F),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Title with green live pulse
              Row(
                children: <Widget>[
                  FadeTransition(
                    opacity: _pulseAnimation,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.terminalGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Server Logs',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.terminalText,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (!isCompact) ...<Widget>[
                    const SizedBox(width: 8),
                    Text(
                      'nest-gateway-01 / journalctl -f',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        color: AppColors.terminalComment,
                      ),
                    ),
                  ],
                ],
              ),

              const Spacer(),

              // Stream paused indicator or live status pill
              if (_isStreamPaused)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.terminalYellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.terminalYellow.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.pause_circle_filled_rounded,
                        size: 13,
                        color: AppColors.terminalYellow,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'STREAM DIJEDA',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.terminalYellow,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Terminal Secondary Toolbar with Level Filter Dropdown, Search Field, Auto-scroll, and Actions.
  Widget _buildTerminalControlsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF11161D),
        border: Border(
          bottom: BorderSide(color: AppColors.terminalBorder, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isVeryNarrow = constraints.maxWidth < 640;

          if (isVeryNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _buildLogLevelDropdown(),
                    const SizedBox(width: 8),
                    Expanded(child: _buildSearchTextField()),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    _buildAutoScrollToggle(),
                    _buildTerminalActionButtons(),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: <Widget>[
              // Log level filter dropdown
              _buildLogLevelDropdown(),
              const SizedBox(width: 10),

              // Search text field
              Expanded(
                child: _buildSearchTextField(),
              ),
              const SizedBox(width: 12),

              // Auto scroll switch
              _buildAutoScrollToggle(),
              const SizedBox(width: 10),

              // Terminal action buttons (Pause, Copy, Clear)
              _buildTerminalActionButtons(),
            ],
          );
        },
      ),
    );
  }

  /// Log Level selector dropdown styled for dark terminal.
  Widget _buildLogLevelDropdown() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.terminalSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.terminalBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ServerLogLevel>(
          value: _selectedFilterLevel,
          dropdownColor: AppColors.terminalSurface,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.terminalComment,
          ),
          style: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.terminalText,
          ),
          onChanged: (ServerLogLevel? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedFilterLevel = newValue;
              });
            }
          },
          items: ServerLogLevel.values.map((ServerLogLevel level) {
            return DropdownMenuItem<ServerLogLevel>(
              value: level,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(level.icon, size: 14, color: level.color),
                  const SizedBox(width: 6),
                  Text(
                    level.label,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: level.color,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Search input field for filtering logs by keyword.
  Widget _buildSearchTextField() {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.terminalSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.terminalBorder),
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          color: AppColors.terminalText,
        ),
        cursorColor: AppColors.terminalPrompt,
        decoration: InputDecoration(
          hintText: 'Cari pesan, node, atau tag log...',
          hintStyle: GoogleFonts.jetBrainsMono(
            fontSize: 11.5,
            color: AppColors.terminalComment,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 16,
            color: AppColors.terminalComment,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.terminalComment,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: (String val) {
          setState(() {
            _searchQuery = val;
          });
        },
      ),
    );
  }

  /// Auto-scroll toggle switch.
  Widget _buildAutoScrollToggle() {
    return InkWell(
      onTap: () {
        setState(() {
          _isAutoScrollEnabled = !_isAutoScrollEnabled;
        });
        if (_isAutoScrollEnabled) {
          _scrollToBottom();
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _isAutoScrollEnabled
              ? AppColors.terminalGreen.withValues(alpha: 0.12)
              : AppColors.terminalSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: _isAutoScrollEnabled
                ? AppColors.terminalGreen.withValues(alpha: 0.4)
                : AppColors.terminalBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              _isAutoScrollEnabled
                  ? Icons.vertical_align_bottom_rounded
                  : Icons.pause_presentation_rounded,
              size: 14,
              color: _isAutoScrollEnabled
                  ? AppColors.terminalGreen
                  : AppColors.terminalComment,
            ),
            const SizedBox(width: 6),
            Text(
              'Auto-scroll',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _isAutoScrollEnabled
                    ? AppColors.terminalGreen
                    : AppColors.terminalComment,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isAutoScrollEnabled
                    ? AppColors.terminalGreen
                    : AppColors.terminalComment.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Terminal control buttons: Pause/Resume, Copy All, and Clear.
  Widget _buildTerminalActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Pause / Resume Toggle
        Tooltip(
          message: _isStreamPaused ? 'Lanjutkan Stream Log' : 'Jeda Stream Log',
          child: InkWell(
            onTap: () {
              setState(() {
                _isStreamPaused = !_isStreamPaused;
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _isStreamPaused
                    ? AppColors.terminalYellow.withValues(alpha: 0.15)
                    : AppColors.terminalSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _isStreamPaused
                      ? AppColors.terminalYellow.withValues(alpha: 0.4)
                      : AppColors.terminalBorder,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    _isStreamPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    size: 16,
                    color: _isStreamPaused
                        ? AppColors.terminalYellow
                        : AppColors.terminalText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isStreamPaused ? 'Lanjutkan' : 'Jeda',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _isStreamPaused
                          ? AppColors.terminalYellow
                          : AppColors.terminalText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Copy All Button
        Tooltip(
          message: 'Salin Semua Log Terlihat',
          child: InkWell(
            onTap: _copyFilteredLogsToClipboard,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.terminalSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.terminalBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: AppColors.terminalComment,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Salin',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.terminalComment,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),

        // Clear Button
        Tooltip(
          message: 'Bersihkan Layar Terminal',
          child: InkWell(
            onTap: _clearLogs,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.terminalSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.terminalBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.delete_sweep_outlined,
                    size: 15,
                    color: AppColors.terminalRed,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Bersihkan',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.terminalRed,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Terminal Log lines display area with monospace styling and color coded levels.
  Widget _buildTerminalLogsBody(List<ServerLogEntry> visibleLogs) {
    if (visibleLogs.isEmpty) {
      return Container(
        height: 380,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.search_off_rounded,
              size: 42,
              color: AppColors.terminalComment,
            ),
            const SizedBox(height: 12),
            Text(
              '> Tidak ada log yang cocok dengan filter aktif.',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                color: AppColors.terminalComment,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ubah kata kunci pencarian atau reset filter tingkat keparahan log.',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11.5,
                color: AppColors.terminalComment.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 440,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: RawScrollbar(
        controller: _terminalScrollController,
        thumbVisibility: true,
        thickness: 6,
        radius: const Radius.circular(3),
        thumbColor: AppColors.terminalBorder,
        child: ListView.builder(
          controller: _terminalScrollController,
          itemCount: visibleLogs.length,
          itemBuilder: (BuildContext context, int index) {
            final ServerLogEntry entry = visibleLogs[index];
            return _buildLogLineItem(entry, index + 1);
          },
        ),
      ),
    );
  }

  /// Builds a single terminal log line with line number, timestamp, level badge, and syntax highlighted body.
  Widget _buildLogLineItem(ServerLogEntry entry, int lineNumber) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: entry.formattedLine));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Log line disalin: ${entry.formattedLine}',
              style: GoogleFonts.jetBrainsMono(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: const Color(0xFF1F2937),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      },
      hoverColor: const Color(0xFF161B22),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Line Number
            SizedBox(
              width: 32,
              child: Text(
                lineNumber.toString().padLeft(3, '0'),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11.5,
                  color: const Color(0xFF484F58),
                  height: 1.4,
                ),
              ),
            ),

            // Timestamp
            Text(
              '[${entry.formattedTime}]',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                color: AppColors.terminalComment,
                height: 1.4,
              ),
            ),
            const SizedBox(width: 8),

            // Level Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: entry.level.bgHighlight,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                '[${entry.level.label}]',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: entry.level.color,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Message text
            Expanded(
              child: SelectableText.rich(
                _formatLogMessage(entry),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: AppColors.terminalText,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formats log message body with rich syntax styling for key values, endpoints, and JSON blocks.
  TextSpan _formatLogMessage(ServerLogEntry entry) {
    final String msg = entry.message;

    // Check if message contains JSON-like telemetry
    if (msg.contains('{') && msg.contains('}')) {
      final int start = msg.indexOf('{');
      final int end = msg.indexOf('}') + 1;
      final String prefix = msg.substring(0, start);
      final String jsonContent = msg.substring(start, end);
      final String suffix = msg.substring(end);

      return TextSpan(
        children: <TextSpan>[
          TextSpan(text: prefix),
          TextSpan(
            text: jsonContent,
            style: const TextStyle(
              color: Color(0xFF7EE787),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (suffix.isNotEmpty) TextSpan(text: suffix),
        ],
      );
    }

    // Colorize HTTP status codes
    if (entry.level == ServerLogLevel.http) {
      return TextSpan(
        children: <TextSpan>[
          TextSpan(
            text: msg,
            style: TextStyle(
              color: msg.contains('200') || msg.contains('201')
                  ? const Color(0xFF79C0FF)
                  : const Color(0xFFFFA657),
            ),
          ),
        ],
      );
    }

    return TextSpan(
      text: msg,
      style: TextStyle(
        color: entry.level == ServerLogLevel.error
            ? const Color(0xFFFF7B72)
            : (entry.level == ServerLogLevel.warn
                ? const Color(0xFFD29922)
                : AppColors.terminalText),
      ),
    );
  }

  /// Terminal Status Footer Bar with total counts, active filters, and cursor prompt.
  Widget _buildTerminalFooterBar(int visibleCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.terminalSurface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
        border: Border(
          top: BorderSide(color: AppColors.terminalBorder, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'agrimotion-core@edge-server:~#',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: AppColors.terminalPrompt,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              FadeTransition(
                opacity: _pulseAnimation,
                child: Container(
                  width: 6,
                  height: 12,
                  color: AppColors.terminalPrompt,
                ),
              ),
            ],
          ),
          Text(
            'Menampilkan $visibleCount dari ${_logs.length} entri log | Buffer: 400 maks',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: AppColors.terminalComment,
            ),
          ),
        ],
      ),
    );
  }
}
