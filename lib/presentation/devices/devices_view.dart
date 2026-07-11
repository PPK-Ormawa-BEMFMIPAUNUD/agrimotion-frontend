import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class DevicesView extends StatelessWidget {
  const DevicesView({super.key});

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
    final List<Map<String, dynamic>> desktopData = [
      {
        "type": "SOIL MOISTURE NODE",
        "name": "Blok A - Sektor 1",
        "location": "Lahan Utama",
        "battery": "85%",
        "lastSync": "2 mnt lalu",
        "isOnline": true
      },
      {
        "type": "WEATHER STATION",
        "name": "Pusat Pompa Air",
        "location": "Gudang Utara",
        "battery": "5%",
        "lastSync": "14 jam lalu",
        "isOnline": false
      },
      {
        "type": "IRRIGATION VALVE",
        "name": "Blok B - Katup 3",
        "location": "Lahan Sekunder",
        "battery": "AC Power",
        "lastSync": "1 mnt lalu",
        "isOnline": true
      }
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Manajemen Perangkat",
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("Pantau dan kelola semua node sensor IoT di lapangan.",
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text("Tambah Perangkat",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
              ),
            ],
          ),
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 400,
                mainAxisExtent: 220,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24),
            itemCount: desktopData.length,
            itemBuilder: (context, index) =>
                _buildDesktopCard(desktopData[index]),
          )
        ],
      ),
    );
  }

  Widget _buildDesktopCard(Map<String, dynamic> data) {
    final bool isOnline = data['isOnline'];
    final Color statusColor = isOnline ? AppTheme.primaryColor : Colors.red;
    final Color bgColor =
        isOnline ? Colors.white : Colors.red.shade50.withOpacity(0.5);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border(
            left: BorderSide(color: statusColor, width: 6),
            top: BorderSide(
                color: isOnline ? Colors.grey.shade200 : Colors.red.shade200),
            right: BorderSide(
                color: isOnline ? Colors.grey.shade200 : Colors.red.shade200),
            bottom: BorderSide(
                color: isOnline ? Colors.grey.shade200 : Colors.red.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(data['type'],
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isOnline ? Colors.grey : Colors.red)),
                    _buildStatusChip(isOnline),
                  ],
                ),
                const SizedBox(height: 8),
                Text(data['name'],
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: isOnline ? Colors.grey.shade200 : Colors.red.shade100),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Lokasi",
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 14,
                              color: isOnline
                                  ? Colors.grey.shade700
                                  : Colors.red.shade700),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(data['location'],
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis)),
                        ],
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Baterai",
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                              data['battery'] == 'AC Power'
                                  ? Icons.electrical_services
                                  : (isOnline
                                      ? Icons.battery_full
                                      : Icons.battery_alert),
                              size: 14,
                              color: isOnline
                                  ? AppTheme.primaryColor
                                  : Colors.red),
                          const SizedBox(width: 4),
                          Text(data['battery'],
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isOnline
                                      ? Colors.black87
                                      : Colors.red.shade700)),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 12, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Sync: ${data['lastSync']}",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isOnline ? Colors.grey : Colors.red)),
                if (isOnline)
                  TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.settings,
                          size: 14, color: AppTheme.primaryColor),
                      label: const Text("Konfigurasi",
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold)))
                else
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.refresh,
                        size: 14, color: Colors.white),
                    label: const Text("Ping",
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6))),
                  )
              ],
            ),
          )
        ],
      ),
    );
  }

  // ==========================================================================
  // TATA LETAK MOBILE
  // ==========================================================================
  Widget _buildMobileLayout() {
    final List<Map<String, dynamic>> mobileData = [
      {
        "name": "Node Alpha-1",
        "location": "North Field, Sector A",
        "battery": "92%",
        "lastSync": "2 mins ago",
        "isOnline": true
      },
      {
        "name": "Node Beta-2",
        "location": "South Orchard",
        "battery": "78%",
        "lastSync": "5 mins ago",
        "isOnline": true
      },
      {
        "name": "Node Gamma-3",
        "location": "West Valley",
        "battery": "12%",
        "lastSync": "4 hrs ago",
        "isOnline": false
      }
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Devices",
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937))),
          const SizedBox(height: 4),
          const Text("Manage and monitor sensor nodes.",
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("4 ACTIVE NODES",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey)),
              Row(
                children: [
                  const Icon(Icons.filter_list,
                      size: 18, color: AppTheme.primaryColor),
                  const SizedBox(width: 4),
                  const Text("Filter",
                      style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: mobileData.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) =>
                _buildMobileCard(mobileData[index]),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildMobileCard(Map<String, dynamic> data) {
    final bool isOnline = data['isOnline'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isOnline ? Colors.white : const Color(0xFFFFF8F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isOnline ? Colors.grey.shade300 : Colors.red, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['name'],
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              _buildStatusChip(isOnline),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(data['location'],
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade200, height: 1, thickness: 1.5),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("BATTERY",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                            isOnline ? Icons.battery_full : Icons.battery_alert,
                            size: 16,
                            color:
                                isOnline ? AppTheme.primaryColor : Colors.red),
                        const SizedBox(width: 6),
                        Text(data['battery'],
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isOnline ? Colors.black87 : Colors.red)),
                      ],
                    )
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("LAST SYNC",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.sync,
                            size: 16,
                            color:
                                isOnline ? Colors.grey.shade700 : Colors.red),
                        const SizedBox(width: 6),
                        Text(data['lastSync'],
                            style: TextStyle(
                                fontSize: 14,
                                color: isOnline ? Colors.black87 : Colors.red)),
                      ],
                    )
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatusChip(bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: isOnline ? Colors.green.shade100 : Colors.red.shade100,
          borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOnline ? Icons.wifi : Icons.wifi_off,
              size: 12,
              color: isOnline ? Colors.green.shade800 : Colors.red.shade800),
          const SizedBox(width: 4),
          Text(isOnline ? "Online" : "Offline",
              style: TextStyle(
                  color: isOnline ? Colors.green.shade800 : Colors.red.shade800,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
