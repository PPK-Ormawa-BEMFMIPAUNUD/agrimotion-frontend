import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/analytics_model.dart';
import '../../../../core/theme/app_theme.dart';

class TreatmentActivitySection extends StatefulWidget {
  final int demplotId;
  final List<FarmActivityModel> activities;
  final bool isLoading;
  final Function(String?) onFilterChanged;
  final Function(Map<String, dynamic>) onActivityCreated;

  const TreatmentActivitySection({
    super.key,
    required this.demplotId,
    required this.activities,
    required this.isLoading,
    required this.onFilterChanged,
    required this.onActivityCreated,
  });

  @override
  State<TreatmentActivitySection> createState() => _TreatmentActivitySectionState();
}

class _TreatmentActivitySectionState extends State<TreatmentActivitySection> {
  String _selectedFilter = 'Semua';
  final List<String> _filters = ['Semua', 'WATERING', 'FERTILIZATION', 'SPRAYING'];
  final Map<String, String> _filterLabels = {
    'Semua': 'Semua',
    'WATERING': 'Penyiraman 💧',
    'FERTILIZATION': 'Pemupukan 🧪',
    'SPRAYING': 'Penyemprotan 🌿'
  };

  void _showAddActivityModal() {
    String selectedType = 'WATERING';
    final TextEditingController volumeController = TextEditingController();
    final TextEditingController substanceController = TextEditingController();
    final TextEditingController dosageController = TextEditingController();
    final TextEditingController notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Catat Aktivitas Budidaya',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Jenis Aktivitas',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'WATERING', child: Text('💧 Penyiraman (Irigasi)')),
                        DropdownMenuItem(value: 'FERTILIZATION', child: Text('🧪 Pemupukan (Nutrisi)')),
                        DropdownMenuItem(value: 'SPRAYING', child: Text('🌿 Penyemprotan (Hama/Fungisida)')),
                      ],
                      onChanged: (val) {
                        setStateModal(() {
                          selectedType = val!;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: volumeController,
                      decoration: const InputDecoration(
                        labelText: 'Volume Air / Larutan (Liter)',
                        hintText: 'Contoh: 2.5',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.water_drop_outlined),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    if (selectedType == 'FERTILIZATION' || selectedType == 'SPRAYING') ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: substanceController,
                        decoration: InputDecoration(
                          labelText: selectedType == 'FERTILIZATION'
                              ? 'Nama Pupuk / Nutrisi'
                              : 'Nama Pestisida / Bahan',
                          hintText: selectedType == 'FERTILIZATION'
                              ? 'Contoh: NPK 16-16-16'
                              : 'Contoh: Ekstrak Daun Mimba',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.science_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: dosageController,
                        decoration: const InputDecoration(
                          labelText: 'Dosis / Takaran',
                          hintText: 'Contoh: 10 ml/L atau 5 gram/tanaman',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.scale_outlined),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Catatan Perlakuan (Opsional)',
                        hintText: 'Contoh: Pengendalian ulat atau pemupukan rutin',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          final payload = {
                            'demplotId': widget.demplotId,
                            'type': selectedType,
                            'volumeLiter': double.tryParse(volumeController.text.trim()),
                            'substanceName': substanceController.text.trim().isNotEmpty
                                ? substanceController.text.trim()
                                : null,
                            'dosage': dosageController.text.trim().isNotEmpty
                                ? dosageController.text.trim()
                                : null,
                            'notes': notesController.text.trim().isNotEmpty
                                ? notesController.text.trim()
                                : null,
                          };
                          widget.onActivityCreated(payload);
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Simpan Log Aktivitas',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Log Aktivitas Budidaya',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  'Riwayat penyiraman, pemupukan, dan penyemprotan',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showAddActivityModal,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Catat Aktivitas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(_filterLabels[filter]!),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.primaryColor : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                      widget.onFilterChanged(filter == 'Semua' ? null : filter);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        if (widget.isLoading)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (widget.activities.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 20.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada log aktivitas untuk demplot ini',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Klik "+ Catat Aktivitas" untuk mulai merekam perlakuan budidaya.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.activities.length,
            itemBuilder: (context, index) {
              final act = widget.activities[index];
              return _buildActivityCard(act);
            },
          ),
      ],
    );
  }

  Widget _buildActivityCard(FarmActivityModel act) {
    Color typeColor;
    String typeLabel;
    IconData typeIcon;

    switch (act.type.toUpperCase()) {
      case 'FERTILIZATION':
      case 'FERTILIZER':
      case 'PUPUK':
        typeColor = Colors.teal;
        typeLabel = 'Pemupukan Nutrisi';
        typeIcon = Icons.science_rounded;
        break;
      case 'SPRAYING':
      case 'PESTICIDE':
      case 'PESTI':
        typeColor = Colors.deepPurple;
        typeLabel = 'Penyemprotan Hama';
        typeIcon = Icons.pest_control_rounded;
        break;
      case 'WATERING':
      case 'WATER':
      case 'AIR':
      default:
        typeColor = Colors.blue;
        typeLabel = 'Penyiraman Irigasi';
        typeIcon = Icons.water_drop_rounded;
        break;
    }

    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(act.executedAt.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(typeIcon, color: typeColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          typeLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        Text(
                          '$formattedDate WITA',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
                if (act.volumeLiter != null && act.volumeLiter! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.opacity, size: 13, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '${act.volumeLiter!.toStringAsFixed(1)} L',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (act.substanceName != null && act.substanceName!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${act.substanceName!}${act.dosage != null && act.dosage!.isNotEmpty ? " • ${act.dosage}" : ""}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (act.notes != null && act.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      act.notes!,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
