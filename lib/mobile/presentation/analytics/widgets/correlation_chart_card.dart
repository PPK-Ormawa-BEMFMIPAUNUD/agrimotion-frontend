import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/analytics_model.dart';
import '../../../../core/models/crop_cycle_model.dart';
import '../../../../shared/widgets/skeleton_loader.dart';

class CorrelationChartCard extends StatelessWidget {
  final List<CorrelationPointModel> data;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final CropCycleModel? activeCropCycle;

  const CorrelationChartCard({
    super.key,
    required this.data,
    required this.isLoading,
    this.errorMessage,
    required this.onRetry,
    this.activeCropCycle,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Korelasi Kelembaban & Suhu",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Tren mikroklimat",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_vert, color: Colors.grey.shade600),
            ],
          ),
          
          if (activeCropCycle != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Text('🌱', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Siklus: ${activeCropCycle!.commodityName} • Ditanam: ${activeCropCycle!.formattedPlantingDate} • ${activeCropCycle!.hst} Hari (${activeCropCycle!.phase})',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Legends
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(AppTheme.primaryColor, 'Kelembaban (%)', false),
              const SizedBox(width: 24),
              _buildLegend(Colors.orangeAccent, 'Suhu (°C)', true),
            ],
          ),
          const SizedBox(height: 24),

          // Chart Area
          SizedBox(
            height: 280,
            width: double.infinity,
            child: _buildChartContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text, bool isDashed) {
    return Row(
      children: [
        if (isDashed)
          SizedBox(
            width: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(width: 4, height: 2, color: color),
                Container(width: 4, height: 2, color: color),
                Container(width: 4, height: 2, color: color),
              ],
            ),
          )
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildChartContent() {
    if (isLoading) {
      return const SkeletonLoader(
        width: double.infinity,
        height: double.infinity,
        borderRadius: 8,
      );
    }

    if (errorMessage != null) {
      final is400 = errorMessage!.contains('400') || errorMessage!.contains('skema');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              is400 ? Icons.info_outline : Icons.error_outline,
              color: is400 ? Colors.grey.shade600 : Colors.redAccent,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              is400
                  ? 'Data telemetri korelasi belum tersedia untuk demplot ini.'
                  : errorMessage!,
              style: TextStyle(
                fontSize: 12,
                color: is400 ? Colors.grey.shade700 : Colors.redAccent,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('Coba Lagi', style: TextStyle(color: AppTheme.primaryColor)),
            ),
          ],
        ),
      );
    }

    if (data.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada data korelasi untuk periode ini.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    final spotsMoisture = <FlSpot>[];
    final spotsTemperature = <FlSpot>[];

    for (int i = 0; i < data.length; i++) {
      spotsMoisture.add(FlSpot(i.toDouble(), data[i].soilMoisture));
      spotsTemperature.add(FlSpot(i.toDouble(), data[i].temperature));
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16, left: 16),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (data.length > 1 ? data.length - 1 : 1).toDouble(),
          minY: 0,
          maxY: 100, // Kelembaban 0-100%, Suhu 0-40 (kita scale di UI atau pake min-max sama)
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final textStyle = const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  );
                  final isTemp = touchedSpot.barIndex == 1;
                  return LineTooltipItem(
                    '${touchedSpot.y.toStringAsFixed(1)}${isTemp ? '°C' : '%'}',
                    textStyle,
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < data.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        data[index].label,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text(
                'Kelembaban (%)',
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
              axisNameSize: 20,
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                    textAlign: TextAlign.right,
                  );
                },
              ),
            ),
            rightTitles: AxisTitles(
              axisNameWidget: const Text(
                'Suhu (°C)',
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
              axisNameSize: 20,
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                reservedSize: 36,
                getTitlesWidget: (value, meta) {
                  return Text(
                    (value * 0.4).toStringAsFixed(1), // Scale 0-100 to 0-40
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                    textAlign: TextAlign.left,
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // Kelembaban Tanah
            LineChartBarData(
              spots: spotsMoisture,
              isCurved: true,
              color: AppTheme.primaryColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primaryColor.withOpacity(0.15),
              ),
            ),
            // Suhu
            LineChartBarData(
              // Scale suhu (misal max 40°C) menjadi skala chart (100) -> Y_Chart = Y_Temp / 0.4
              spots: spotsTemperature.map((e) => FlSpot(e.x, e.y / 0.4)).toList(),
              isCurved: true,
              color: Colors.orangeAccent,
              barWidth: 2,
              isStrokeCapRound: true,
              dashArray: [5, 5],
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}
