import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/analytics_model.dart';

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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Catat Aktivitas Budidaya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'Jenis Aktivitas', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'WATERING', child: Text('Penyiraman')),
                      DropdownMenuItem(value: 'FERTILIZATION', child: Text('Pemupukan')),
                      DropdownMenuItem(value: 'SPRAYING', child: Text('Penyemprotan')),
                    ],
                    onChanged: (val) {
                      setStateModal(() {
                        selectedType = val!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedType == 'WATERING' || selectedType == 'FERTILIZATION' || selectedType == 'SPRAYING')
                    TextField(
                      controller: volumeController,
                      decoration: const InputDecoration(labelText: 'Volume (Liter)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  const SizedBox(height: 12),
                  if (selectedType == 'FERTILIZATION' || selectedType == 'SPRAYING') ...[
                    TextField(
                      controller: substanceController,
                      decoration: const InputDecoration(labelText: 'Nama Bahan/Pupuk', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dosageController,
                      decoration: const InputDecoration(labelText: 'Dosis/Takaran', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: 'Catatan (Opsional)', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final payload = {
                          'demplotId': widget.demplotId,
                          'type': selectedType,
                          'volumeLiter': double.tryParse(volumeController.text),
                          'substanceName': substanceController.text.isNotEmpty ? substanceController.text : null,
                          'dosage': dosageController.text.isNotEmpty ? dosageController.text : null,
                          'notes': notesController.text.isNotEmpty ? notesController.text : null,
                        };
                        widget.onActivityCreated(payload);
                        Navigator.pop(context);
                      },
                      child: const Text('Simpan'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
            const Text(
              'Log Aktivitas Budidaya',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _showAddActivityModal,
              icon: const Icon(Icons.add),
              label: const Text('Catat'),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
          const Center(child: CircularProgressIndicator())
        else if (widget.activities.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('Belum ada log aktivitas.'),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.activities.length,
            itemBuilder: (context, index) {
              final act = widget.activities[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[50],
                    child: Text(
                      act.type == 'WATERING' ? '💧' : act.type == 'FERTILIZATION' ? '🧪' : '🌿',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  title: Text(act.type),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('dd MMM yyyy HH:mm').format(act.executedAt)),
                      if (act.volumeLiter != null) Text('Volume: ${act.volumeLiter} L'),
                      if (act.substanceName != null) Text('Bahan: ${act.substanceName} (${act.dosage})'),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
