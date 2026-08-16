import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/mock_control_helper.dart';
import '../../../core/models/alert_model.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/services/sensor_service.dart';

class AlertsView extends StatefulWidget {
  const AlertsView({super.key});

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  late final AlertService _alertService;
  List<AlertModel> _alerts = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _alertService = AlertService(SensorService());
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final alerts = await _alertService.fetchAndEvaluateAlerts();
      if (mounted) {
        setState(() {
          _alerts = alerts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _dismissAlert(String id) {
    setState(() {
      _alerts.removeWhere((a) => a.id == id);
    });
    MockControlHelper.showSimulationSnackBar(
      context,
      featureName: 'Dismiss Alert',
      description: 'Alert dihapus dari tampilan lokal.',
    );
  }

  void _markAllRead() {
    setState(() {
      _alerts.clear();
    });
    MockControlHelper.showSimulationSnackBar(
      context,
      featureName: 'Tandai Semua Dibaca',
      description: 'Semua alert ditandai sudah dibaca dan dihapus dari layar.',
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 850;

        if (_isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
        }
        if (_errorMessage.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(_errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadAlerts, child: const Text('Coba Lagi')),
              ],
            ),
          );
        }

        if (isDesktop) {
          return _buildDesktopLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  // ==========================================================================
  // TATA LETAK DESKTOP (WEB)
  // ==========================================================================
  Widget _buildDesktopLayout() {
    int critCount = _alerts.where((a) => a.severity == AlertSeverity.critical).length;
    int warnCount = _alerts.where((a) => a.severity == AlertSeverity.warning).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Sistem Peringatan Dini",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text("Memantau anomali sensor dan isu kritis di seluruh lahan. ($critCount Kritis, $warnCount Peringatan)",
                      style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _loadAlerts,
                    icon: const Icon(Icons.refresh, size: 16, color: Colors.black87),
                    label: const Text("Refresh", style: TextStyle(color: Colors.black87)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(color: Colors.grey.shade300),
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: _markAllRead,
                    child: const Text("Mark All Read",
                        style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  )
                ],
              )
            ],
          ),
          const SizedBox(height: 32),

          if (_alerts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 64.0),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 80, color: Colors.green.shade300),
                    const SizedBox(height: 16),
                    const Text("Sistem Aman", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 8),
                    const Text("Tidak ada peringatan kritis atau anomali yang terdeteksi saat ini.", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _alerts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final alert = _alerts[index];
                if (alert.severity == AlertSeverity.critical) {
                  return _buildDesktopCriticalCard(alert);
                } else if (alert.severity == AlertSeverity.warning) {
                  return _buildDesktopWarningCard(alert);
                } else {
                  return _buildDesktopInfoCard(alert);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopCriticalCard(AlertModel alert) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200, width: 2),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 40,
            top: 10,
            child: Icon(Icons.warning_amber_rounded, size: 100, color: Colors.red.withOpacity(0.05)),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                    backgroundColor: Colors.red.shade700,
                    radius: 24,
                    child: Icon(alert.title.contains('Suhu') ? Icons.thermostat : Icons.water_drop, color: Colors.white)),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _pill("CRITICAL", Colors.red),
                          const SizedBox(width: 8),
                          Text(_formatTimeAgo(alert.timestamp),
                              style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(alert.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(alert.description,
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => _dismissAlert(alert.id),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade700),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                      child: const Text("Dismiss"),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        MockControlHelper.showSimulationDialog(
                          context,
                          title: 'Tindakan Darurat',
                          description: 'Mengaktifkan perintah darurat (seperti pompa/ventilasi) ke alat ${alert.deviceId}.',
                          icon: Icons.power_settings_new,
                        );
                      },
                      icon: const Icon(Icons.power_settings_new, size: 16, color: Colors.white),
                      label: const Text("Tindak Lanjut", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
                    )
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopWarningCard(AlertModel alert) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200, width: 1.5)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
              backgroundColor: Colors.orange.shade600,
              radius: 20,
              child: Icon(alert.title.contains('Suhu') ? Icons.thermostat : Icons.opacity, color: Colors.white, size: 20)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _pill("WARNING", Colors.orange.shade600),
                    const SizedBox(width: 8),
                    Text(_formatTimeAgo(alert.timestamp),
                        style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(alert.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(alert.description,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.grey.shade400),
              onPressed: () => _dismissAlert(alert.id),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDesktopInfoCard(AlertModel alert) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
              backgroundColor: Colors.blue.shade600,
              radius: 20,
              child: const Icon(Icons.wifi_off, color: Colors.white, size: 20)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _pill("INFO", Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Text(_formatTimeAgo(alert.timestamp),
                        style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(alert.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(alert.description,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: Colors.grey.shade400),
            onPressed: () => _dismissAlert(alert.id),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TATA LETAK MOBILE
  // ==========================================================================
  Widget _buildMobileLayout() {
    int critCount = _alerts.where((a) => a.severity == AlertSeverity.critical).length;
    int warnCount = _alerts.where((a) => a.severity == AlertSeverity.warning).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Peringatan Dini",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.primaryColor),
                onPressed: _loadAlerts,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text("Memantau kondisi kritis di lapangan.",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 24),

          // Ringkasan
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      Text(critCount.toString(),
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                      Text("Kritis", style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500))
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      Text(warnCount.toString(),
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                      Text("Peringatan", style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w500))
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Daftar Peringatan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton(
                onPressed: _markAllRead,
                child: const Text("Tandai Semua Dibaca", style: TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
              )
            ],
          ),
          const SizedBox(height: 12),

          if (_alerts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48.0),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
                    const SizedBox(height: 16),
                    const Text("Sistem Aman", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _alerts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final alert = _alerts[index];
                if (alert.severity == AlertSeverity.critical) {
                  return _mobileCriticalCard(alert);
                } else if (alert.severity == AlertSeverity.warning) {
                  return _mobileWarningCard(alert);
                } else {
                  return _mobileInfoCard(alert);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _mobileCriticalCard(AlertModel alert) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200, width: 2),
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.05), blurRadius: 10, spreadRadius: 2)],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 20,
            top: 20,
            child: Icon(Icons.warning, size: 80, color: Colors.red.withOpacity(0.05)),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _pill("CRITICAL", Colors.red.shade700),
                    Text(_formatTimeAgo(alert.timestamp),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(alert.title.contains('Suhu') ? Icons.thermostat : Icons.water_drop, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(alert.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(alert.description,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _dismissAlert(alert.id),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700, side: BorderSide(color: Colors.red.shade300)),
                        child: const Text("Abaikan"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          MockControlHelper.showSimulationDialog(context,
                              title: 'Tindak Lanjut',
                              description: 'Kirim perintah darurat ke node ${alert.deviceId}.',
                              icon: Icons.power_settings_new);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                        child: const Text("Tindak", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileWarningCard(AlertModel alert) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _pill("WARNING", Colors.orange.shade700),
              Text(_formatTimeAgo(alert.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(alert.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(alert.description,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _dismissAlert(alert.id),
              child: Text("Tandai Dibaca", style: TextStyle(color: Colors.orange.shade700)),
            ),
          )
        ],
      ),
    );
  }

  Widget _mobileInfoCard(AlertModel alert) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _pill("INFO", Colors.blue.shade700),
              Text(_formatTimeAgo(alert.timestamp),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(alert.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(alert.description,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => _dismissAlert(alert.id),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("Dismiss", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
    );
  }
}
