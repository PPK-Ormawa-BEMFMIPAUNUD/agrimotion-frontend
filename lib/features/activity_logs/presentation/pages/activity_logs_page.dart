import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agrimotion/core/theme/colors.dart';
import 'package:agrimotion/core/services/activity_log_service.dart';
import 'package:agrimotion/features/activity_logs/domain/activity_log_models.dart';
import 'package:agrimotion/core/services/cache_service.dart';

class ActivityLogsPage extends ConsumerStatefulWidget {
  const ActivityLogsPage({super.key});

  @override
  ConsumerState<ActivityLogsPage> createState() => _ActivityLogsPageState();
}

class _ActivityLogsPageState extends ConsumerState<ActivityLogsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // SWR State for Login Logs
  List<UserLoginLog> _loginLogs = [];
  bool _isLoadingLoginLogs = true;
  String? _loginLogsError;

  // SWR State for Watering Logs
  List<WateringLog> _wateringLogs = [];
  bool _isLoadingWateringLogs = true;
  String? _wateringLogsError;

  // Filters for Login Tab
  final TextEditingController _loginSearchController = TextEditingController();
  String _loginSearchQuery = '';

  // Filters for Watering Tab
  final TextEditingController _wateringSearchController = TextEditingController();
  String _wateringSearchQuery = '';
  String _selectedActuationType = 'ALL'; // ALL, WATER, FERTILIZER, PESTICIDE
  String _selectedMethod = 'ALL'; // ALL, AUTO, MANUAL

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loginSearchController.addListener(() {
      setState(() {
        _loginSearchQuery = _loginSearchController.text.toLowerCase();
      });
    });
    _wateringSearchController.addListener(() {
      setState(() {
        _wateringSearchQuery = _wateringSearchController.text.toLowerCase();
      });
    });

    Future.wait([
      _fetchLoginLogs(),
      _fetchWateringLogs(),
    ]);
  }

  Future<void> _fetchLoginLogs() async {
    final cacheService = ref.read(cacheServiceProvider);
    final cached = cacheService.getCacheData('login_logs');
    if (cached != null && cached is List) {
      if (mounted) {
        setState(() {
          _loginLogs = cached
              .whereType<Map>()
              .map((e) => UserLoginLog.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _isLoadingLoginLogs = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingLoginLogs = true;
          _loginLogsError = null;
        });
      }
    }

    try {
      final logs = await ref.read(activityLogServiceProvider).fetchLoginLogs();
      final jsonList = logs.map((e) => e.toJson()).toList();
      await cacheService.setCacheData('login_logs', jsonList);

      if (mounted) {
        setState(() {
          _loginLogs = logs;
          _isLoadingLoginLogs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_loginLogs.isEmpty) {
            _loginLogsError = e.toString();
          }
          _isLoadingLoginLogs = false;
        });
      }
    }
  }

  Future<void> _fetchWateringLogs() async {
    final cacheService = ref.read(cacheServiceProvider);
    final cached = cacheService.getCacheData('watering_logs');
    if (cached != null && cached is List) {
      if (mounted) {
        setState(() {
          _wateringLogs = cached
              .whereType<Map>()
              .map((e) => WateringLog.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _isLoadingWateringLogs = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingWateringLogs = true;
          _wateringLogsError = null;
        });
      }
    }

    try {
      final logs = await ref.read(activityLogServiceProvider).fetchWateringLogs();
      final jsonList = logs.map((e) => e.toJson()).toList();
      await cacheService.setCacheData('watering_logs', jsonList);

      if (mounted) {
        setState(() {
          _wateringLogs = logs;
          _isLoadingWateringLogs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_wateringLogs.isEmpty) {
            _wateringLogsError = e.toString();
          }
          _isLoadingWateringLogs = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginSearchController.dispose();
    _wateringSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isDark),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryEmerald,
              unselectedLabelColor: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
              indicatorColor: AppColors.primaryEmerald,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Log Login Kader'),
                Tab(text: 'Log Penyiraman & Aktuasi'),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginLogsTab(isDark),
                  _buildWateringLogsTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Log Aktivitas Sistem',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Riwayat akses pengguna dan kontrol lahan',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
                    ),
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Future.wait([
                    _fetchLoginLogs(),
                    _fetchWateringLogs(),
                  ]);
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Segarkan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
                  side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginLogsTab(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: TextField(
            controller: _loginSearchController,
            decoration: InputDecoration(
              hintText: 'Cari nama kader atau email...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
              ),
            ),
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              if (_isLoadingLoginLogs && _loginLogs.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryEmerald));
              }

              if (_loginLogsError != null && _loginLogs.isEmpty) {
                return _buildErrorState(_loginLogsError!, _fetchLoginLogs, isDark);
              }

              final filteredLogs = _loginLogs.where((log) {
                final nameMatch = log.name?.toLowerCase().contains(_loginSearchQuery) ?? false;
                final emailMatch = log.email?.toLowerCase().contains(_loginSearchQuery) ?? false;
                return nameMatch || emailMatch;
              }).toList();

              if (filteredLogs.isEmpty) {
                return _buildEmptyState(isDark);
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 800) {
                    return _buildLoginDataTable(filteredLogs, isDark);
                  } else {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, index) {
                        return _buildLoginCard(filteredLogs[index], isDark);
                      },
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWateringLogsTab(bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _wateringSearchController,
                  decoration: InputDecoration(
                    hintText: 'Cari demplot atau operator...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedActuationType,
                      isExpanded: true,
                      dropdownColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('Semua Aktuasi')),
                        DropdownMenuItem(value: 'WATER', child: Text('Air')),
                        DropdownMenuItem(value: 'FERTILIZER', child: Text('Pupuk NPK')),
                        DropdownMenuItem(value: 'PESTICIDE', child: Text('Pestisida')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedActuationType = val!;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMethod,
                      isExpanded: true,
                      dropdownColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('Semua Metode')),
                        DropdownMenuItem(value: 'AUTO', child: Text('Otomatis (Sistem)')),
                        DropdownMenuItem(value: 'MANUAL', child: Text('Manual (Kader)')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedMethod = val!;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              if (_isLoadingWateringLogs && _wateringLogs.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryEmerald));
              }

              if (_wateringLogsError != null && _wateringLogs.isEmpty) {
                return _buildErrorState(_wateringLogsError!, _fetchWateringLogs, isDark);
              }

              final filteredLogs = _wateringLogs.where((log) {
                // Text search
                final searchMatch = (log.deviceCode?.toLowerCase().contains(_wateringSearchQuery) ?? false) ||
                                    (log.farmName?.toLowerCase().contains(_wateringSearchQuery) ?? false) ||
                                    (log.operatorDisplayName.toLowerCase().contains(_wateringSearchQuery));
                
                // Type filter
                final typeMatch = _selectedActuationType == 'ALL' || log.type == _selectedActuationType || log.actuationType == _selectedActuationType;
                
                // Method filter
                bool methodMatch = true;
                if (_selectedMethod == 'AUTO') {
                  methodMatch = log.isAutomatic;
                } else if (_selectedMethod == 'MANUAL') {
                  methodMatch = !log.isAutomatic;
                }

                return searchMatch && typeMatch && methodMatch;
              }).toList();

              if (filteredLogs.isEmpty) {
                return _buildEmptyState(isDark);
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 800) {
                    return _buildWateringDataTable(filteredLogs, isDark);
                  } else {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: filteredLogs.length,
                      itemBuilder: (context, index) {
                        return _buildWateringCard(filteredLogs[index], isDark);
                      },
                    );
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Login Table & Card ---

  Widget _buildLoginDataTable(List<UserLoginLog> logs, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
        child: DataTable(
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
          ),
          columns: const [
            DataColumn(label: Text('No')),
            DataColumn(label: Text('Nama Kader')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Peran')),
            DataColumn(label: Text('Waktu Login')),
            DataColumn(label: Text('IP / Perangkat')),
          ],
          rows: List.generate(logs.length, (index) {
            final log = logs[index];
            return DataRow(cells: [
              DataCell(Text('${index + 1}')),
              DataCell(Text(log.name ?? '-')),
              DataCell(Text(log.email ?? '-')),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: log.roleBadgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: log.roleBadgeColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    log.role ?? 'USER',
                    style: TextStyle(color: log.roleBadgeColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              DataCell(Text(log.formattedLoginTime)),
              DataCell(Text(log.ipAddress ?? '-')),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _buildLoginCard(UserLoginLog log, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  log.name ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: log.roleBadgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log.role ?? 'USER',
                  style: TextStyle(color: log.roleBadgeColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(log.email ?? '-', style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 16, color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(log.formattedLoginTime),
            ],
          ),
        ],
      ),
    );
  }

  // --- Watering Table & Card ---

  Widget _buildWateringDataTable(List<WateringLog> logs, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
        child: DataTable(
          headingTextStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
          ),
          columns: const [
            DataColumn(label: Text('No')),
            DataColumn(label: Text('Alat / Lahan')),
            DataColumn(label: Text('Aktuasi')),
            DataColumn(label: Text('Metode')),
            DataColumn(label: Text('Operator')),
            DataColumn(label: Text('Durasi')),
            DataColumn(label: Text('Waktu')),
          ],
          rows: List.generate(logs.length, (index) {
            final log = logs[index];
            final displayLocation = log.farmName ?? log.deviceCode ?? 'Demplot Irigasi';

            return DataRow(cells: [
              DataCell(Text('${index + 1}')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sensors_rounded,
                      size: 16,
                      color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(displayLocation),
                  ],
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: log.actuationTypeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: log.actuationTypeColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(log.actuationTypeIcon, size: 14, color: log.actuationTypeColor),
                      const SizedBox(width: 6),
                      Text(
                        log.actuationTypeLabel,
                        style: TextStyle(
                          color: log.actuationTypeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: log.isAutomatic 
                        ? AppColors.primaryEmerald.withValues(alpha: 0.1) 
                        : AppColors.infoBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        log.isAutomatic ? Icons.smart_toy_outlined : Icons.person_outline_rounded,
                        size: 14,
                        color: log.isAutomatic ? AppColors.primaryEmerald : AppColors.infoBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        log.isAutomatic ? 'OTOMATIS' : 'MANUAL',
                        style: TextStyle(
                          color: log.isAutomatic ? AppColors.primaryEmerald : AppColors.infoBlue,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              DataCell(Text(log.operatorDisplayName)),
              DataCell(Text(log.formattedDuration)),
              DataCell(Text(log.formattedTimestamp)),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _buildWateringCard(WateringLog log, bool isDark) {
    final displayLocation = log.farmName ?? log.deviceCode ?? 'Demplot Irigasi';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sensors_rounded,
                    size: 18,
                    color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    displayLocation,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: log.actuationTypeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: log.actuationTypeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(log.actuationTypeIcon, size: 14, color: log.actuationTypeColor),
                    const SizedBox(width: 4),
                    Text(
                      log.actuationTypeLabel,
                      style: TextStyle(color: log.actuationTypeColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                log.isAutomatic ? Icons.smart_toy_outlined : Icons.person_outline_rounded,
                size: 16,
                color: log.isAutomatic ? AppColors.primaryEmerald : AppColors.infoBlue,
              ),
              const SizedBox(width: 8),
              Text(
                log.isAutomatic ? 'Otomatis (${log.operatorDisplayName})' : 'Manual (${log.operatorDisplayName})',
                style: TextStyle(color: log.isAutomatic ? AppColors.primaryEmerald : AppColors.infoBlue, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(log.formattedDuration),
                ],
              ),
              Text(log.formattedTimestamp, style: TextStyle(fontSize: 12, color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  // --- States ---

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 56,
            color: isDark ? AppColors.textDarkSecondary.withValues(alpha: 0.5) : AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Belum ada log aktivitas tercatat',
            style: TextStyle(
              color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Riwayat aktivitas pengguna dan aktuasi perangkat akan tampil di sini.',
            style: TextStyle(
              color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.dangerRose),
          const SizedBox(height: 16),
          Text(
            'Gagal memuat log aktivitas',
            style: TextStyle(color: isDark ? AppColors.textDarkPrimary : AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: isDark ? AppColors.textDarkSecondary : AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryEmerald),
          ),
        ],
      ),
    );
  }
}
