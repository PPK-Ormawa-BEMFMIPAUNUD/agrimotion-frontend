import 'package:flutter/material.dart';

class DailyExtremesCard extends StatelessWidget {
  final Map<String, dynamic>? extremes;
  final Map<String, dynamic>? npkTrends;
  final bool isLoading;

  const DailyExtremesCard({
    super.key,
    required this.extremes,
    required this.npkTrends,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || extremes == null || npkTrends == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ekstrem & Tren Harian',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.5,
              children: [
                _buildStatItem('Suhu (°C)', extremes!['temperature']?['avg']?.toStringAsFixed(1) ?? '-', Icons.thermostat),
                _buildStatItem('Kelembapan (%)', extremes!['moisture']?['avg']?.toStringAsFixed(1) ?? '-', Icons.water_drop),
                _buildNpkTrendItem('Nitrogen', npkTrends!['n']?['trend'] ?? 'statis', npkTrends!['n']?['value'] ?? 0),
                _buildNpkTrendItem('Fosfor', npkTrends!['p']?['trend'] ?? 'statis', npkTrends!['p']?['value'] ?? 0),
                _buildNpkTrendItem('Kalium', npkTrends!['k']?['trend'] ?? 'statis', npkTrends!['k']?['value'] ?? 0),
                _buildStatItem('pH', extremes!['ph']?['avg']?.toStringAsFixed(1) ?? '-', Icons.science),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildNpkTrendItem(String label, String trend, num value) {
    IconData icon;
    Color color;
    if (trend == 'naik') {
      icon = Icons.trending_up;
      color = Colors.green;
    } else if (trend == 'turun') {
      icon = Icons.trending_down;
      color = Colors.red;
    } else {
      icon = Icons.trending_flat;
      color = Colors.orange;
    }

    return Row(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('${value.toStringAsFixed(1)} mg/kg', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
