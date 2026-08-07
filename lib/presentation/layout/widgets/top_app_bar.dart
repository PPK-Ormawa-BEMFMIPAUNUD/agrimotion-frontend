import 'package:flutter/material.dart';
import '../../../core/utils/mock_control_helper.dart';

class TopAppBar extends StatelessWidget {
  const TopAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          const Text("Overview",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
          SizedBox(
            width: 300,
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search devices, alerts...",
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () {
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
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            onPressed: () {
              MockControlHelper.showSimulationSnackBar(
                context,
                featureName: 'Pusat Notifikasi',
                description:
                    'Di lahan, panel ini akan menampilkan notifikasi real-time dari semua sensor — '
                    'termasuk peringatan kelembaban rendah, suhu tinggi, dan status baterai perangkat.',
              );
            },
            icon: const Icon(Icons.notifications_none),
          ),
          const SizedBox(width: 8),
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
