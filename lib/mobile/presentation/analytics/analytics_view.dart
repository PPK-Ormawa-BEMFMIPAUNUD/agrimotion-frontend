import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:file_saver/file_saver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/mock_control_helper.dart';
import '../../../core/models/sensor_data.dart';
import '../../../core/services/sensor_service.dart';
import 'widgets/dual_axis_chart.dart';

class AnalyticsView extends StatefulWidget {
  const AnalyticsView({super.key});

  @override
  State<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<AnalyticsView> {
  String _selectedPeriod = 'Bulan';
  final SensorService _sensorService = SensorService();
  bool _isLoading = true;
  String? _errorMessage;
  List<SensorData> _sensorDataList = [];
  double _avgMoisture = 0.0;
  double _meanTemp = 0.0;
  double _avgNpk = 0.0;
  int _activeSensors = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _sensorService.fetchTelemetryList(limit: 50);

      double totalMoisture = 0;
      double totalTemp = 0;
      double totalNpk = 0;
      int npkCount = 0;
      Set<String> uniqueDevices = {};

      for (var item in data) {
        totalMoisture += item.soilMoisture ?? 0;
        totalTemp += item.temperature ?? 0;
        if (item.npkN != null || item.npkP != null || item.npkK != null) {
          totalNpk += (item.npkN ?? 0) + (item.npkP ?? 0) + (item.npkK ?? 0);
          npkCount++;
        }
        if (item.deviceId != null || item.deviceCode != null) {
          uniqueDevices.add(item.deviceId ?? item.deviceCode!);
        }
      }

      setState(() {
        _sensorDataList = data;
        if (data.isNotEmpty) {
          _avgMoisture = totalMoisture / data.length;
          _meanTemp = totalTemp / data.length;
        }
        if (npkCount > 0) {
          _avgNpk = (totalNpk / 3) / npkCount;
        }
        _activeSensors = uniqueDevices.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _exportData() async {
    if (_sensorDataList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diekspor')),
      );
      return;
    }

    String csv = "TIMESTAMP,NODE_ID,FARM_ID,MOISTURE,TEMPERATURE,PH,NPK\n";
    for (var item in _sensorDataList) {
      csv +=
          "${item.timestamp.toIso8601String()},${item.deviceCode ?? item.deviceId ?? ''},${item.farmId ?? ''},${item.soilMoisture ?? ''},${item.temperature ?? ''},${item.ph ?? ''},${item.npkDisplay}\n";
    }

    try {
      final String fileName =
          'agrimotion_laporan_${DateTime.now().millisecondsSinceEpoch}';
      final bytes = Uint8List.fromList(utf8.encode(csv));

      final path = await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: 'csv',
        mimeType: MimeType.csv,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(path.isNotEmpty
                ? 'Laporan CSV berhasil disimpan ke:\n$path'
                : 'Laporan CSV berhasil diunduh!'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan file: $e'),
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
              _buildHeader(),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                            color: AppTheme.primaryColor)))
              else if (_errorMessage != null)
                Center(
                    child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Text(_errorMessage!,
                            style: const TextStyle(color: Colors.red))))
              else ...[
                _buildKpiRow(constraints.maxWidth),
                const SizedBox(height: 24),
                _buildChartsRow(constraints.maxWidth),
                const SizedBox(height: 24),
                _buildDataTable(),
              ],
            ],
          ),
        );
      },
    );
  }

  // ==========================================================================
  // 1. HEADER SECTION
  // ==========================================================================
  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        final titleColumn = const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Analisis Data Historis",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            SizedBox(height: 4),
            Text("Tinjau tren sensor dan ekspor laporan berkala.",
                style: TextStyle(color: Colors.grey, fontSize: 14)),
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
                  _buildSegmentButton("Hari", _selectedPeriod == 'Hari'),
                  Container(width: 1, height: 20, color: Colors.grey.shade300),
                  _buildSegmentButton("Minggu", _selectedPeriod == 'Minggu'),
                  Container(width: 1, height: 20, color: Colors.grey.shade300),
                  _buildSegmentButton("Bulan", _selectedPeriod == 'Bulan'),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _exportData,
              icon: const Icon(Icons.download, size: 16, color: Colors.black87),
              label: const Text("Ekspor Laporan",
                  style: TextStyle(
                      color: Colors.black87, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
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
      },
    );
  }

  Widget _buildSegmentButton(String text, bool isActive) {
    return InkWell(
      onTap: () {
        setState(() => _selectedPeriod = text);
        MockControlHelper.showSimulationSnackBar(
          context,
          featureName: 'Periode $text',
          description: 'Data historis dimuat untuk periode $text.',
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.green.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          text,
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
  // 2. KPI CARDS SECTION
  // ==========================================================================
  Widget _buildKpiRow(double maxWidth) {
    // Responsivitas lebar kartu
    final isDesktop = maxWidth > 1000;
    final cardWidth = isDesktop ? (maxWidth / 4) - 18 : (maxWidth / 2) - 12;

    return Wrap(
      spacing: 24,
      runSpacing: 24,
      children: [
        _kpiCard(
            cardWidth,
            "RATA-RATA KELEMBABAN TANAH",
            "${_avgMoisture.toStringAsFixed(1)}%",
            "Rata-rata saat ini",
            Icons.water_drop_outlined,
            true,
            true),
        _kpiCard(
            cardWidth,
            "RATA-RATA SUHU",
            "${_meanTemp.toStringAsFixed(1)}°C",
            "Rata-rata saat ini",
            Icons.thermostat_outlined,
            false,
            true,
            iconColor: Colors.red),
        _kpiCard(cardWidth, "INDEKS NUTRISI NPK", _avgNpk.toStringAsFixed(1),
            "Rata-rata saat ini", Icons.science_outlined, false, false,
            valueSub: ""),
        _kpiCard(cardWidth, "SENSOR AKTIF", "$_activeSensors",
            "Node terdeteksi", Icons.sensors, true, true,
            valueSub: "", isStatusPoint: true),
      ],
    );
  }

  Widget _kpiCard(double width, String title, String value, String subtitle,
      IconData icon, bool isPositiveIcon, bool isPositiveTrend,
      {Color iconColor = AppTheme.primaryColor,
      String valueSub = "",
      bool isStatusPoint = false}) {
    // Memisahkan angka utama dan sub-angka (misal 124 dan /128)
    final mainValue = value.replaceAll(valueSub, "");

    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, color: iconColor, size: 16),
              )
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(mainValue,
                    style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                if (valueSub.isNotEmpty)
                  Text(valueSub,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isStatusPoint)
                Icon(Icons.circle,
                    color: isPositiveTrend ? Colors.green : Colors.red,
                    size: 10)
              else if (isPositiveIcon)
                const Icon(Icons.trending_up, color: Colors.green, size: 16)
              else if (!isPositiveTrend && !isPositiveIcon)
                const Icon(Icons.trending_down, color: Colors.red, size: 16)
              else
                const Icon(Icons.horizontal_rule, color: Colors.grey, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(subtitle,
                    style: TextStyle(
                        color: isStatusPoint
                            ? Colors.grey.shade700
                            : (isPositiveTrend
                                ? Colors.green
                                : (isPositiveIcon == false &&
                                        subtitle.contains('-')
                                    ? Colors.red
                                    : Colors.grey)),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // 3. CHARTS SECTION
  // ==========================================================================
  Widget _buildChartsRow(double maxWidth) {
    if (maxWidth < 900) {
      return Column(
        children: [
          _buildCorrelationChartCard(),
          const SizedBox(height: 24),
          _buildWaterUsageCard(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: _buildCorrelationChartCard()),
        const SizedBox(width: 24),
        Expanded(flex: 3, child: _buildWaterUsageCard()),
      ],
    );
  }

  Widget _buildCorrelationChartCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
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
                    Text("Korelasi Kelembaban & Suhu",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2),
                    SizedBox(height: 4),
                    Text("Tren historis 30 hari di Sektor A.",
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.more_vert, color: Colors.grey.shade600),
            ],
          ),
          const SizedBox(height: 40),
          // Chart Painter Placeholder (CustomPaint)
          SizedBox(
            height: 280,
            width: double.infinity,
            child: CustomPaint(painter: DualAxisChartPainter()),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterUsageCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Penggunaan Air",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 4),
          const Text("Volume per Sektor (Liter)",
              style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 24),

          // Custom Stacked Bar Chart
          SizedBox(
            height: 180,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _stackedBar("Minggu 1", 60, 45, 30),
                _stackedBar("Minggu 2", 45, 55, 25),
                _stackedBar("Minggu 3", 50, 45, 28),
                _stackedBar("Minggu 4", 48, 40, 20),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Legends
          _waterLegend(AppTheme.primaryColor, "Sektor A (Utara)", "4.200 L"),
          const SizedBox(height: 12),
          _waterLegend(Colors.green.shade300, "Sektor B (Timur)", "3.850 L"),
          const SizedBox(height: 12),
          _waterLegend(Colors.grey.shade300, "Sektor C (Selatan)", "2.100 L"),
        ],
      ),
    );
  }

  Widget _stackedBar(String label, double val1, double val2, double val3) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
            width: 32,
            height: val3,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(2)))),
        Container(width: 32, height: val2, color: Colors.green.shade300),
        Container(width: 32, height: val1, color: AppTheme.primaryColor),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _waterLegend(Color color, String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          ],
        ),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ==========================================================================
  // 4. DATA TABLE SECTION
  // ==========================================================================
  Widget _buildDataTable() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header Actions
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 500;
                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Data Log Sensor",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 36,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Filter ID node...",
                            hintStyle: TextStyle(
                                fontSize: 13, color: Colors.grey.shade400),
                            prefixIcon: Icon(Icons.filter_list,
                                size: 16, color: Colors.grey.shade500),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 0),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300)),
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text("Data Log Sensor",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ),
                    SizedBox(
                      width: 200,
                      height: 36,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Filter ID node...",
                          hintStyle: TextStyle(
                              fontSize: 13, color: Colors.grey.shade400),
                          prefixIcon: Icon(Icons.filter_list,
                              size: 16, color: Colors.grey.shade500),
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 0),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300)),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),

          // Table Data — horizontally scrollable on narrow screens
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 600),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1.5),
                  4: FlexColumnWidth(1.5),
                  5: FlexColumnWidth(1.5),
                },
                children: [
                  // Header Row
                  TableRow(
                    children: [
                      _th("WAKTU"),
                      _th("ID NODE"),
                      _th("SEKTOR"),
                      _th("KELEMBABAN (%)"),
                      _th("SUHU (°C)"),
                      _th("STATUS"),
                    ],
                  ),
                  // Data Rows
                  if (_sensorDataList.isEmpty)
                    const TableRow(children: [
                      Padding(
                          padding: EdgeInsets.all(16),
                          child: Text("Tidak ada data tersedia.")),
                      Text(""),
                      Text(""),
                      Text(""),
                      Text(""),
                      Text("")
                    ])
                  else
                    ..._sensorDataList.map((item) {
                      final isNormal =
                          (item.soilMoisture ?? 0) > 30; // simplistic logic
                      return _tdRow(
                          item.formattedTimestamp
                              .split(',')
                              .last
                              .trim(), // short time
                          item.deviceCode ?? item.deviceId ?? "-",
                          item.farmId?.substring(0, 8) ??
                              "Utama", // short farm id placeholder
                          SensorData.formatValue(item.soilMoisture),
                          SensorData.formatValue(item.temperature),
                          isNormal ? "Normal" : "Kelembaban Rendah",
                          isNormal,
                          isLast: _sensorDataList.last == item);
                    }),
                ],
              ),
            ),
          ),

          // Pagination Footer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    "Menampilkan 1-${_sensorDataList.length.clamp(0, 50)} dari ${_sensorDataList.length} data",
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                Row(
                  children: [
                    _pageBtn("Sebelumnya"),
                    const SizedBox(width: 8),
                    _pageBtn("Berikutnya"),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _th(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600)),
    );
  }

  TableRow _tdRow(String time, String node, String sector, String moist,
      String temp, String status, bool isNormal,
      {bool isLast = false}) {
    return TableRow(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      children: [
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(time,
                style: const TextStyle(fontSize: 13, color: Colors.black87))),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(node,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold))),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(sector,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(moist,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isNormal ? Colors.black87 : Colors.red.shade700))),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(temp,
                style: const TextStyle(fontSize: 13, color: Colors.black87))),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: isNormal ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12)),
                child: Text(status,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isNormal
                            ? Colors.green.shade700
                            : Colors.red.shade700)),
              ),
            )),
      ],
    );
  }

  Widget _pageBtn(String label) {
    return InkWell(
      onTap: () {
        MockControlHelper.showSimulationSnackBar(
          context,
          featureName: 'Navigasi Halaman',
          description:
              'Di lahan, tabel akan memuat halaman data berikutnya dari database sensor.',
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}
