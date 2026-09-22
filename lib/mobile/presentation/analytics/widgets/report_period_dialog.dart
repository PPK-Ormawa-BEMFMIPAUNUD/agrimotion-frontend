import 'package:flutter/material.dart';

class ReportPeriodDialog extends StatefulWidget {
  final int demplotId;
  final String demplotName;
  final String commodity;

  const ReportPeriodDialog({
    super.key,
    required this.demplotId,
    required this.demplotName,
    required this.commodity,
  });

  @override
  State<ReportPeriodDialog> createState() => _ReportPeriodDialogState();
}

class _ReportPeriodDialogState extends State<ReportPeriodDialog> {
  String _selectedPeriod = 'weekly';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buat Laporan PDF'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilih periode laporan untuk demplot ${widget.demplotName} (${widget.commodity}):',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          RadioListTile<String>(
            title: const Text('Mingguan (7 Hari Terakhir)'),
            value: 'weekly',
            groupValue: _selectedPeriod,
            onChanged: (value) => setState(() => _selectedPeriod = value!),
          ),
          RadioListTile<String>(
            title: const Text('Bulanan (30 Hari Terakhir)'),
            value: 'monthly',
            groupValue: _selectedPeriod,
            onChanged: (value) => setState(() => _selectedPeriod = value!),
          ),
          RadioListTile<String>(
            title: const Text('Satu Siklus Tanam Berjalan'),
            value: 'cycle',
            groupValue: _selectedPeriod,
            onChanged: (value) => setState(() => _selectedPeriod = value!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(_selectedPeriod);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('Buat Laporan'),
        ),
      ],
    );
  }
}
