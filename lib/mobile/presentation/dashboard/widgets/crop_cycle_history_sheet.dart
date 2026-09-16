import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/crop_cycle_model.dart';
import '../../../../core/services/crop_cycle_service.dart';

class CropCycleHistorySheet extends StatefulWidget {
  final int demplotId;
  final String demplotName;

  const CropCycleHistorySheet({
    super.key,
    required this.demplotId,
    required this.demplotName,
  });

  @override
  State<CropCycleHistorySheet> createState() => _CropCycleHistorySheetState();
}

class _CropCycleHistorySheetState extends State<CropCycleHistorySheet> {
  final _service = CropCycleService();
  late Future<List<CropCycleModel>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _service.fetchHistory(widget.demplotId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Text(
            'Riwayat Panen - ${widget.demplotName}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<CropCycleModel>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Gagal memuat riwayat panen.'));
                }
                
                final cycles = snapshot.data ?? [];
                if (cycles.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada riwayat panen pada demplot ini.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: cycles.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final cycle = cycles[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                cycle.commodityName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${cycle.yieldKg ?? '-'} Kg',
                                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Tanam: ${cycle.formattedPlantingDate} • Panen: ${cycle.formattedHarvestDate}',
                               style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          Text('Lama Siklus: ${cycle.durationDays ?? '-'} Hari',
                               style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          if (cycle.notes != null && cycle.notes!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(cycle.notes!, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
