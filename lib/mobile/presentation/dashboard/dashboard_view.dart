import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/demplot_config.dart';
import '../../../core/models/sensor_data.dart';
import '../../../core/services/sensor_service.dart';
import '../../../core/services/mqtt_service.dart';
import '../../../core/utils/pump_command.dart';

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

  /// Subscription to ESP32 MQTT status messages.
  StreamSubscription<String>? _mqttStatusSubscription;

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
    _listenMqttStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _mqttStatusSubscription?.cancel();
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
  Demplot get _currentDemplot => DemplotConfig.demplots[_selectedDemplotIndex];

  /// The currently active device node within the selected Demplot.
  DeviceNode get _currentDevice => _currentDemplot.devices[_selectedNodeIndex];

  /// The telemetry data for the currently active device node.
  SensorData? get _currentSensorData => _telemetryMap[_currentDevice.deviceId];

  // ---------------------------------------------------------------------------
  // Spraying Control State (Pupuk Cair, Pestisida & Air)
  // ---------------------------------------------------------------------------
  bool _isSprayingFertilizer = false;
  bool _isSprayingPesticide = false;
  bool _isSprayingWater = false;
  int _fertilizerDuration = 10; // default in seconds
  int _pesticideDuration = 10; // default in seconds
  int _waterDuration = 10; // default in seconds
  int _sprayRemainingSeconds = 0;
  Timer? _sprayCountdownTimer;
  String? _activeSprayingType;

  final List<Map<String, String>> _sprayLogs = [
    {
      "type": "Pupuk Cair",
      "demplot": "Demplot 1 (Bunga Pacah)",
      "duration": "10s",
      "time": "Tadi pagi 08:30",
      "status": "Selesai"
    },
    {
      "type": "Pestisida",
      "demplot": "Demplot 2 (Sawi)",
      "duration": "5s",
      "time": "Kemarin 16:45",
      "status": "Selesai"
    }
  ];

  void _startSpraying({required String type, required int durationSeconds}) {
    if (_isSprayingFertilizer || _isSprayingPesticide || _isSprayingWater) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Penyemprotan lain sedang aktif! Harap tunggu atau hentikan dahulu.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ── MQTT: Publish ON command to ESP32 ──
    final mqttType = type == 'Pupuk Cair'
        ? 'PUPUK'
        : type == 'Siram Air'
            ? 'AIR'
            : 'PESTI';
    final onCommand = PumpCommand.build(
      demplotIndex: _selectedDemplotIndex,
      type: mqttType,
      turnOn: true,
    );
    final published = MqttService.instance.publishCommand(onCommand);

    if (!published) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'MQTT belum terhubung. Perintah tidak dikirim ke ESP32.')),
            ],
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
      // Still allow local UI to proceed — user can see the timer
    }

    setState(() {
      _activeSprayingType = type;
      _sprayRemainingSeconds = durationSeconds;
      if (type == 'Pupuk Cair') {
        _isSprayingFertilizer = true;
      } else if (type == 'Siram Air') {
        _isSprayingWater = true;
      } else {
        _isSprayingPesticide = true;
      }
    });

    _sprayCountdownTimer?.cancel();
    _sprayCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_sprayRemainingSeconds <= 1) {
        timer.cancel();

        // ── MQTT: Publish OFF command when timer completes ──
        final offCommand = PumpCommand.build(
          demplotIndex: _selectedDemplotIndex,
          type: mqttType,
          turnOn: false,
        );
        MqttService.instance.publishCommand(offCommand);

        setState(() {
          _isSprayingFertilizer = false;
          _isSprayingPesticide = false;
          _isSprayingWater = false;
          _activeSprayingType = null;
          _sprayRemainingSeconds = 0;
          _sprayLogs.insert(0, {
            "type": type,
            "demplot": '${_currentDemplot.name} (${_currentDemplot.commodity})',
            "duration": type == 'Siram Air'
                ? '${durationSeconds ~/ 60}m'
                : '${durationSeconds}s',
            "time": "Baru saja",
            "status": "Selesai"
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                    'Penyemprotan $type selesai pada ${_currentDemplot.name}!'),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      } else {
        setState(() {
          _sprayRemainingSeconds--;
        });
      }
    });
  }

  void _stopSpraying() {
    _sprayCountdownTimer?.cancel();
    final stoppedType = _activeSprayingType ?? 'Penyemprotan';

    // ── MQTT: Publish OFF command for the active spray type ──
    if (_activeSprayingType != null) {
      final mqttType = _activeSprayingType == 'Pupuk Cair'
          ? 'PUPUK'
          : _activeSprayingType == 'Siram Air'
              ? 'AIR'
              : 'PESTI';
      final offCommand = PumpCommand.build(
        demplotIndex: _selectedDemplotIndex,
        type: mqttType,
        turnOn: false,
      );
      MqttService.instance.publishCommand(offCommand);
    }

    setState(() {
      _isSprayingFertilizer = false;
      _isSprayingPesticide = false;
      _isSprayingWater = false;
      _activeSprayingType = null;
      _sprayRemainingSeconds = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$stoppedType dihentikan secara manual.'),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MQTT Status Listener — feedback from ESP32
  // ---------------------------------------------------------------------------

  /// Listens to `agrimotion/device/pumps/status` for real-time feedback from ESP32.
  /// Displays a themed SnackBar when a status message is received.
  void _listenMqttStatus() {
    _mqttStatusSubscription =
        MqttService.instance.onStatusReceived.listen((status) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 4),
          content: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.memory,
                    color: Color(0xFF4ADE80),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Feedback ESP32',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
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
    });
  }

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
            // Multi-node sub-selector for Demplot 2
            if (_currentDemplot.isMultiNode) ...[
              _buildNodeSubSelector(),
              const SizedBox(height: 16),
            ],
            _buildKpiCards(),
            const SizedBox(height: 20),
            _buildNpkSection(),
            const SizedBox(height: 20),
            _buildSprayControlSection(),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.softShadow,
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
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected ? AppTheme.primaryGradient : null,
                      color: isSelected ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.2)
                                : const Color(0xFFF1F5F9),
                          ),
                          child: Center(
                            child: Text(
                              demplot.icon,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          demplot.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          demplot.commodity,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.9)
                                : const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!_isLoading) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.22)
                                  : (onlineCount > 0
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFFEE2E2)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? Colors.white
                                        : (onlineCount > 0
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFFDC2626)),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$onlineCount/${demplot.devices.length} Online',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : (onlineCount > 0
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFFB91C1C)),
                                  ),
                                ),
                              ],
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
  // NODE SUB-SELECTOR — Chip toggle for multi-node Demplots (e.g., Demplot 2)
  // ============================================================================
  Widget _buildNodeSubSelector() {
    final demplot = _currentDemplot;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.hub_outlined,
                    size: 16, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 8),
              Text(
                'Pilih Node Sensor — ${demplot.name}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${demplot.devices.length} Node',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(demplot.devices.length, (index) {
              final device = demplot.devices[index];
              final isSelected = _selectedNodeIndex == index;
              final telemetry = _telemetryMap[device.deviceId];
              final isOnline = telemetry != null && telemetry.isDeviceOnline;

              Color dotColor;
              if (!device.isInstalled) {
                dotColor = const Color(0xFF94A3B8);
              } else if (isOnline) {
                dotColor = const Color(0xFF22C55E);
              } else {
                dotColor = const Color(0xFFEF4444);
              }

              return GestureDetector(
                onTap: () {
                  if (_selectedNodeIndex != index) {
                    setState(() => _selectedNodeIndex = index);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : const Color(0xFFCBD5E1),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected && isOnline
                              ? const Color(0xFF86EFAC)
                              : dotColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        device.isInstalled
                            ? '${device.label} (${device.deviceCode})'
                            : '${device.label} (Belum Terpasang)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF334155),
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
    final bool isInstalled = _currentDevice.isInstalled;

    String statusText;
    Color statusTextColor;
    String badgeLabel;
    Color badgeColor;

    if (!isInstalled) {
      statusText = 'Belum Terpasang';
      statusTextColor = const Color(0xFF64748B);
      badgeLabel = 'BELUM TERPASANG';
      badgeColor = const Color(0xFF64748B);
    } else if (_errorMessage != null) {
      statusText = 'Terputus';
      statusTextColor = const Color(0xFFDC2626);
      badgeLabel = 'TERPUTUS';
      badgeColor = const Color(0xFFDC2626);
    } else if (isConnecting) {
      statusText = 'Menghubungkan...';
      statusTextColor = const Color(0xFFD97706);
      badgeLabel = 'MENUNGGU';
      badgeColor = const Color(0xFFD97706);
    } else if (isNodeOnline) {
      statusText = 'Optimal';
      statusTextColor = AppTheme.primaryColor;
      badgeLabel = 'ONLINE';
      badgeColor = const Color(0xFF16A34A);
    } else {
      statusText = 'Perangkat Offline';
      statusTextColor = const Color(0xFFDC2626);
      badgeLabel = 'OFFLINE';
      badgeColor = const Color(0xFFDC2626);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.softShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          final statusHeader = LayoutBuilder(
            builder: (context, headerConstraints) {
              final isVeryNarrow = headerConstraints.maxWidth < 360;

              if (isVeryNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_currentDemplot.icon} ${_currentDemplot.name}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _statusBadge(badgeLabel, badgeColor),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusTextColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusTextColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      !isInstalled
                          ? 'Perangkat ini belum terpasang di lapangan.'
                          : (_errorMessage != null
                              ? 'Tidak dapat terhubung ke server backend.'
                              : (isConnecting
                                  ? 'Menghubungkan ke server...'
                                  : 'Komoditas: ${_currentDemplot.commodity} · ${_currentDevice.label}')),
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              '${_currentDemplot.icon} ${_currentDemplot.name}',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusTextColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  color: statusTextColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          !isInstalled
                              ? 'Perangkat ini belum terpasang di lapangan.'
                              : (_errorMessage != null
                                  ? 'Tidak dapat terhubung ke server backend.'
                                  : (isConnecting
                                      ? 'Menghubungkan ke ${ApiConfig.baseUrl}...'
                                      : 'Komoditas: ${_currentDemplot.commodity} · ${_currentDevice.label} (${_currentDevice.deviceCode})')),
                          style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _statusBadge(badgeLabel, badgeColor),
                ],
              );
            },
          );

          final syncInfo = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sync, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    !isInstalled
                        ? 'Belum ada data'
                        : (data != null
                            ? '${data.timeAgo} (${data.formattedTimestamp})'
                            : (isConnecting ? 'Memuat...' : '-')),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
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
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi,
                          size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Terakhir aktif: ${data!.lastOnlineAgo}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
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
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    syncInfo,
                    if (data?.lastOnline != null) ...[
                      const SizedBox(height: 8),
                      lastOnlineInfo,
                    ],
                  ],
                )
              else
                Wrap(
                  spacing: 10,
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.amber.shade800, size: 22),
          const SizedBox(width: 12),
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
                  'Kemungkinan sensor ESP32 tidak mengirim data melalui MQTT.',
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 22),
              const SizedBox(width: 12),
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
                    'Percobaan ke-$_consecutiveFailures · interval: ${_computePollingInterval().inSeconds}s',
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

        final spacing = 14.0;
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
              const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              statusLabel: data?.lux != null
                  ? (data!.lux! > 500 ? 'Terang' : 'Cukup')
                  : null,
            ),
            _kpiCard(
              cardWidth,
              'SUHU UDARA',
              data != null ? SensorData.formatValue(data.temperature) : null,
              '°C',
              Icons.thermostat_outlined,
              const Color(0xFFEF4444),
              const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              statusLabel: data?.temperature != null
                  ? (data!.temperature! > 32
                      ? 'Tinggi'
                      : (data.temperature! < 24 ? 'Sejuk' : 'Normal'))
                  : null,
            ),
            _kpiCard(
              cardWidth,
              'KELEMBABAN UDARA',
              data != null ? SensorData.formatValue(data.humidity) : null,
              '%',
              Icons.water_drop_outlined,
              const Color(0xFF0284C7),
              const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              statusLabel: data?.humidity != null
                  ? (data!.humidity! > 70 ? 'Lembap' : 'Optimal')
                  : null,
            ),
            _kpiCard(
              cardWidth,
              'KELEMBABAN TANAH',
              data != null ? SensorData.formatValue(data.soilMoisture) : null,
              '%',
              Icons.grass_outlined,
              AppTheme.primaryColor,
              AppTheme.primaryGradient,
              statusLabel: data?.soilMoisture != null
                  ? (data!.soilMoisture! < 30 ? 'Perlu Air' : 'Optimal')
                  : null,
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
    LinearGradient gradient, {
    String? statusLabel,
  }) {
    if (width <= 0) return const SizedBox.shrink();

    final bool isNa = value == 'N/A' || value == null;

    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: isNa
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      if (!isNa) ...[
                        const SizedBox(width: 4),
                        Text(
                          unit,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _currentSensorData != null
                      ? _currentSensorData!.timeAgo
                      : 'Menunggu data...',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (statusLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Accent bottom bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 3,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: gradient,
              ),
            ),
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
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(8),
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
          final cardW = ((width - spacing * 3) / 4).clamp(0.0, double.infinity);
          if (cardW <= 0) return const SizedBox.shrink();

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              _miniMetricCard(
                cardW,
                'pH TANAH',
                data != null ? SensorData.formatValue(data.ph) : null,
                Icons.science_outlined,
                const Color(0xFF8B5CF6),
              ),
              _miniMetricCard(
                cardW,
                'NITROGEN (N)',
                data != null ? _formatNpkValue(data.npkN) : null,
                Icons.eco_outlined,
                const Color(0xFF10B981),
              ),
              _miniMetricCard(
                cardW,
                'FOSFOR (P)',
                data != null ? _formatNpkValue(data.npkP) : null,
                Icons.eco_outlined,
                const Color(0xFF3B82F6),
              ),
              _miniMetricCard(
                cardW,
                'KALIUM (K)',
                data != null ? _formatNpkValue(data.npkK) : null,
                Icons.eco_outlined,
                const Color(0xFFF59E0B),
              ),
            ],
          );
        } else {
          final cardW = ((width - spacing) / 2).clamp(0.0, double.infinity);
          if (cardW <= 0) return const SizedBox.shrink();

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              _miniMetricCard(
                cardW,
                'pH TANAH',
                data != null ? SensorData.formatValue(data.ph) : null,
                Icons.science_outlined,
                const Color(0xFF8B5CF6),
              ),
              _miniMetricCard(
                cardW,
                'NITROGEN (N)',
                data != null ? _formatNpkValue(data.npkN) : null,
                Icons.eco_outlined,
                const Color(0xFF10B981),
              ),
              _miniMetricCard(
                cardW,
                'FOSFOR (P)',
                data != null ? _formatNpkValue(data.npkP) : null,
                Icons.eco_outlined,
                const Color(0xFF3B82F6),
              ),
              _miniMetricCard(
                cardW,
                'KALIUM (K)',
                data != null ? _formatNpkValue(data.npkK) : null,
                Icons.eco_outlined,
                const Color(0xFFF59E0B),
              ),
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

    final bool isNa = value == 'N/A' || value == null;

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          value == null
              ? _shimmerPlaceholder()
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isNa
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ============================================================================
  // SPRAY CONTROL SECTION — Pupuk Cair & Pestisida Aktuator
  // ============================================================================
  Widget _buildSprayControlSection() {
    final isSpraying =
        _isSprayingFertilizer || _isSprayingPesticide || _isSprayingWater;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.shower_rounded,
                              size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Kontrol Penyemprotan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Target: ${_currentDemplot.name} (${_currentDemplot.commodity})',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder<MqttConnectionState>(
                valueListenable: MqttService.instance.connectionState,
                builder: (context, mqttState, _) {
                  final bool mqttConnected =
                      mqttState == MqttConnectionState.connected;

                  Color badgeBg;
                  Color badgeBorder;
                  Color dotColor;
                  Color textColor;
                  String label;

                  if (isSpraying) {
                    badgeBg = const Color(0xFFFEF3C7);
                    badgeBorder = const Color(0xFFF59E0B);
                    dotColor = const Color(0xFFD97706);
                    textColor = const Color(0xFFB45309);
                    label = 'MENYEMPROT';
                  } else if (mqttConnected) {
                    badgeBg = const Color(0xFFDCFCE7);
                    badgeBorder = const Color(0xFF16A34A);
                    dotColor = const Color(0xFF16A34A);
                    textColor = const Color(0xFF15803D);
                    label = 'MQTT TERHUBUNG';
                  } else {
                    badgeBg = const Color(0xFFFEE2E2);
                    badgeBorder = const Color(0xFFFCA5A5);
                    dotColor = const Color(0xFFDC2626);
                    textColor = const Color(0xFFB91C1C);
                    label = 'MQTT TERPUTUS';
                  }

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badgeBorder, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dotColor,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),

          // Banner jika sedang aktif menyemprot
          if (isSpraying) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menyemprot $_activeSprayingType...',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        Text(
                          'Tersisa: $_sprayRemainingSeconds detik di ${_currentDemplot.name}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _stopSpraying,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Hentikan',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Tiga Kartu Kontrol
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 550;

              final fertilizerCard = _sprayCard(
                title: 'Semprot Pupuk Cair',
                subtitle: 'Nutrisi organik untuk kesuburan tanah & tanaman',
                icon: Icons.eco_rounded,
                accentColor: const Color(0xFF0F7646),
                gradient: AppTheme.primaryGradient,
                selectedDuration: _fertilizerDuration,
                onDurationChanged: (val) =>
                    setState(() => _fertilizerDuration = val),
                isThisSpraying: _isSprayingFertilizer,
                onAction: () => _confirmAndSpray(
                  type: 'Pupuk Cair',
                  durationSeconds: _fertilizerDuration,
                ),
              );

              final pesticideCard = _sprayCard(
                title: 'Semprot Pestisida',
                subtitle: 'Proteksi tanaman dari hama & jamur',
                icon: Icons.shield_outlined,
                accentColor: const Color(0xFFD97706),
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                selectedDuration: _pesticideDuration,
                onDurationChanged: (val) =>
                    setState(() => _pesticideDuration = val),
                isThisSpraying: _isSprayingPesticide,
                onAction: () => _confirmAndSpray(
                  type: 'Pestisida',
                  durationSeconds: _pesticideDuration,
                ),
              );

              final waterCard = _sprayCard(
                title: 'Siram Air Saja',
                subtitle: 'Penyiraman air bersih tanpa campuran',
                icon: Icons.water_drop,
                accentColor: const Color(0xFF0284C7),
                gradient: const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                durationOptions: const [5, 10, 15],
                durationUnit: 'm',
                selectedDuration: _waterDuration,
                onDurationChanged: (val) =>
                    setState(() => _waterDuration = val),
                isThisSpraying: _isSprayingWater,
                onAction: () => _confirmAndSpray(
                  type: 'Siram Air',
                  durationSeconds: _waterDuration * 60,
                ),
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: fertilizerCard),
                    const SizedBox(width: 14),
                    Expanded(child: pesticideCard),
                    const SizedBox(width: 14),
                    Expanded(child: waterCard),
                  ],
                );
              } else {
                return Column(
                  children: [
                    fertilizerCard,
                    const SizedBox(height: 14),
                    pesticideCard,
                    const SizedBox(height: 14),
                    waterCard,
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Riwayat singkat penyemprotan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Aktivitas Penyemprotan Terakhir',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
              Text(
                '${_sprayLogs.length} Log',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._sprayLogs.take(2).map((log) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            log['type'] == 'Pupuk Cair'
                                ? Icons.eco
                                : log['type'] == 'Siram Air'
                                    ? Icons.water_drop
                                    : Icons.shield,
                            size: 14,
                            color: log['type'] == 'Pupuk Cair'
                                ? AppTheme.primaryColor
                                : log['type'] == 'Siram Air'
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${log['type']} (${log['duration']}) · ${log['demplot']}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        log['time'] ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _sprayCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required LinearGradient gradient,
    required int selectedDuration,
    required Function(int) onDurationChanged,
    required bool isThisSpraying,
    required VoidCallback onAction,
    List<int> durationOptions = const [5, 10, 15],
    String durationUnit = 's',
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Durasi:',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                children: durationOptions.map((val) {
                  final isSelected = selectedDuration == val;
                  return GestureDetector(
                    onTap: () => onDurationChanged(val),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSelected ? accentColor : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? accentColor
                              : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        '$val$durationUnit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: isThisSpraying ? _stopSpraying : onAction,
              icon: Icon(
                isThisSpraying
                    ? Icons.stop_circle_outlined
                    : Icons.play_arrow_rounded,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                isThisSpraying
                    ? 'Hentikan ($_sprayRemainingSeconds s)'
                    : 'Mulai $title',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isThisSpraying ? Colors.red.shade700 : accentColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAndSpray({
    required String type,
    required int durationSeconds,
  }) {
    // Determine icon and color based on type
    final IconData typeIcon;
    final Color typeColor;
    if (type == 'Pupuk Cair') {
      typeIcon = Icons.eco;
      typeColor = AppTheme.primaryColor;
    } else if (type == 'Siram Air') {
      typeIcon = Icons.water_drop;
      typeColor = const Color(0xFF0284C7);
    } else {
      typeIcon = Icons.shield;
      typeColor = const Color(0xFFD97706);
    }

    final String actionLabel =
        type == 'Siram Air' ? 'penyiraman air bersih' : 'penyemprotan $type';

    final String durationLabel =
        type == 'Siram Air' ? 'Durasi Siram' : 'Durasi Semprot';

    final String buttonLabel =
        type == 'Siram Air' ? 'Mulai Siram' : 'Mulai Semprot';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(typeIcon, color: typeColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Konfirmasi $type',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anda akan mengaktifkan aktuator $actionLabel dengan parameter:',
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _confirmRow('Target Demplot',
                      '${_currentDemplot.name} (${_currentDemplot.commodity})'),
                  const SizedBox(height: 6),
                  _confirmRow('Node Aktif', _currentDevice.label),
                  const SizedBox(height: 6),
                  _confirmRow(
                    durationLabel,
                    type == 'Siram Air'
                        ? '${durationSeconds ~/ 60} Menit'
                        : '$durationSeconds Detik',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startSpraying(type: type, durationSeconds: durationSeconds);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: typeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A))),
      ],
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
              const SizedBox(width: 18),
              Expanded(flex: 1, child: _buildDeviceInfoCard()),
            ],
          );
        } else {
          return Column(
            children: [
              _buildBarChartCard(),
              const SizedBox(height: 18),
              _buildDeviceInfoCard(),
            ],
          );
        }
      },
    );
  }

  Widget _buildBarChartCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Tren Kelembaban Tanah',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Data historis 7 hari terakhir',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Mingguan',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
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
    final barWidth = (containerWidth / 10).clamp(14.0, 34.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: barWidth,
          height: height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF16A34A), Color(0xFF0F7646)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceInfoCard() {
    final data = _currentSensorData;
    final device = _currentDevice;
    final bool isInstalled = device.isInstalled;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Info Node Sensor',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isInstalled)
                _statusBadge('BELUM TERPASANG', const Color(0xFF64748B))
              else if (data != null)
                _statusBadge(
                  data.isDeviceOnline ? 'ONLINE' : 'OFFLINE',
                  data.isDeviceOnline
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _deviceInfoRow(
            Icons.label_outlined,
            'Label Node',
            device.label,
          ),
          const SizedBox(height: 12),
          _deviceInfoRow(
            Icons.qr_code_outlined,
            'Kode Perangkat',
            device.deviceCode,
          ),
          const SizedBox(height: 12),
          _deviceInfoRow(
            Icons.router_outlined,
            'ID Perangkat',
            device.deviceId,
          ),
          const SizedBox(height: 12),
          _deviceInfoRow(
            Icons.landscape_outlined,
            'Demplot / Lahan',
            '${_currentDemplot.name} (${_currentDemplot.commodity})',
          ),
          const SizedBox(height: 12),
          _deviceInfoRow(
            Icons.wifi,
            'Status Node',
            !isInstalled
                ? 'Belum Terpasang'
                : (data?.deviceStatus ?? (isInstalled ? 'OFFLINE' : '-')),
          ),
          const SizedBox(height: 12),
          _deviceInfoRow(
            Icons.battery_charging_full,
            'Baterai',
            !isInstalled
                ? '-'
                : (data?.battery != null
                    ? '${data!.battery!.toStringAsFixed(0)}%'
                    : '-'),
          ),
          const SizedBox(height: 12),
          _deviceInfoRow(
            Icons.signal_cellular_alt,
            'Sinyal RSSI',
            !isInstalled
                ? '-'
                : (data?.signal != null ? '${data!.signal} dBm' : '-'),
          ),
          const SizedBox(height: 12),
          _deviceInfoRow(
            Icons.access_time,
            'Terakhir Online',
            !isInstalled ? '-' : (data?.lastOnlineAgo ?? '-'),
          ),
        ],
      ),
    );
  }

  Widget _deviceInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: const Color(0xFF64748B)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
