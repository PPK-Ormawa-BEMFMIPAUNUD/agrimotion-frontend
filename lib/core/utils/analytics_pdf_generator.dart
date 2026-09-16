import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/analytics_model.dart';
import '../models/crop_cycle_model.dart';
import 'package:intl/intl.dart';

class AnalyticsPdfGenerator {
  static Future<void> generateAndPrintReport({
    required String demplotName,
    required String period,
    required AnalyticsOverviewModel overview,
    required WaterUsageAnalyticsModel waterUsage,
    CropCycleModel? activeCropCycle,
  }) async {
    final pdf = pw.Document();

    final now = DateTime.now();
    final dateFormat = DateFormat('dd MMMM yyyy HH:mm');

    String periodLabel = 'Mingguan';
    if (period == 'day') periodLabel = 'Harian';
    else if (period == 'month') periodLabel = 'Bulanan';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(periodLabel, demplotName, activeCropCycle),
        footer: (context) => _buildFooter(context, now, dateFormat),
        build: (context) => [
          pw.SizedBox(height: 24),
          _buildSummarySection(overview),
          pw.SizedBox(height: 24),
          _buildWaterUsageSection(waterUsage),
          pw.SizedBox(height: 24),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Laporan_Analitik_AGRIMOTION_${period}_$demplotName.pdf',
    );
  }

  static pw.Widget _buildHeader(String periodLabel, String demplotName, CropCycleModel? cycle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'AGRI-MOTION',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800,
                  ),
                ),
                pw.Text(
                  'Precision Agriculture System',
                  style: const pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Text(
              'LAPORAN ANALITIK',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Divider(thickness: 2, color: PdfColors.green800),
        pw.SizedBox(height: 16),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildHeaderInfoRow('Demplot', demplotName),
            _buildHeaderInfoRow('Periode', periodLabel),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildHeaderInfoRow('Komoditas', cycle?.commodityName ?? 'Lahan Bera / Kosong'),
            _buildHeaderInfoRow('Status Lahan', cycle != null ? 'Sedang Ditanami' : 'Kosong'),
          ],
        ),
        if (cycle != null) ...[
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildHeaderInfoRow('Tanggal Tanam', cycle.formattedPlantingDate),
              _buildHeaderInfoRow('Usia Tanaman', '${cycle.hst} Hari (${cycle.phase})'),
            ],
          ),
        ],
      ],
    );
  }

  static pw.Widget _buildHeaderInfoRow(String label, String value) {
    return pw.Row(
      children: [
        pw.Text('$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        pw.Text(value, style: const pw.TextStyle(color: PdfColors.black)),
      ],
    );
  }

  static pw.Widget _buildSummarySection(AnalyticsOverviewModel overview) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '1. Ringkasan Kondisi Lahan',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
          },
          children: [
            _buildTableRow(['Parameter', 'Nilai Rata-rata', 'Status/Satuan'], isHeader: true),
            _buildTableRow(['Kelembaban Tanah', '${overview.avgSoilMoisture.toStringAsFixed(1)}', '%']),
            _buildTableRow(['Suhu Udara', '${overview.avgTemperature.toStringAsFixed(1)}', '°C']),
            _buildTableRow(['Kelembaban Udara (RH)', '${overview.avgHumidity.toStringAsFixed(1)}', '%']),
            _buildTableRow(['pH Tanah', '${overview.avgPh.toStringAsFixed(1)}', 'pH']),
            _buildTableRow(['Indeks NPK', '${overview.avgNpkIndex.toStringAsFixed(1)}', 'mg/kg']),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Total sampel data diproses: ${overview.totalSamples}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      ],
    );
  }

  static pw.Widget _buildWaterUsageSection(WaterUsageAnalyticsModel waterUsage) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '2. Riwayat & Akumulasi Penyiraman',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
          },
          children: [
            _buildTableRow(['Area Demplot', 'Komoditas', 'Durasi Pompa (dtk)', 'Volume (Liter)'], isHeader: true),
            ...waterUsage.demplots.map((d) {
              return _buildTableRow([
                d.name,
                d.commodity,
                d.totalDurationSeconds.toString(),
                d.estimatedLiters.toStringAsFixed(1),
              ]);
            }).toList(),
            _buildTableRow(['TOTAL', '-', '-', '${waterUsage.totalLiters.toStringAsFixed(1)} Liter'], isFooter: true),
          ],
        ),
      ],
    );
  }

  static pw.TableRow _buildTableRow(List<String> cells, {bool isHeader = false, bool isFooter = false}) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: isHeader ? PdfColors.grey200 : (isFooter ? PdfColors.green50 : null),
      ),
      children: cells.map((cell) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Text(
            cell,
            style: pw.TextStyle(
              fontWeight: (isHeader || isFooter) ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontSize: 11,
              color: isHeader ? PdfColors.black : (isFooter ? PdfColors.green800 : PdfColors.grey800),
            ),
            textAlign: (isHeader || cell.contains(RegExp(r'[0-9]'))) && !cell.contains('Demplot') && cell != 'TOTAL' 
                ? pw.TextAlign.center 
                : pw.TextAlign.left,
          ),
        );
      }).toList(),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, DateTime now, DateFormat format) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Dicetak pada: ${format.format(now)}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Text(
              'Halaman ${context.pageNumber} dari ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }
}
