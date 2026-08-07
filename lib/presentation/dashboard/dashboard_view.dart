import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/config/api_config.dart';
import '../../core/config/demplot_config.dart';
import '../../core/models/sensor_data.dart';
import '../../core/services/sensor_service.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView>
    with WidgetsBindingObserver {
  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  /// Telemetry data keyed by deviceId UUID.
  /// Populated from `GET /telemetry/latest` which returns all 4 nodes.
  Map<String, SensorData> _telemetryMap = {};

  bool _isLoading = true;
  String? _errorMessage;
  Timer? _pollingTimer;
  bool _isRetrying = false;

  /// Guard to prevent overlapping concurrent fetch calls.
  /// Without this, a slow network response + timer fire can stack
  /// multiple in-flight HTTP requests that race to setState.
  bool _isFetching = false;

  /// Consecutive fetch failure counter for exponential backoff.
  int _consecutiveFailures = 0;

  /// Whether the telemetry data is "stale" — server responded 200 but
  /// the newest timestamp is older than [ApiConfig.staleDataThreshold].
  /// This catches MQTT broker outages where ESP32 data stops flowing.
  bool _isDataStale = false;

  /// Currently selected Demplot index (0 = Demplot 1, 1 = Demplot 2, 2 = Demplot 3).
  int _selectedDemplotIndex = 0;

  /// For multi-node Demplots (e.g., Demplot 1 with node-1a & node-1b):
  /// index of the currently selected sub-node within that Demplot.
  int _selectedNodeIndex = 0;

  final SensorService _sensorService = SensorService();

  // ---------------------------------------------------------------------------
  // Lifecycle — AppLifecycleState Observer
  // ---------------------------------------------------------------------------
  //
  // WHY: On mobile, when the user locks the screen or switches to another
  // app, Android/iOS throttle or pause Timer.periodic. When the user comes
  // back, the timer may fire with the old stale data interval or skip
  // entirely. We MUST detect the resume and force-fetch immediately.
  //
  // HOW: WidgetsBindingObserver.didChangeAppLifecycleState fires:
  //   - `paused`   → user left the app (locked screen, switched apps)
  //   - `resumed`  → user came back (unlocked screen, switched back)
  //   - `inactive` → app is transitioning (e.g., phone call overlay)
  //   - `hidden`   → app is completely hidden (iOS multi-tasking)
  //
  // On `resumed`, we cancel the old timer (which may have drifted),
  // immediately force-fetch fresh data, and restart a clean timer.

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchAllTelemetry();
    _startPollingTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _sensorService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // User just unlocked phone / switched back to app.
      // Force-fetch immediately and restart a clean polling timer.
      _pollingTimer?.cancel();
      _fetchAllTelemetry();
      _startPollingTimer();
    } else if (state == AppLifecycleState.paused) {
      // App going to background — cancel timer to save battery.
      // It will be restarted on resume.
      _pollingTimer?.cancel();
    }
  }

  // ---------------------------------------------------------------------------
  // Polling Timer — with exponential backoff on repeated failures
  // ---------------------------------------------------------------------------

  /// Starts (or restarts) the periodic polling timer.
  ///
  /// The interval depends on the current failure state:
  /// - Normal:  [ApiConfig.pollingInterval] (10s)
  /// - Backoff: exponentially increasing from [reconnectBackoffBase] to
  ///            [reconnectBackoffMax] after [maxConsecutiveFailures] in a row.
  void _startPollingTimer() {
    _pollingTimer?.cancel();
    final interval = _computePollingInterval();
    _pollingTimer = Timer.periodic(interval, (_) {
      _fetchAllTelemetry();
    });
  }

  /// Computes the current polling interval based on consecutive failure count.
  Duration _computePollingInterval() {
    if (_consecutiveFailures < ApiConfig.maxConsecutiveFailures) {
      return ApiConfig.pollingInterval; // Normal: 10s
    }

    // Exponential backoff: base × 2^(failures - maxConsecutiveFailures)
    final backoffMultiplier =
        _consecutiveFailures - ApiConfig.maxConsecutiveFailures;
    final backoffMs = ApiConfig.reconnectBackoffBase.inMilliseconds *
        (1 << backoffMultiplier.clamp(0, 4)); // cap at 2^4 = 16×
    final cappedMs =
        backoffMs.clamp(0, ApiConfig.reconnectBackoffMax.inMilliseconds);
    return Duration(milliseconds: cappedMs);
  }

  // ---------------------------------------------------------------------------
  // Data Fetching — with concurrency guard, backoff, and staleness detection
  // ---------------------------------------------------------------------------

  /// Fetches telemetry for ALL nodes at once, then populates [_telemetryMap].
  ///
  /// Includes:
  /// - [_isFetching] guard against overlapping concurrent requests
  /// - Consecutive failure counter for exponential backoff
  /// - Staleness detection (server 200 but data timestamp too old)
  /// - Automatic backoff-to-normal recovery on first success
  Future<void> _fetchAllTelemetry() async {
    // Prevent overlapping requests (slow network + timer fire)
    if (_isFetching) return;
    _isFetching = true;

    try {
      final allData = await _sensorService.fetchAllLatestTelemetry();
      if (mounted) {
        final map = <String, SensorData>{};
        for (final item in allData) {
          if (item.deviceId != null) {
            map[item.deviceId!] = item;
          }
        }

        // Staleness detection: check if the newest data timestamp is too old.
        // This catches MQTT outages where the server responds 200 but ESP32
        // data hasn't actually been updated in a while.
        bool stale = false;
        if (map.isNotEmpty) {
          final newestTimestamp = map.values
              .map((s) => s.timestamp)
              .reduce((a, b) => a.isAfter(b) ? a : b);
          final age = DateTime.now().difference(newestTimestamp.toLocal());
          stale = age > ApiConfig.staleDataThreshold;
        }

        // SUCCESS — reset failure counter and restore normal polling if needed
        final wasInBackoff =
            _consecutiveFailures >= ApiConfig.maxConsecutiveFailures;
        setState(() {
          _telemetryMap = map;
          _isLoading = false;
          _errorMessage = null;
          _isRetrying = false;
          _isDataStale = stale;
          _consecutiveFailures = 0;
        });

        // If we were in backoff mode, restart timer at normal interval
        if (wasInBackoff) {
          _startPollingTimer();
        }
      }
    } catch (e) {
      if (mounted) {
        _consecutiveFailures++;

        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
          _isRetrying = false;
        });

        // If we just crossed the backoff threshold, restart timer with
        // longer interval to avoid hammering a dead server on mobile data.
        if (_consecutiveFailures == ApiConfig.maxConsecutiveFailures) {
          _startPollingTimer();
        }
      }
    } finally {
      _isFetching = false;
    }
  }

  void _retryConnection() {
    setState(() {
      _isRetrying = true;
      _errorMessage = null;
      _consecutiveFailures = 0; // Reset backoff on manual retry
    });
    _startPollingTimer(); // Restart at normal interval
    _fetchAllTelemetry();
  }


  // ---------------------------------------------------------------------------
  // Computed Getters
  // ---------------------------------------------------------------------------

  /// The currently selected Demplot configuration.
  Demplot get _currentDemplot =>
      DemplotConfig.demplots[_selectedDemplotIndex];

  /// The currently active device node within the selected Demplot.
  DeviceNode get _currentDevice =>
      _currentDemplot.devices[_selectedNodeIndex];

  /// The telemetry data for the currently active device node.
  SensorData? get _currentSensorData =>
      _telemetryMap[_currentDevice.deviceId];

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchAllTelemetry,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDemplotSelector(),
            const SizedBox(height: 16),
            _buildSystemStatus(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorBanner(),
            ],
            if (_isDataStale && _errorMessage == null) ...[
              const SizedBox(height: 16),
              _buildStaleBanner(),
            ],
            const SizedBox(height: 20),
            // Multi-node sub-selector for Demplot 1
            if (_currentDemplot.isMultiNode) ...[
              _buildNodeSubSelector(),
              const SizedBox(height: 16),
            ],
            _buildKpiCards(),
            const SizedBox(height: 20),
            _buildNpkSection(),
            const SizedBox(height: 20),
            _buildBottomArea(),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // DEMPLOT SELECTOR — Horizontal tab/chip bar for 3 Demplots
  // ============================================================================
  Widget _buildDemplotSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: List.generate(DemplotConfig.demplots.length, (index) {
              final demplot = DemplotConfig.demplots[index];
              final isSelected = _selectedDemplotIndex == index;

              // Count how many devices in this Demplot are ONLINE
              final onlineCount = demplot.devices.where((d) {
                final td = _telemetryMap[d.deviceId];
                return td != null && td.isDeviceOnline;
              }).length;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_selectedDemplotIndex != index) {
                      setState(() {
                        _selectedDemplotIndex = index;
                        _selectedNodeIndex = 0; // Reset sub-node selection
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          demplot.icon,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          demplot.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          demplot.commodity,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected
                                ? Colors.white.withAlpha(200)
                                : Colors.grey.shade500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!_isLoading) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withAlpha(40)
                                  : (onlineCount > 0
                                      ? Colors.green.withAlpha(20)
                                      : Colors.red.withAlpha(20)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$onlineCount/${demplot.devices.length} online',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white.withAlpha(220)
                                    : (onlineCount > 0
                                        ? Colors.green.shade700
                                        : Colors.red.shade600),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  // ============================================================================
  // NODE SUB-SELECTOR — Chip toggle for multi-node Demplots (e.g., Demplot 1)
  // ============================================================================
  Widget _buildNodeSubSelector() {
    final demplot = _currentDemplot;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sensors, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(
                'Pilih Node Sensor — ${demplot.name}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(demplot.devices.length, (index) {
              final device = demplot.devices[index];
              final isSelected = _selectedNodeIndex == index;
              final telemetry = _telemetryMap[device.deviceId];
              final isOnline =
                  telemetry != null && telemetry.isDeviceOnline;

              return GestureDetector(
                onTap: () {
                  if (_selectedNodeIndex != index) {
                    setState(() => _selectedNodeIndex = index);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Online/Offline dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOnline ? Colors.greenAccent : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${device.label} (${device.deviceCode})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // SYSTEM STATUS HEADER — Connection info + Node status badge
  // ============================================================================
  Widget _buildSystemStatus() {
    final data = _currentSensorData;
    final bool hasData = data != null;
    final bool isNodeOnline = hasData && data.isDeviceOnline;
    final bool isConnecting = _isLoading || _isRetrying;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          final statusHeader = Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: '${_currentDemplot.icon} ${_currentDemplot.name}: ',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                        children: [
                          TextSpan(
                            text: _errorMessage != null
                                ? 'Terputus'
                                : (isConnecting
                                    ? 'Menghubungkan...'
                                    : (isNodeOnline
                                        ? 'Optimal'
                                        : 'Device Offline')),
                            style: TextStyle(
                              color: _errorMessage != null
                                  ? Colors.red
                                  : (isConnecting
                                      ? Colors.orange
                                      : (isNodeOnline
                                          ? AppTheme.primaryColor
                                          : Colors.red)),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _errorMessage != null
                          ? 'Tidak dapat terhubung ke backend server.'
                          : (isConnecting
                              ? 'Menghubungkan ke ${ApiConfig.baseUrl}...'
                              : 'Komoditas: ${_currentDemplot.commodity} · ${_currentDevice.label} (${_currentDevice.deviceCode})'),
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(
                isNodeOnline
                    ? 'ONLINE'
                    : (isConnecting ? 'MENUNGGU' : 'OFFLINE'),
                isNodeOnline
                    ? Colors.green
                    : (isConnecting ? Colors.orange : Colors.red),
              ),
            ],
          );

          final syncInfo = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time,
                    size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    data != null
                        ? '${data.timeAgo} (${data.formattedTimestamp})'
                        : (isConnecting ? '...' : 'N/A'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );

          final lastOnlineInfo = data?.lastOnline != null
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi, size: 13, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Terakhir online: ${data!.lastOnlineAgo}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              statusHeader,
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    syncInfo,
                    const SizedBox(height: 8),
                    lastOnlineInfo,
                  ],
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    syncInfo,
                    lastOnlineInfo,
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 8),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // STALE DATA BANNER — Server 200 but sensor data not updating
  // ============================================================================
  Widget _buildStaleBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.amber.shade800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Sensor Tidak Terupdate',
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Server merespons normal, tapi data terakhir sudah lebih dari '
                  '${ApiConfig.staleDataThreshold.inMinutes} menit yang lalu. '
                  'Kemungkinan sensor ESP32 tidak mengirim data melalui MQTT '
                  'atau koneksi broker MQTT terputus.',
                  style: TextStyle(
                    color: Colors.amber.shade800,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // ERROR BANNER — No mock data, retry button
  // ============================================================================
  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Koneksi ke Server Gagal',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _errorMessage ?? 'Terjadi kesalahan.',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: _isRetrying ? null : _retryConnection,
                  icon: _isRetrying
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(_isRetrying ? 'Menghubungkan...' : 'Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (_consecutiveFailures >= ApiConfig.maxConsecutiveFailures) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Percobaan ulang ke-$_consecutiveFailures · '
                    'interval: ${_computePollingInterval().inSeconds}s',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // KPI CARDS — Sensor metrics with null safety
  // ============================================================================
  Widget _buildKpiCards() {
    final data = _currentSensorData;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width <= 0) return const SizedBox.shrink();

        int crossAxisCount;
        if (width > 1000) {
          crossAxisCount = 4;
        } else if (width > 600) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 2;
        }

        final spacing = 12.0;
        final cardWidth =
            ((width - (spacing * (crossAxisCount - 1))) / crossAxisCount)
                .clamp(0.0, double.infinity);

        if (cardWidth <= 0) return const SizedBox.shrink();

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _kpiCard(
              cardWidth,
              'INTENSITAS CAHAYA',
              data != null
                  ? SensorData.formatValue(data.lux, decimals: 0)
                  : null,
              'Lux',
              Icons.light_mode_outlined,
              const Color(0xFFF59E0B),
            ),
            _kpiCard(
              cardWidth,
              'SUHU UDARA',
              data != null
                  ? SensorData.formatValue(data.temperature)
                  : null,
              '°C',
              Icons.thermostat_outlined,
              Colors.red,
            ),
            _kpiCard(
              cardWidth,
              'KELEMBABAN UDARA',
              data != null
                  ? SensorData.formatValue(data.humidity)
                  : null,
              '%',
              Icons.water_drop_outlined,
              Colors.blue,
            ),
            _kpiCard(
              cardWidth,
              'KELEMBABAN TANAH',
              data != null
                  ? SensorData.formatValue(data.soilMoisture)
                  : null,
              '%',
              Icons.grass_outlined,
              AppTheme.primaryColor,
            ),
          ],
        );
      },
    );
  }

  Widget _kpiCard(
    double width,
    String title,
    String? value,
    String unit,
    IconData icon,
    Color accentColor,
  ) {
    if (width <= 0) return const SizedBox.shrink();

    final bool isNa = value == 'N/A';

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          value == null
              ? _shimmerPlaceholder()
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isNa ? Colors.grey.shade400 : Colors.black87,
                        ),
                      ),
                      if (!isNa) ...[
                        const SizedBox(width: 4),
                        Text(
                          unit,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
          const SizedBox(height: 8),
          Text(
            _currentSensorData != null
                ? _currentSensorData!.timeAgo
                : 'Menunggu data...',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _shimmerPlaceholder() {
    return Container(
      height: 32,
      width: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  // ============================================================================
  // NPK & pH SECTION — Additional sensor metrics with null safety
  // ============================================================================
  Widget _buildNpkSection() {
    final data = _currentSensorData;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width <= 0) return const SizedBox.shrink();

        final isWide = width > 600;
        final spacing = 12.0;

        if (isWide) {
          final cardW =
              ((width - spacing * 3) / 4).clamp(0.0, double.infinity);
          if (cardW <= 0) return const SizedBox.shrink();

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              _miniMetricCard(
                  cardW,
                  'pH TANAH',
                  data != null
                      ? SensorData.formatValue(data.ph)
                      : null,
                  Icons.science_outlined,
                  Colors.purple),
              _miniMetricCard(
                  cardW,
                  'NITROGEN (N)',
                  data != null
                      ? _formatNpkValue(data.npkN)
                      : null,
                  Icons.eco_outlined,
                  const Color(0xFF059669)),
              _miniMetricCard(
                  cardW,
                  'FOSFOR (P)',
                  data != null
                      ? _formatNpkValue(data.npkP)
                      : null,
                  Icons.eco_outlined,
                  Colors.blue),
              _miniMetricCard(
                  cardW,
                  'KALIUM (K)',
                  data != null
                      ? _formatNpkValue(data.npkK)
                      : null,
                  Icons.eco_outlined,
                  Colors.orange),
            ],
          );
        } else {
          final cardW =
              ((width - spacing) / 2).clamp(0.0, double.infinity);
          if (cardW <= 0) return const SizedBox.shrink();

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              _miniMetricCard(
                  cardW,
                  'pH TANAH',
                  data != null
                      ? SensorData.formatValue(data.ph)
                      : null,
                  Icons.science_outlined,
                  Colors.purple),
              _miniMetricCard(
                  cardW,
                  'NITROGEN (N)',
                  data != null
                      ? _formatNpkValue(data.npkN)
                      : null,
                  Icons.eco_outlined,
                  const Color(0xFF059669)),
              _miniMetricCard(
                  cardW,
                  'FOSFOR (P)',
                  data != null
                      ? _formatNpkValue(data.npkP)
                      : null,
                  Icons.eco_outlined,
                  Colors.blue),
              _miniMetricCard(
                  cardW,
                  'KALIUM (K)',
                  data != null
                      ? _formatNpkValue(data.npkK)
                      : null,
                  Icons.eco_outlined,
                  Colors.orange),
            ],
          );
        }
      },
    );
  }

  /// Formats an NPK value with "mg/kg" unit, or returns "N/A" if null.
  String _formatNpkValue(double? value) {
    if (value == null) return 'N/A';
    return '${value.toStringAsFixed(0)} mg/kg';
  }

  Widget _miniMetricCard(
      double width, String title, String? value, IconData icon, Color color) {
    if (width <= 0) return const SizedBox.shrink();

    final bool isNa = value == 'N/A';

    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          value == null
              ? _shimmerPlaceholder()
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isNa ? Colors.grey.shade400 : Colors.black87,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ============================================================================
  // BOTTOM AREA — Charts & Device Info
  // ============================================================================
  Widget _buildBottomArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildBarChartCard()),
              const SizedBox(width: 20),
              Expanded(flex: 1, child: _buildDeviceInfoCard()),
            ],
          );
        } else {
          return Column(
            children: [
              _buildBarChartCard(),
              const SizedBox(height: 20),
              _buildDeviceInfoCard(),
            ],
          );
        }
      },
    );
  }

  Widget _buildBarChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tren Kelembaban Tanah',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Data historis 7 hari terakhir',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 180,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _barItem('Sen', 100, constraints.maxWidth),
                    _barItem('Sel', 90, constraints.maxWidth),
                    _barItem('Rab', 80, constraints.maxWidth),
                    _barItem('Kam', 160, constraints.maxWidth),
                    _barItem('Jum', 140, constraints.maxWidth),
                    _barItem('Sab', 120, constraints.maxWidth),
                    _barItem('Min', 110, constraints.maxWidth),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _barItem(String day, double height, double containerWidth) {
    final barWidth = (containerWidth / 10).clamp(12.0, 32.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: barWidth,
          height: height,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceInfoCard() {
    final data = _currentSensorData;
    final device = _currentDevice;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Info Perangkat Aktif',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (data != null)
                _statusBadge(
                  data.isDeviceOnline ? 'ONLINE' : 'OFFLINE',
                  data.isDeviceOnline ? Colors.green : Colors.red,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _deviceInfoRow(
            Icons.label_outlined,
            'Kode Device',
            device.deviceCode,
          ),
          const SizedBox(height: 12),
          _deviceInfoRow(
            Icons.router_outlined,
            'ID Device',
            device.deviceId,
          ),
          const SizedBox(height: 12),
          _deviceInfoRow(
            Icons.landscape_outlined,
            'Demplot / Farm',
            '${_currentDemplot.name} (${_currentDemplot.commodity})',
          ),
          const SizedBox(height: 12),
          _deviceInfoRow(
            Icons.wifi,
            'Status Node',
            data?.deviceStatus ?? 'N/A',
          ),
          const SizedBox(height: 12),
          _deviceInfoRow(
            Icons.battery_charging_full,
            'Baterai',
            data?.battery != null
                ? '${data!.battery!.toStringAsFixed(0)}%'
                : 'N/A',
          ),
          const SizedBox(height: 12),
          _deviceInfoRow(
            Icons.signal_cellular_alt,
            'RSSI Signal',
            data?.signal != null ? '${data!.signal} dBm' : 'N/A',
          ),
          const SizedBox(height: 12),
          _deviceInfoRow(
            Icons.access_time,
            'Terakhir Online',
            data?.lastOnlineAgo ?? 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _deviceInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
