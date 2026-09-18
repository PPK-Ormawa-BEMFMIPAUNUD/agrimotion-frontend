import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/analytics_model.dart';
import '../../../core/services/sensor_service.dart';
import '../../../core/utils/analytics_pdf_generator.dart';
import '../../../core/models/crop_cycle_model.dart';
import '../../../core/services/crop_cycle_service.dart';
import 'widgets/soil_health_card.dart';
import 'widgets/daily_extremes_card.dart';
import 'widgets/treatment_activity_section.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  String _selectedPeriod = '7d';
  int _demplotId = 0; // Menggunakan Demplot 1 sebagai default
  String _demplotName = 'Demplot 1';
  final SensorService _sensorService = SensorService();
  final CropCycleService _cropCycleService = CropCycleService();

  bool _isOverviewLoading = true;
  bool _isDemplotAnalyticsLoading = true;
  bool _isActivitiesLoading = true;

  String? _overviewError;
  String? _demplotAnalyticsError;
  String? _activitiesError;

  AnalyticsOverviewModel? _overviewData;
  DemplotAnalyticsModel? _demplotAnalyticsData;
  List<FarmActivityModel> _activitiesData = [];
  String? _activityFilter;

  CropCycleModel? _activeCropCycle;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    _fetchCropCycle();
    _fetchOverview();
    _fetchDemplotAnalytics();
    _fetchActivities();
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
      final periodForOverview = _selectedPeriod == '7d' ? 'week' : _selectedPeriod == '30d' ? 'month' : 'week';
      final data = await _sensorService.fetchAnalyticsOverview(_demplotId, periodForOverview);
      if (mounted) {
        setState(() {
          _overviewData = data;
          _isOverviewLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _overviewError = e.toString();
          _isOverviewLoading = false;
        });
      }
    }
  }

  Future<void> _fetchDemplotAnalytics() async {
    setState(() {
      _isDemplotAnalyticsLoading = true;
      _demplotAnalyticsError = null;
    });
    try {
      final data = await _sensorService.fetchDemplotAnalytics(_demplotId, period: _selectedPeriod);
      if (mounted) {
        setState(() {
          _demplotAnalyticsData = data;
          _isDemplotAnalyticsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _demplotAnalyticsError = e.toString();
          _isDemplotAnalyticsLoading = false;
        });
      }
    }
  }

  Future<void> _fetchActivities() async {
    setState(() {
      _isActivitiesLoading = true;
      _activitiesError = null;
    });
    try {
      final data = await _sensorService.fetchActivities(demplotId: _demplotId, type: _activityFilter);
      if (mounted) {
        setState(() {
          _activitiesData = data;
          _isActivitiesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _activitiesError = e.toString();
          _isActivitiesLoading = false;
        });
      }
    }
  }

  Future<void> _exportData() async {
    if (_overviewData == null || _demplotAnalyticsData == null) {
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
        demplotAnalytics: _demplotAnalyticsData!,
        activities: _activitiesData,
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
        // Demplot Selection Tabs (Demplot 1, 2, 3)
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDemplotTabButton("Demplot 1", 0),
              Container(width: 1, height: 20, color: Colors.grey.shade300),
              _buildDemplotTabButton("Demplot 2", 1),
              Container(width: 1, height: 20, color: Colors.grey.shade300),
              _buildDemplotTabButton("Demplot 3", 2),
            ],
          ),
        ),
        // Period Selection Tabs
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSegmentButton("7 Hari", '7d'),
              Container(width: 1, height: 20, color: Colors.grey.shade300),
              _buildSegmentButton("30 Hari", '30d'),
              Container(width: 1, height: 20, color: Colors.grey.shade300),
              _buildSegmentButton("Satu Siklus", 'cycle'),
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

  Widget _buildDemplotTabButton(String label, int id) {
    final isActive = _demplotId == id;
    return InkWell(
      onTap: () {
        if (!isActive) {
          setState(() {
            _demplotId = id;
            _demplotName = 'Demplot ${id + 1}';
          });
          _fetchAllData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
    if (_demplotAnalyticsError != null) {
      return Center(
        child: Text(
          _demplotAnalyticsError!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    
    if (_activitiesError != null) {
      return Center(
        child: Text(
          _activitiesError!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final soilHealthCard = SoilHealthCard(
      score: _demplotAnalyticsData?.soilHealthScore ?? 0,
      status: _demplotAnalyticsData?.soilHealthStatus ?? '-',
      isLoading: _isDemplotAnalyticsLoading,
    );

    final extremesCard = DailyExtremesCard(
      extremes: _demplotAnalyticsData?.extremes,
      npkTrends: _demplotAnalyticsData?.npkTrends,
      isLoading: _isDemplotAnalyticsLoading,
    );

    final treatmentSection = TreatmentActivitySection(
      demplotId: _demplotId,
      activities: _activitiesData,
      isLoading: _isActivitiesLoading,
      onFilterChanged: (filter) {
        _activityFilter = filter;
        _fetchActivities();
      },
      onActivityCreated: (payload) async {
        final success = await _sensorService.createActivity(payload);
        if (success) {
          _fetchActivities();
          _fetchDemplotAnalytics();
          _fetchOverview();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Aktivitas berhasil dicatat & disinkronkan.')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gagal mencatat aktivitas budidaya.')),
            );
          }
        }
      },
    );

    if (maxWidth < 1100) {
      return Column(
        children: [
          soilHealthCard,
          const SizedBox(height: 24),
          extremesCard,
          const SizedBox(height: 24),
          treatmentSection,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            children: [
              soilHealthCard,
              const SizedBox(height: 24),
              extremesCard,
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(flex: 6, child: treatmentSection),
      ],
    );
  }
}
