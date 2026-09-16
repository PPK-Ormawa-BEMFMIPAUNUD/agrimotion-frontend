import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/soil_moisture_trend_model.dart';
import '../../../../core/services/sensor_service.dart';
import '../../../../shared/widgets/skeleton_loader.dart';

class SoilMoistureTrendCard extends StatefulWidget {
  final int demplotId;
  final SensorService? sensorService;

  const SoilMoistureTrendCard({
    super.key,
    required this.demplotId,
    this.sensorService,
  });

  @override
  State<SoilMoistureTrendCard> createState() => _SoilMoistureTrendCardState();
}

class _SoilMoistureTrendCardState extends State<SoilMoistureTrendCard> {
  late final SensorService _sensorService;
  
  bool _isLoading = true;
  String? _errorMessage;
  List<SoilMoistureTrendModel> _trends = [];
  
  int? _hoveredOrSelectedIndex;

  @override
  void initState() {
    super.initState();
    _sensorService = widget.sensorService ?? SensorService();
    _fetchTrendData();
  }

  @override
  void didUpdateWidget(covariant SoilMoistureTrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.demplotId != widget.demplotId) {
      _fetchTrendData();
    }
  }

  Future<void> _fetchTrendData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hoveredOrSelectedIndex = null;
    });

    try {
      final data = await _sensorService.fetchSoilMoistureTrends(widget.demplotId, days: 7);
      if (mounted) {
        setState(() {
          _trends = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Tren Kelembaban Tanah',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Text(
              'Data historis 7 hari terakhir',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Mingguan',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 180,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final barHeight = 40.0 + (index * 15.0) % 100;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SkeletonLoader(
                width: 20,
                height: barHeight,
                borderRadius: 6,
              ),
              const SizedBox(height: 8),
              const SkeletonLoader(width: 24, height: 12, borderRadius: 4),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildErrorState() {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Gagal memuat data.',
              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _fetchTrendData,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarItem(SoilMoistureTrendModel item, int index, double containerWidth) {
    final barWidth = (containerWidth / 10).clamp(14.0, 34.0);
    // Skala 0% - 100% dipetakan ke maksimum tinggi bar (misalnya 150px)
    final double maxBarHeight = 150.0;
    
    // Pastikan bar minimal sedikit terlihat walau 0% (biar rapi)
    double calculatedHeight = (item.avgSoilMoisture / 100.0) * maxBarHeight;
    if (calculatedHeight < 4.0) calculatedHeight = 4.0;
    if (calculatedHeight > maxBarHeight) calculatedHeight = maxBarHeight;

    final isSelected = _hoveredOrSelectedIndex == index;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredOrSelectedIndex = index),
      onExit: (_) => setState(() => _hoveredOrSelectedIndex = null),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _hoveredOrSelectedIndex = isSelected ? null : index;
          });
        },
        child: Tooltip(
          message: '${item.dayName}, ${DateFormat('d MMM').format(item.date)}: ${item.avgSoilMoisture.toStringAsFixed(1)}%',
          preferBelow: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isSelected ? barWidth + 4 : barWidth,
                height: calculatedHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected 
                      ? [const Color(0xFF34D399), const Color(0xFF059669)] // highlight lighter green
                      : [const Color(0xFF10B981), const Color(0xFF059669)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.dayName,
                style: TextStyle(
                  color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartArea() {
    if (_trends.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Tidak ada data telemetri historis.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(_trends.length, (index) {
              return _buildBarItem(_trends[index], index, constraints.maxWidth);
            }),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 28),
          if (_isLoading)
            _buildLoadingState()
          else if (_errorMessage != null)
            _buildErrorState()
          else
            _buildChartArea(),
        ],
      ),
    );
  }
}
