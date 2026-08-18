import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/config/demplot_config.dart';
import '../../core/models/sensor_data.dart';
import '../../core/services/sensor_service.dart';
import '../../core/theme/app_theme.dart';

class DevicesView extends StatefulWidget {
  const DevicesView({super.key});

  @override
  State<DevicesView> createState() => _DevicesViewState();
}

class _DevicesViewState extends State<DevicesView> {
  final SensorService _sensorService = SensorService();
  Map<String, SensorData> _telemetryMap = {};
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTelemetry();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadTelemetry());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTelemetry() async {
    try {
      final list = await _sensorService.fetchAllLatestTelemetry();
      final map = <String, SensorData>{};
      for (final item in list) {
        if (item.deviceId != null) {
          map[item.deviceId!] = item;
        }
      }
      if (mounted) {
        setState(() {
          _telemetryMap = map;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadTelemetry,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Status Node & Perangkat",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Pemantauan status konektivitas dan daya perangkat sensor.",
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _loadTelemetry();
                  },
                  icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                  tooltip: 'Segarkan',
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Loop demplots
            ...DemplotConfig.demplots.map((demplot) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(demplot.icon, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(
                          '${demplot.name} — ${demplot.commodity}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 650;
                        final spacing = 14.0;
                        final cardWidth = isWide
                            ? (constraints.maxWidth - spacing) / 2
                            : constraints.maxWidth;

                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: demplot.devices.map((device) {
                            final telemetry = _telemetryMap[device.deviceId];
                            final isInstalled = device.isInstalled;
                            final isOnline = isInstalled && (telemetry?.isDeviceOnline ?? false);

                            return _buildDeviceCard(
                              width: cardWidth,
                              demplot: demplot,
                              device: device,
                              telemetry: telemetry,
                              isInstalled: isInstalled,
                              isOnline: isOnline,
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard({
    required double width,
    required Demplot demplot,
    required DeviceNode device,
    required SensorData? telemetry,
    required bool isInstalled,
    required bool isOnline,
  }) {
    Color statusColor;
    String statusLabel;
    if (!isInstalled) {
      statusColor = const Color(0xFF64748B);
      statusLabel = "BELUM TERPASANG";
    } else if (isOnline) {
      statusColor = const Color(0xFF16A34A);
      statusLabel = "ONLINE";
    } else {
      statusColor = const Color(0xFFDC2626);
      statusLabel = "OFFLINE";
    }

    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline
              ? const Color(0xFFBBF7D0)
              : (!isInstalled ? AppTheme.borderColor : const Color(0xFFFECACA)),
          width: 1.2,
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.router_outlined,
                      color: statusColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        device.deviceCode,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _buildStatusPill(statusLabel, statusColor),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          _detailRow(
            icon: Icons.battery_charging_full,
            label: "Daya Baterai",
            value: !isInstalled
                ? "-"
                : (telemetry?.battery != null
                    ? '${telemetry!.battery!.toStringAsFixed(0)}%'
                    : "-"),
          ),
          const SizedBox(height: 8),
          _detailRow(
            icon: Icons.signal_cellular_alt,
            label: "Sinyal RSSI",
            value: !isInstalled
                ? "-"
                : (telemetry?.signal != null ? '${telemetry!.signal} dBm' : "-"),
          ),
          const SizedBox(height: 8),
          _detailRow(
            icon: Icons.access_time,
            label: "Sinkronisasi Terakhir",
            value: !isInstalled
                ? "Belum ada data"
                : (telemetry != null
                    ? telemetry.timeAgo
                    : (_isLoading ? "Memuat..." : "Belum ada data")),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

