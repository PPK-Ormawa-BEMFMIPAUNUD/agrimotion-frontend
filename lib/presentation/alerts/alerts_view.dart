import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/mock_control_helper.dart';

class AlertsView extends StatefulWidget {
  const AlertsView({super.key});

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  bool _criticalDismissed = false;
  bool _warningDismissed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 850;
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("System Alerts",
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  SizedBox(height: 4),
                  Text(
                      "Monitor critical issues and system notifications across all deployed nodes.",
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      MockControlHelper.showSimulationSnackBar(
                        context,
                        featureName: 'Filter Notifikasi',
                        description:
                            'Di lahan, Anda dapat memfilter notifikasi berdasarkan tingkat keparahan (Critical, Warning, Info) dan sektor lahan.',
                      );
                    },
                    icon: const Icon(Icons.filter_list,
                        size: 16, color: Colors.black87),
                    label: const Text("Filter",
                        style: TextStyle(color: Colors.black87)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(color: Colors.grey.shade300),
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () {
                      MockControlHelper.showSimulationSnackBar(
                        context,
                        featureName: 'Tandai Semua Dibaca',
                        description:
                            'Semua notifikasi akan ditandai sebagai sudah dibaca dan disinkronkan ke server.',
                      );
                    },
                    child: const Text("Mark All Read",
                        style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold)),
                  )
                ],
              )
            ],
          ),
          const SizedBox(height: 32),

          // ROW 1: Full Width Critical Alert
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _criticalDismissed
                ? const SizedBox.shrink()
                : _buildDesktopCriticalCard(),
          ),

          if (!_criticalDismissed) const SizedBox(height: 24),

          // ROW 2: Warning (60%) & Info (40%)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _warningDismissed
                      ? const SizedBox.shrink()
                      : _buildDesktopWarningCard(),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: _buildDesktopInfoCard()),
            ],
          ),

          const SizedBox(height: 24),

          // ROW 3: Small Info Cards
          Row(
            children: [
              Expanded(
                  child: _buildDesktopSmallCard(
                      Icons.system_update_alt,
                      "Firmware Update Complete",
                      "All Gateways updated to v2.4.1",
                      "Yesterday")),
              const SizedBox(width: 24),
              Expanded(
                  child: _buildDesktopSmallCard(
                      Icons.solar_power_outlined,
                      "Solar Array Optimal",
                      "Sector 4 batteries fully charged.",
                      "Yesterday")),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDesktopCriticalCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: Colors.red.shade700, width: 4),
          top: BorderSide(color: Colors.grey.shade200),
          right: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.red.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 2)
        ],
      ),
      child: Stack(
        children: [
          // Watermark Triangle di background kanan
          Positioned(
            right: 40,
            top: 10,
            child: Icon(Icons.change_history,
                size: 100, color: Colors.red.withOpacity(0.05)),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                    backgroundColor: Colors.red.shade700,
                    radius: 24,
                    child: const Icon(Icons.water_drop, color: Colors.white)),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _pill("CRITICAL", Colors.red),
                          const SizedBox(width: 8),
                          const Text("Just now",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text("Soil Moisture Critically Low",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        "Node #Alpha-04 in Sector 7 is reporting soil moisture at 12% (threshold: 25%).\nImmediate irrigation required to prevent crop stress.",
                        style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _criticalDismissed = true;
                        });
                        MockControlHelper.showSimulationSnackBar(
                          context,
                          featureName: 'Dismiss Alert',
                          description:
                              'Alert telah di-dismiss. Di lahan, status ini akan disinkronkan ke server dan dihapus dari antrian notifikasi.',
                        );
                      },
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade700),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16)),
                      child: const Text("Dismiss"),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        MockControlHelper.showSimulationDialog(
                          context,
                          title: 'Aktivasi Pompa Irigasi',
                          description:
                              'Di lahan, tombol ini akan mengirim perintah otomatis ke ESP32 melalui MQTT untuk mengaktifkan pompa irigasi di Sektor 7. Sistem akan berjalan selama 15 menit atau hingga kelembaban tanah mencapai 25%.',
                          icon: Icons.water_drop,
                        );
                      },
                      icon: const Icon(Icons.power_settings_new,
                          size: 16, color: Colors.white),
                      label: const Text("Activate Pump",
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16)),
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

  Widget _buildDesktopWarningCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
              backgroundColor: Colors.red.shade600,
              radius: 20,
              child:
                  const Icon(Icons.thermostat, color: Colors.white, size: 20)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _pill("WARNING", Colors.red.shade600),
                    const SizedBox(width: 8),
                    const Text("45 mins ago",
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text("Temperature Spike Detected",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    "Greenhouse 2 ambient temperature has risen by 5°C in the last hour. Current\ntemp: 32°C. Ventilation system automated response initiated.",
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.4)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        MockControlHelper.showSimulationSnackBar(
                          context,
                          featureName: 'Grafik Suhu',
                          description: 'Di lahan, grafik real-time suhu greenhouse akan ditampilkan dari data sensor DHT22.',
                        );
                      },
                      child: Text("View Graph",
                          style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: () {
                        setState(() => _warningDismissed = true);
                        MockControlHelper.showSimulationSnackBar(
                          context,
                          featureName: 'Tandai Dibaca',
                          description: 'Warning telah ditandai sudah dibaca dan disinkronkan ke server.',
                        );
                      },
                      child: Text("Mark Read",
                          style: TextStyle(
                              color: Colors.grey.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDesktopInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
              backgroundColor: Colors.green.shade700,
              radius: 20,
              child: const Icon(Icons.wifi_off, color: Colors.white, size: 20)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _pill("INFO", Colors.green.shade700),
                    const SizedBox(width: 8),
                    const Text("2 hours ago",
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text("Node Disconnected",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                    "Node #Beta-12 lost\nconnection briefly but re-\nestablished successfully.",
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        height: 1.4)),
                const SizedBox(height: 16),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 8),
                Center(
                    child: Text("Dismiss",
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                            fontSize: 12))),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDesktopSmallCard(
      IconData icon, String title, String subtitle, String time) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.grey.shade600, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Text(time,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
        ],
      ),
    );
  }

  // ==========================================================================
  // TATA LETAK MOBILE
  // ==========================================================================
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9), // Abu-abu sangat terang
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.notifications_none, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text("Alerts",
                style: TextStyle(
                    color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.black87),
              onPressed: () {
                MockControlHelper.showSimulationSnackBar(
                  context,
                  featureName: 'Filter Notifikasi',
                  description:
                      'Anda dapat memfilter notifikasi berdasarkan tingkat keparahan dan zona lahan.',
                );
              }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Top KPI Row
            Row(
              children: [
                Expanded(
                    child: _mobileKpiCard(
                        Icons.error, "Critical", "2", Colors.red.shade700)),
                const SizedBox(width: 16),
                Expanded(
                    child: _mobileKpiCard(Icons.warning, "Warnings", "5",
                        Colors.orange.shade600)),
              ],
            ),
            const SizedBox(height: 24),

            // List of Cards
            _mobileCriticalCard(
              "Moisture Levels Critical",
              "Zone A (North Field) soil moisture dropped below 15%. Immediate irrigation required to prevent crop stress.",
              "2 mins ago",
              Icons.water_drop,
              "Activate Pump A",
              Icons.power_settings_new,
              onPrimaryPressed: () {
                MockControlHelper.showSimulationDialog(
                  context,
                  title: 'Aktivasi Pompa Irigasi',
                  description:
                      'Di lahan, tombol ini akan mengirim perintah otomatis ke ESP32 melalui MQTT untuk mengaktifkan pompa irigasi di Pompa A di Zona Utara. Sistem akan berjalan selama 15 menit atau hingga kelembaban tanah mencapai 25%.',
                  icon: Icons.water_drop,
                );
              },
            ),
            const SizedBox(height: 16),
            _mobileCriticalCard(
              "Greenhouse Temp Spike",
              "Greenhouse 3 temperature exceeded 35°C. Cooling systems failed to respond.",
              "15 mins ago",
              Icons.thermostat,
              "Force Vents Open",
              Icons.ac_unit,
              onPrimaryPressed: () {
                MockControlHelper.showSimulationDialog(
                  context,
                  title: 'Buka Ventilasi Greenhouse',
                  description:
                      'Di lahan, perintah ini akan membuka ventilasi otomatis di Greenhouse 3 melalui aktuator servo yang terhubung ke ESP32. Sistem pendinginan akan aktif sampai suhu turun di bawah 30°C.',
                  icon: Icons.ac_unit,
                );
              },
            ),
            const SizedBox(height: 16),
            _mobileWarningCard(
              "Low Battery: Node 42",
              "Sensor node 42 in Sector B is reporting 15% battery remaining.",
              "1 hour ago",
              "Acknowledge",
              onPressed: () {
                MockControlHelper.showSimulationSnackBar(
                  context,
                  featureName: 'Acknowledge Alert',
                  description:
                      'Alert telah di-acknowledge. Tim maintenance akan menerima notifikasi untuk pengecekan baterai Node 42.',
                );
              },
            ),
            const SizedBox(height: 16),
            _mobileWarningCard(
              "Irregular Flow Rate",
              "Main line flow rate is 10% below expected levels. Possible minor leak or blockage.",
              "3 hours ago",
              "Schedule Inspection",
              onPressed: () {
                MockControlHelper.showSimulationDialog(
                  context,
                  title: 'Jadwalkan Inspeksi',
                  description:
                      'Di lahan, fitur ini akan membuat jadwal inspeksi otomatis dan mengirim notifikasi ke tim lapangan untuk memeriksa jalur pipa utama.',
                  icon: Icons.calendar_month,
                );
              },
            ),
            const SizedBox(height: 16),
            _mobileInfoCard(
                "System Update Complete",
                "Gateway firmware updated to v2.4.1 successfully.",
                "Yesterday"),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _mobileKpiCard(
      IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _mobileCriticalCard(String title, String desc, String time,
      IconData bgIcon, String btnText, IconData btnIcon,
      {VoidCallback? onPrimaryPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
            left: BorderSide(color: Colors.red.shade700, width: 4),
            top: BorderSide(color: Colors.grey.shade200),
            right: BorderSide(color: Colors.grey.shade200),
            bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
              color: Colors.red.withOpacity(0.02),
              blurRadius: 10,
              spreadRadius: 2)
        ],
      ),
      child: Stack(
        children: [
          Positioned(
              right: 20,
              top: 20,
              child: Icon(bgIcon,
                  size: 40,
                  color: Colors.red.withOpacity(0.06))), // Watermark icon
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _pill("CRITICAL", Colors.red.shade700,
                        bg: Colors.red.shade50),
                    const SizedBox(width: 12),
                    Text(time,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(desc,
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        height: 1.4)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onPrimaryPressed ?? () {},
                        icon: Icon(btnIcon, color: Colors.white, size: 18),
                        label: Text(btnText,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () {
                        MockControlHelper.showSimulationSnackBar(
                          context,
                          featureName: 'Opsi Lanjutan',
                          description:
                              'Menu ini akan menampilkan opsi tambahan seperti eskalasi ke tim lapangan, penjadwalan maintenance, dan riwayat alert.',
                        );
                      },
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(color: Colors.grey.shade400)),
                      child:
                          const Icon(Icons.more_horiz, color: Colors.black87),
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

  Widget _mobileWarningCard(
      String title, String desc, String time, String btnText,
      {VoidCallback? onPressed}) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
            left: BorderSide(color: Colors.orange.shade500, width: 4),
            top: BorderSide(color: Colors.grey.shade200),
            right: BorderSide(color: Colors.grey.shade200),
            bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pill("WARNING", Colors.orange.shade800,
                  bg: Colors.orange.shade50),
              const SizedBox(width: 12),
              Text(time,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(desc,
              style: TextStyle(
                  color: Colors.grey.shade700, fontSize: 14, height: 1.4)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onPressed ?? () {},
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: Colors.grey.shade400)),
              child: Text(btnText,
                  style: const TextStyle(
                      color: Colors.black87, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _mobileInfoCard(String title, String desc, String time) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
            left: BorderSide(color: Colors.blue.shade400, width: 4),
            top: BorderSide(color: Colors.grey.shade200),
            right: BorderSide(color: Colors.grey.shade200),
            bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _pill("INFO", Colors.blue.shade700, bg: Colors.blue.shade50),
              const SizedBox(width: 12),
              Text(time,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(desc,
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }

  // Widget utilitas kecil untuk tag/badge
  Widget _pill(String text, Color textColor, {Color? bg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg ?? textColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(
              color: textColor, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}
