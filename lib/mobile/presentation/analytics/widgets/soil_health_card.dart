import 'package:flutter/material.dart';

class SoilHealthCard extends StatelessWidget {
  final int score;
  final String status;
  final bool isLoading;

  const SoilHealthCard({
    super.key,
    required this.score,
    required this.status,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    Color getStatusColor() {
      if (score >= 80) return Colors.green;
      if (score >= 60) return Colors.orange;
      return Colors.red;
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
              'Indeks Kesuburan Tanah',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 8,
                        backgroundColor: Colors.grey[200],
                        color: getStatusColor(),
                      ),
                    ),
                    Text(
                      '$score',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: getStatusColor(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: getStatusColor(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Skor komposit deviasi indikator N, P, K, pH, dan kelembapan terhadap parameter ideal.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
