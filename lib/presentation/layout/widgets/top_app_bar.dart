import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/mock_control_helper.dart';

class TopAppBar extends StatelessWidget {
  const TopAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Ringkasan Sistem",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                "Pemantauan telemetri real-time",
                style: TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 280,
            height: 38,
            child: TextField(
              decoration: InputDecoration(
                hintText: "Cari perangkat, peringatan...",
                hintStyle:
                    const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppTheme.primaryColor, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          _actionIconBtn(
            icon: Icons.help_outline_rounded,
            tooltip: 'Panduan',
            onTap: () {
              MockControlHelper.showSimulationDialog(
                context,
                title: 'Bantuan & Panduan',
                description:
                    'AGRI-MOTION adalah sistem pemantauan IoT presisi untuk pertanian. '
                    'Dashboard menampilkan data real-time dari sensor ESP32 di lapangan. '
                    'Gunakan menu navigasi untuk mengakses perangkat, analitik, notifikasi, dan pengaturan.',
                icon: Icons.help_outline,
              );
            },
          ),
          const SizedBox(width: 8),
          _actionIconBtn(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifikasi',
            onTap: () {
              MockControlHelper.showSimulationSnackBar(
                context,
                featureName: 'Pusat Notifikasi',
                description:
                    'Menampilkan notifikasi real-time dari sensor lapangan.',
              );
            },
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.primaryColor,
                  child:
                      const Icon(Icons.person, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Text(
                  "Petani Utama",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionIconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Icon(icon, size: 19, color: const Color(0xFF475569)),
      ),
    );
  }
}
