import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/crop_cycle_model.dart';
import 'crop_cycle_start_dialog.dart';
import 'crop_cycle_harvest_dialog.dart';
import 'crop_cycle_history_sheet.dart';

class CropCycleBanner extends StatelessWidget {
  final CropCycleModel? activeCycle;
  final int demplotId;
  final String demplotName;
  final VoidCallback onStateChanged;

  const CropCycleBanner({
    super.key,
    required this.activeCycle,
    required this.demplotId,
    required this.demplotName,
    required this.onStateChanged,
  });

  void _showStartDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CropCycleStartDialog(
        demplotId: demplotId,
        demplotName: demplotName,
        onSuccess: onStateChanged,
      ),
    );
  }

  void _showHarvestDialog(BuildContext context) {
    if (activeCycle == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CropCycleHarvestDialog(
        cycle: activeCycle!,
        demplotName: demplotName,
        onSuccess: onStateChanged,
      ),
    );
  }

  void _showHistorySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CropCycleHistorySheet(
        demplotId: demplotId,
        demplotName: demplotName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (activeCycle != null) {
      return _buildActiveState(context);
    } else {
      return _buildIdleState(context);
    }
  }

  Widget _buildActiveState(BuildContext context) {
    final cycle = activeCycle!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
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
                  const Text('🌱', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    'Siklus Tanam Aktif',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  cycle.phase,
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HST: ${cycle.hst} Hari',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cycle.commodityName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (cycle.progressPercentage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: cycle.progressPercentage! / 100,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tanam: ${cycle.formattedPlantingDate}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  'Target Panen: ${cycle.formattedTargetHarvestDate}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showHarvestDialog(context),
                  icon: const Icon(Icons.shopping_basket, size: 18),
                  label: const Text('Selesaikan Panen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _showHistorySheet(context),
                icon: const Icon(Icons.history),
                tooltip: 'Riwayat Panen',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdleState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          const Icon(Icons.grass, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            'Demplot Kosong / Bera',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lahan saat ini sedang tidak ditanami atau sedang dalam masa istirahat.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showStartDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Mulai Tanam Baru'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _showHistorySheet(context),
                icon: const Icon(Icons.history),
                tooltip: 'Riwayat Panen',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
