import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../../../core/models/sensor_data.dart';
import '../../../../core/models/ews_status_model.dart';
import '../../../../core/config/demplot_config.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/services/sensor_service.dart';
import '../../../../core/utils/actuation_calculator.dart';

class DssActuationDialog extends StatefulWidget {
  final Demplot demplot;
  final DeviceNode device;
  final SensorData? sensorData;
  final ActuationType type;
  final EwsStatusModel? ewsStatus;
  final Function(double) onConfirm;

  const DssActuationDialog({
    super.key,
    required this.demplot,
    required this.device,
    required this.sensorData,
    required this.type,
    this.ewsStatus,
    required this.onConfirm,
  });

  @override
  State<DssActuationDialog> createState() => _DssActuationDialogState();
}

class _DssActuationDialogState extends State<DssActuationDialog> {
  late TextEditingController _controller;
  late DssRecommendation _recommendation;
  double? _currentValue;
  EwsValidationResult _validation = const EwsValidationResult.valid();
  int _estimatedSeconds = 0;
  bool _isLoadingDss = false;
  String? _sourceTag;
  
  EwsStatusModel? _ewsStatus;

  bool get _isPesticideLocked {
    if (widget.type != ActuationType.pesticide) return false;
    if (_ewsStatus != null) {
      return !_ewsStatus!.pesticideAllowed;
    }
    // Fallback if offline: calculate HST for Demplot Sawi
    final demplotIndex = DemplotConfig.demplots.indexOf(widget.demplot);
    if (demplotIndex == 1) {
      final plantingDate = DateTime.utc(2026, 8, 9);
      final now = DateTime.now().toUtc();
      final hst = now.difference(plantingDate).inDays + 1;
      if (hst >= 35) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    final demplotIndex = DemplotConfig.demplots.indexOf(widget.demplot);
    _ewsStatus = widget.ewsStatus;

    // Inisialisasi awal menggunakan fallback kalkulator lokal
    _recommendation = ActuationCalculator.getRecommendation(
        demplotIndex, widget.type, widget.sensorData);

    _currentValue = _recommendation.recommendedValue;
    _controller = TextEditingController(text: _currentValue.toString());

    _controller.addListener(_onInputChanged);
    _validateAndUpdateEstimation();

    // Jika aktuasi berupa pupuk, ambil rekomendasi presisi ML dari Backend
    if (widget.type == ActuationType.fertilizer) {
      _fetchBackendDssRecommendation(demplotIndex);
    }
    
    if (widget.type == ActuationType.pesticide) {
      _fetchBackendEwsStatus(demplotIndex);
    }
  }

  Future<void> _fetchBackendEwsStatus(int demplotIndex) async {
    try {
      final sensorService = SensorService();
      final status = await sensorService.fetchEwsStatus(demplotIndex);
      if (mounted) {
        setState(() {
          _ewsStatus = status;
        });
      }
    } catch (_) {
      // Ignored, handled by service fallback
    }
  }

  Future<void> _fetchBackendDssRecommendation(int demplotIndex) async {
    setState(() => _isLoadingDss = true);

    try {
      // Menggunakan Base URL API aplikasi
      final url = Uri.parse(
          '${ApiConfig.baseUrl}/api/dss/recommendation/$demplotIndex');
      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final data = jsonResponse['data'];

          final double val =
              (data['recommendedValue'] ?? data['recommendedGrams'] as num)
                  .toDouble();
          final String reason =
              data['reason'] ?? 'Rekomendasi model Machine Learning DSS';
          final String summary = data['sensorSummary']?.toString() ??
              _recommendation.sensorSummary;

          if (mounted) {
            setState(() {
              _recommendation = DssRecommendation(
                recommendedValue: val,
                reason: reason,
                sensorSummary: summary,
              );
              _currentValue = val;
              _controller.text = val.toString();
              _sourceTag = data['source'] == 'ml_model'
                  ? 'AI / ML Model'
                  : 'Standar Agronomi';
              _validateAndUpdateEstimation();
            });
          }
        }
      }
    } catch (_) {
      // Jika jaringan/backend error, tetap gunakan kalkulator lokal tanpa interupsi
      if (mounted) {
        setState(() => _sourceTag = 'Offline Fallback');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingDss = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    setState(() {
      _currentValue = double.tryParse(_controller.text);
      _validateAndUpdateEstimation();
    });
  }

  void _validateAndUpdateEstimation() {
    if (_currentValue == null) {
      _validation = const EwsValidationResult.error(
          'Input tidak valid', 'Mohon masukkan angka dosis yang benar.');
      _estimatedSeconds = 0;
      return;
    }

    _validation = ActuationCalculator.validateActuation(
        widget.type, _currentValue!, widget.sensorData);

    if (_validation.isValid) {
      final demplotIndex = DemplotConfig.demplots.indexOf(widget.demplot);
      _estimatedSeconds = ActuationCalculator.calculateDurationSeconds(
          demplotIndex, widget.type, _currentValue!);
    } else {
      _estimatedSeconds = 0;
    }
  }

  void _resetToRecommendation() {
    _controller.text = _recommendation.recommendedValue.toString();
  }

  @override
  Widget build(BuildContext context) {
    IconData typeIcon;
    Color typeColor;

    switch (widget.type) {
      case ActuationType.fertilizer:
        typeIcon = Icons.eco;
        typeColor = const Color(0xFF0F7646);
        break;
      case ActuationType.pesticide:
        typeIcon = Icons.shield;
        typeColor = const Color(0xFFD97706);
        break;
      case ActuationType.water:
        typeIcon = Icons.water_drop;
        typeColor = const Color(0xFF0284C7);
        break;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(typeIcon, color: typeColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kontrol DSS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: typeColor,
                          ),
                        ),
                        Text(
                          widget.type.label,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Status Lahan Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics_outlined,
                            size: 16, color: Color(0xFF475569)),
                        const SizedBox(width: 6),
                        const Text(
                          'Kondisi Lahan Terkini',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.device.label,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSensorBadge(
                            'Air',
                            widget.sensorData?.soilMoisture != null
                                ? '${widget.sensorData!.soilMoisture!.toStringAsFixed(1)}%'
                                : '-'),
                        _buildSensorBadge(
                            'Suhu',
                            widget.sensorData?.temperature != null
                                ? '${widget.sensorData!.temperature!.toStringAsFixed(1)}°C'
                                : '-'),
                        _buildSensorBadge(
                            'NPK', widget.sensorData?.npkDisplay ?? '-'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // DSS Recommendation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: typeColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 18, color: typeColor),
                        const SizedBox(width: 8),
                        Text(
                          'Rekomendasi Sistem',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: typeColor,
                          ),
                        ),
                        const Spacer(),
                        if (_isLoadingDss)
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: typeColor),
                          )
                        else if (_sourceTag != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _sourceTag!,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: typeColor),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_recommendation.recommendedValue} ${widget.type.fullUnit}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _recommendation.reason,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Input Manual
              const Text(
                'Atur Dosis Fisik',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _controller,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d*')),
                      ],
                      decoration: InputDecoration(
                        suffixText: widget.type.shortUnit,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: typeColor, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _resetToRecommendation,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Estimasi Durasi or EWS Warning
              if (!_validation.isValid)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _validation.errorMessage ?? 'Tidak valid',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _validation.riskDescription ?? '',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF7F1D1D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else if (_estimatedSeconds > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 14, color: typeColor),
                      const SizedBox(width: 6),
                      Text(
                        'Estimasi Pompa Aktif: ${ActuationCalculator.formatDuration(_estimatedSeconds)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: typeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              
              if (widget.type == ActuationType.pesticide && _ewsStatus != null) ...[
                const SizedBox(height: 16),
                if (!_ewsStatus!.pesticideAllowed)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.block, color: Color(0xFFDC2626), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Safety Lock Aktif: Masa panen tiba (>= 35 HST). Penyemprotan pestisida dilarang untuk menjaga keamanan pangan bebas residu kimia.',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_ewsStatus!.isSafe)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF38BDF8)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF0284C7), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Kondisi iklim saat ini aman. Penyemprotan pestisida terjadwal belum mendesak.',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF075985),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Peringatan EWS: ${_ewsStatus!.actionRecommendation}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              // Offline fallback lock banner if EWS is null but it's Sawi and HST >= 35
              if (widget.type == ActuationType.pesticide && _ewsStatus == null && _isPesticideLocked) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.block, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Safety Lock Aktif (Offline): Masa panen tiba (>= 35 HST). Penyemprotan pestisida dilarang untuk menjaga keamanan pangan bebas residu kimia.',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: (_validation.isValid && !_isPesticideLocked)
                        ? () {
                            Navigator.pop(context);
                            widget.onConfirm(_currentValue!);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: typeColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('Mulai ${widget.type.label}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorBadge(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
