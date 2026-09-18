import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/analytics_model.dart';
import '../../../../shared/widgets/skeleton_loader.dart';

class WaterUsageDemplotCard extends StatelessWidget {
  final WaterUsageAnalyticsModel? data;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;

  const WaterUsageDemplotCard({
    super.key,
    required this.data,
    required this.isLoading,
    this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Riwayat & Akumulasi Penyiraman Demplot",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Data penyiraman aktual per area",
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          _buildContent(context),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return Column(
        children: List.generate(
          3,
          (index) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonLoader(
              width: double.infinity,
              height: 70,
              borderRadius: 8,
            ),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      final isAuthError = errorMessage!.contains('401') ||
          errorMessage!.contains('Sesi') ||
          errorMessage!.contains('autentikasi');
      return Center(
        child: Column(
          children: [
            Icon(
              isAuthError ? Icons.lock_outline : Icons.error_outline,
              color: Colors.redAccent,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage!,
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (isAuthError)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Login Kembali'),
              )
            else
              TextButton(
                onPressed: onRetry,
                child: const Text('Coba Lagi', style: TextStyle(color: AppTheme.primaryColor)),
              ),
          ],
        ),
      );
    }

    if (data == null || data!.demplots.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada data penyiraman',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    return Column(
      children: [
        ...data!.demplots.map((d) => _buildDemplotRow(d)),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Total Volume Air",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              "${data!.totalLiters.toStringAsFixed(1)} Liter",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDemplotRow(WaterUsageDemplotModel demplot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  demplot.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  demplot.commodity,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${demplot.estimatedLiters.toStringAsFixed(1)} Liter",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Durasi: ${demplot.totalDurationSeconds} detik",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
