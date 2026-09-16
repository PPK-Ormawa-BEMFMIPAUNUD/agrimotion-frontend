import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/analytics_model.dart';
import '../../../core/services/sensor_service.dart';
import '../../../core/utils/analytics_pdf_generator.dart';
import '../../../core/models/crop_cycle_model.dart';
import '../../../core/services/crop_cycle_service.dart';
import 'widgets/correlation_chart_card.dart';
import 'widgets/water_usage_demplot_card.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  String _selectedPeriod = 'week';
  final int _demplotId = 0; // Menggunakan Demplot 1 sebagai default
  final String _demplotName = 'Demplot 1';
  final SensorService _sensorService = SensorService();
  final CropCycleService _cropCycleService = CropCycleService();

  bool _isOverviewLoading = true;
  bool _isCorrelationLoading = true;
  bool _isWaterUsageLoading = true;

  String? _overviewError;
  String? _correlationError;
  String? _waterUsageError;

  AnalyticsOverviewModel? _overviewData;
  List<CorrelationPointModel> _correlationData = [];
  WaterUsageAnalyticsModel? _waterUsageData;
  CropCycleModel? _activeCropCycle;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    _fetchCropCycle();
    _fetchOverview();
    _fetchCorrelation();
    _fetchWaterUsage();
  }

  Future<void> _fetchCropCycle() async {
    try {
      final cycle = await _cropCycleService.fetchActiveCycle(_demplotId);
      if (mounted) {
        setState(() => _activeCropCycle = cycle);
      }
    } catch (_) {}
  }

  Future<void> _fetchOverview() async {
    setState(() {
      _isOverviewLoading = true;
      _overviewError = null;
    });
    try {
      final data = await _sensorService.fetchAnalyticsOverview(_demplotId, _selectedPeriod);
      setState(() {
        _overviewData = data;
        _isOverviewLoading = false;
      });
    } catch (e) {
      setState(() {
        _overviewError = e.toString();
        _isOverviewLoading = false;
      });
    }
  }

  Future<void> _fetchCorrelation() async {
    setState(() {
      _isCorrelationLoading = true;
      _correlationError = null;
    });
    try {
      final data = await _sensorService.fetchCorrelationAnalytics(_demplotId, _selectedPeriod);
      setState(() {
        _correlationData = data;
        _isCorrelationLoading = false;
      });
    } catch (e) {
      setState(() {
        _correlationError = e.toString();
        _isCorrelationLoading = false;
      });
    }
  }

  Future<void> _fetchWaterUsage() async {
    setState(() {
      _isWaterUsageLoading = true;
      _waterUsageError = null;
    });
    try {
      final data = await _sensorService.fetchWaterUsageAnalytics(_selectedPeriod);
      setState(() {
        _waterUsageData = data;
        _isWaterUsageLoading = false;
      });
    } catch (e) {
      setState(() {
        _waterUsageError = e.toString();
        _isWaterUsageLoading = false;
      });
    }
  }

  Future<void> _exportData() async {
    if (_overviewData == null || _waterUsageData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tunggu hingga semua data selesai dimuat sebelum ekspor.')),
      );
      return;
    }

    try {
      await AnalyticsPdfGenerator.generateAndPrintReport(
        demplotName: _demplotName,
        period: _selectedPeriod,
        overview: _overviewData!,
        waterUsage: _waterUsageData!,
        activeCropCycle: _activeCropCycle,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat laporan PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _sensorService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(constraints.maxWidth),
              const SizedBox(height: 24),
              _buildKpiGrid(constraints.maxWidth),
              const SizedBox(height: 24),
              _buildChartsRow(constraints.maxWidth),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================================
  // 1. HEADER SECTION
  // ==========================================================================
  Widget _buildHeader(double maxWidth) {
    final isMobile = maxWidth < 700;

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          "Analisis Data Historis",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 4),
        Text(
          "Tinjau tren mikroklimat dan ekspor laporan berkala.",
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );

    final actionRow = Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSegmentButton("Hari", 'day'),
              Container(width: 1, height: 20, color: Colors.grey.shade300),
              _buildSegmentButton("Minggu", 'week'),
              Container(width: 1, height: 20, color: Colors.grey.shade300),
              _buildSegmentButton("Bulan", 'month'),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _exportData,
          icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.redAccent),
          label: const Text(
            "Ekspor PDF",
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            side: BorderSide(color: Colors.grey.shade300),
            backgroundColor: Colors.white,
          ),
        )
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleColumn,
          const SizedBox(height: 16),
          actionRow,
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: titleColumn),
          const SizedBox(width: 16),
          actionRow,
        ],
      );
    }
  }

  Widget _buildSegmentButton(String label, String value) {
    final isActive = _selectedPeriod == value;
    return InkWell(
      onTap: () {
        if (!isActive) {
          setState(() {
            _selectedPeriod = value;
          });
          _fetchAllData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.green.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppTheme.primaryColor : Colors.grey.shade700,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // 2. KPI GRID SECTION
  // ==========================================================================
  Widget _buildKpiGrid(double maxWidth) {
    if (_isOverviewLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }
    if (_overviewError != null) {
      return Center(
        child: Text(
          _overviewError!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final data = _overviewData;
    if (data == null) return const SizedBox.shrink();

    // Responsif: Tentukan jumlah kolom
    int crossAxisCount = 4;
    if (maxWidth < 600) {
      crossAxisCount = 1;
    } else if (maxWidth < 900) {
      crossAxisCount = 2;
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.2, // Adjust card height
      children: [
        _kpiCard(
          title: "RATA-RATA KELEMBABAN",
          value: "${data.avgSoilMoisture.toStringAsFixed(1)}%",
          subtitle: "Rata-rata periode ini",
          icon: Icons.water_drop_outlined,
          iconColor: AppTheme.primaryColor,
        ),
        _kpiCard(
          title: "RATA-RATA SUHU",
          value: "${data.avgTemperature.toStringAsFixed(1)}°C",
          subtitle: "Rata-rata periode ini",
          icon: Icons.thermostat_outlined,
          iconColor: Colors.red,
        ),
        _kpiCard(
          title: "INDEKS NUTRISI NPK",
          value: data.avgNpkIndex.toStringAsFixed(1),
          subtitle: "mg/kg",
          icon: Icons.science_outlined,
          iconColor: Colors.purple,
        ),
        _kpiCard(
          title: "SAMPEL DATA",
          value: "${data.totalSamples}",
          subtitle: "Data log diproses",
          icon: Icons.analytics_outlined,
          iconColor: Colors.orange,
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 3. CHARTS SECTION
  // ==========================================================================
  Widget _buildChartsRow(double maxWidth) {
    final correlationCard = CorrelationChartCard(
      data: _correlationData,
      isLoading: _isCorrelationLoading,
      errorMessage: _correlationError,
      onRetry: _fetchCorrelation,
      activeCropCycle: _activeCropCycle,
    );

    final waterUsageCard = WaterUsageDemplotCard(
      data: _waterUsageData,
      isLoading: _isWaterUsageLoading,
      errorMessage: _waterUsageError,
      onRetry: _fetchWaterUsage,
    );

    if (maxWidth < 1100) {
      return Column(
        children: [
          correlationCard,
          const SizedBox(height: 24),
          waterUsageCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: correlationCard),
        const SizedBox(width: 24),
        Expanded(flex: 3, child: waterUsageCard),
      ],
    );
  }
}
