import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import '../../core/services/mqtt_service.dart';
import '../../core/utils/mock_control_helper.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _drainageValve = false;
  bool _fertilizerInjector = false;
  bool _irrigationPump = false;
  
  double _soilMoistureThreshold = 25.0;
  double _maxTempThreshold = 35.0;
  double _minLightThreshold = 200.0;
  
  bool _droughtAlert = true;
  bool _pestAlert = true;
  bool _dailyReport = false;
  bool _lowBatteryAlert = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pengaturan Sistem',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F5A34),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Konfigurasi otomasi, ambang batas, dan notifikasi lahan Anda.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 32),
                if (isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _buildAutomationCard(),
                            const SizedBox(height: 24),
                            _buildNotificationCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          children: [
                            _buildThresholdCard(),
                            const SizedBox(height: 24),
                            _buildSystemInfoCard(),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildAutomationCard(),
                      const SizedBox(height: 24),
                      _buildThresholdCard(),
                      const SizedBox(height: 24),
                      _buildNotificationCard(),
                      const SizedBox(height: 24),
                      _buildSystemInfoCard(),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F5A34),
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildAutomationCard() {
    return _buildCard(
      title: 'Kontrol Otomasi',
      child: Column(
        children: [
          _buildSwitchRow(
            icon: Icons.water_damage,
            label: 'Katup Drainase',
            description: 'Buka/tutup katup air otomatis berdasarkan sensor',
            value: _drainageValve,
            onChanged: (val) {
              setState(() => _drainageValve = val);
              MockControlHelper.showSimulationSnackBar(
                context,
                featureName: 'Kontrol Katup Drainase',
                description: 'Di lahan, tombol ini akan mengirim perintah otomatis ke ESP32 melalui MQTT untuk membuka/menutup katup drainase.',
              );
            },
          ),
          const Divider(height: 32),
          _buildSwitchRow(
            icon: Icons.science,
            label: 'Injektor Pupuk',
            description: 'Aktivasi injektor pupuk cair otomatis',
            value: _fertilizerInjector,
            onChanged: (val) {
              setState(() => _fertilizerInjector = val);
              MockControlHelper.showSimulationSnackBar(
                context,
                featureName: 'Kontrol Injektor Pupuk',
                description: 'Di lahan, injektor pupuk akan diaktifkan melalui relay yang terhubung ke ESP32. Dosis disesuaikan dengan pembacaan sensor NPK.',
              );
            },
          ),
          const Divider(height: 32),
          _buildSwitchRow(
            icon: Icons.power,
            label: 'Pompa Irigasi',
            description: 'Kontrol pompa air utama',
            value: _irrigationPump,
            onChanged: (val) {
              setState(() => _irrigationPump = val);
              MockControlHelper.showSimulationDialog(
                context,
                title: 'Kontrol Pompa Irigasi',
                description: 'Di lahan, pompa irigasi utama akan diaktifkan/dinonaktifkan melalui relay ESP32. Sistem otomatis berhenti saat kelembaban tanah mencapai ambang batas yang ditentukan.',
                icon: Icons.water_drop,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F5A34).withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF0F5A34)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF0F5A34),
        ),
      ],
    );
  }

  Widget _buildThresholdCard() {
    return _buildCard(
      title: 'Ambang Batas Sensor',
      child: Column(
        children: [
          _buildSliderRow(
            label: 'Kelembaban Tanah Minimum',
            value: _soilMoistureThreshold,
            min: 0,
            max: 100,
            divisions: 20,
            unit: '%',
            onChanged: (val) => setState(() => _soilMoistureThreshold = val),
            onChangeEnd: (val) {
              MockControlHelper.showSimulationSnackBar(
                context,
                featureName: 'Ambang Kelembaban Tanah',
                description: 'Ambang batas diatur ke ${val.toInt()}%. Di lahan, irigasi otomatis akan aktif saat kelembaban tanah turun di bawah nilai ini.',
              );
            },
          ),
          const Divider(height: 32),
          _buildSliderRow(
            label: 'Suhu Maksimum',
            value: _maxTempThreshold,
            min: 20,
            max: 50,
            divisions: 30,
            unit: '°C',
            onChanged: (val) => setState(() => _maxTempThreshold = val),
            onChangeEnd: (val) {
              MockControlHelper.showSimulationSnackBar(
                context,
                featureName: 'Ambang Suhu',
                description: 'Ambang batas suhu maksimum diatur ke ${val.toInt()}°C.',
              );
            },
          ),
          const Divider(height: 32),
          _buildSliderRow(
            label: 'Intensitas Cahaya Minimum',
            value: _minLightThreshold,
            min: 0,
            max: 1000,
            divisions: 20,
            unit: ' Lux',
            onChanged: (val) => setState(() => _minLightThreshold = val),
            onChangeEnd: (val) {
              MockControlHelper.showSimulationSnackBar(
                context,
                featureName: 'Ambang Cahaya',
                description: 'Ambang batas intensitas cahaya minimum diatur ke ${val.toInt()} Lux.',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${value.toInt()}$unit',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F5A34),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          // ignore: deprecated_member_use
          activeColor: const Color(0xFF0F5A34),
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }

  Widget _buildNotificationCard() {
    return _buildCard(
      title: 'Notifikasi & Peringatan',
      child: Column(
        children: [
          _buildSimpleSwitch(
            icon: Icons.water_drop_outlined,
            label: 'Peringatan Kekeringan',
            value: _droughtAlert,
            onChanged: (val) {
              setState(() => _droughtAlert = val);
              _showNotifSnack('Peringatan Kekeringan', val);
            },
          ),
          const Divider(height: 24),
          _buildSimpleSwitch(
            icon: Icons.bug_report_outlined,
            label: 'Notifikasi Hama',
            value: _pestAlert,
            onChanged: (val) {
              setState(() => _pestAlert = val);
              _showNotifSnack('Notifikasi Hama', val);
            },
          ),
          const Divider(height: 24),
          _buildSimpleSwitch(
            icon: Icons.summarize_outlined,
            label: 'Laporan Harian',
            value: _dailyReport,
            onChanged: (val) {
              setState(() => _dailyReport = val);
              _showNotifSnack('Laporan Harian', val);
            },
          ),
          const Divider(height: 24),
          _buildSimpleSwitch(
            icon: Icons.battery_alert,
            label: 'Alert Baterai Rendah',
            value: _lowBatteryAlert,
            onChanged: (val) {
              setState(() => _lowBatteryAlert = val);
              _showNotifSnack('Alert Baterai Rendah', val);
            },
          ),
        ],
      ),
    );
  }

  void _showNotifSnack(String name, bool val) {
    MockControlHelper.showSimulationSnackBar(
      context,
      featureName: 'Pengaturan Notifikasi',
      description: '$name telah di${val ? 'aktifkan' : 'nonaktifkan'}.',
    );
  }

  Widget _buildSimpleSwitch({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.black54),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF0F5A34),
        ),
      ],
    );
  }

  Widget _buildSystemInfoCard() {
    return _buildCard(
      title: 'Informasi Sistem',
      child: Column(
        children: [
          _buildInfoRow('Versi Aplikasi', '1.0.0'),
          const Divider(height: 24),
          _buildInfoRow('Firmware ESP32', 'v2.4.1'),
          const Divider(height: 24),
          _buildInfoRow('Server API', '103.174.114.65:3001'),
          const Divider(height: 24),
          _buildInfoRow('MQTT Broker', '103.174.114.65:1883'),
          const Divider(height: 24),
          // Live MQTT connection status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Status MQTT',
                  style: TextStyle(fontSize: 15, color: Colors.black54)),
              ValueListenableBuilder<MqttConnectionState>(
                valueListenable: MqttService.instance.connectionState,
                builder: (context, state, _) {
                  final isConnected = state == MqttConnectionState.connected;
                  final isConnecting = state == MqttConnectionState.connecting;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConnected
                              ? const Color(0xFF16A34A)
                              : (isConnecting
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFDC2626)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isConnected
                            ? 'Terhubung'
                            : (isConnecting ? 'Menghubungkan...' : 'Terputus'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isConnected
                              ? const Color(0xFF16A34A)
                              : (isConnecting
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFDC2626)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String key, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(key, style: const TextStyle(fontSize: 15, color: Colors.black54)),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
