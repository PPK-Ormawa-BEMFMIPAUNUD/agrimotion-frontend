import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/crop_cycle_model.dart';
import '../../../../core/services/crop_cycle_service.dart';
import '../../../../core/network/api_client.dart';

class CropCycleHarvestDialog extends StatefulWidget {
  final CropCycleModel cycle;
  final String demplotName;
  final VoidCallback onSuccess;

  const CropCycleHarvestDialog({
    super.key,
    required this.cycle,
    required this.demplotName,
    required this.onSuccess,
  });

  @override
  State<CropCycleHarvestDialog> createState() => _CropCycleHarvestDialogState();
}

class _CropCycleHarvestDialogState extends State<CropCycleHarvestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _yieldController = TextEditingController();
  final _notesController = TextEditingController();
  
  DateTime _harvestDate = DateTime.now();
  bool _isLoading = false;

  Future<void> _selectHarvestDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _harvestDate,
      firstDate: widget.cycle.plantingDate,
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _harvestDate) {
      setState(() => _harvestDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final service = CropCycleService();
      final yieldVal = double.tryParse(_yieldController.text.replaceAll(',', '.'));
      
      await service.harvestCropCycle(
        id: widget.cycle.id,
        harvestDate: _harvestDate,
        yieldKg: yieldVal,
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
      title: const Text('Selesaikan Panen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apakah Anda yakin ingin menyelesaikan siklus tanam ${widget.cycle.commodityName} pada ${widget.demplotName}?',
                   style: const TextStyle(fontSize: 13, color: Colors.black87)),
              const SizedBox(height: 16),
              const Text('Tanggal Panen', style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              InkWell(
                onTap: _selectHarvestDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_harvestDate.day}/${_harvestDate.month}/${_harvestDate.year}'),
                      const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _yieldController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Hasil Panen (Kg)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  suffixText: 'Kg',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Evaluasi / Catatan Panen',
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
          child: _isLoading 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Simpan & Panen', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
