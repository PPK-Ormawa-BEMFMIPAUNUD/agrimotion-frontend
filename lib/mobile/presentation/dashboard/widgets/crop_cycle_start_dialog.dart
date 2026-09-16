import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/crop_cycle_service.dart';
import '../../../../core/network/api_client.dart';

class CropCycleStartDialog extends StatefulWidget {
  final int demplotId;
  final String demplotName;
  final VoidCallback onSuccess;

  const CropCycleStartDialog({
    super.key,
    required this.demplotId,
    required this.demplotName,
    required this.onSuccess,
  });

  @override
  State<CropCycleStartDialog> createState() => _CropCycleStartDialogState();
}

class _CropCycleStartDialogState extends State<CropCycleStartDialog> {
  final _formKey = GlobalKey<FormState>();
  final _commodityController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime _plantingDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default commodity based on demplotId
    if (widget.demplotId == 0) _commodityController.text = 'Bunga Pacah Air';
    else if (widget.demplotId == 1) _commodityController.text = 'Sawi Organik';
    else if (widget.demplotId == 2) _commodityController.text = 'Cabai Rawit';
  }

  Future<void> _selectPlantingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plantingDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _plantingDate) {
      setState(() {
        _plantingDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final service = CropCycleService();
      // Calculate target harvest date
      int days = 60;
      if (widget.demplotId == 1) days = 35;
      if (widget.demplotId == 2) days = 90;
      
      final targetHarvest = _plantingDate.add(Duration(days: days));

      await service.startCropCycle(
        demplotId: widget.demplotId,
        commodityName: _commodityController.text,
        plantingDate: _plantingDate,
        targetHarvestDate: targetHarvest,
        notes: _notesController.text,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mulai Tanam Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lokasi: ${widget.demplotName}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _commodityController,
                decoration: const InputDecoration(
                  labelText: 'Komoditas',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Komoditas wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              const Text('Tanggal Tanam', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              InkWell(
                onTap: _selectPlantingDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_plantingDate.day}/${_plantingDate.month}/${_plantingDate.year}'),
                      const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Catatan Awal (Opsional)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Konfirmasi', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
