import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/report_model.dart';
import 'package:flutter/foundation.dart'; // for compute

class AnalyticsPdfGenerator {
  /// Generates the PDF document in a separate isolate and launches print/download dialog
  static Future<void> generateAndPrintReport(DemplotReportData reportData) async {
    // We must load the asset byte data on the main thread
    final ByteData logoData = await rootBundle.load('assets/images/logo.png');
    final Uint8List logoBytes = logoData.buffer.asUint8List();

    // Prepare payload
    final payload = {
      'reportData': reportData,
      'logoBytes': logoBytes,
    };

    // Offload PDF building to an isolate
    final Uint8List pdfBytes = await compute(_buildPdfDocument, payload);

    // Layout print dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Laporan_Analitik_${reportData.header.demplotName.replaceAll(" ", "_")}.pdf',
    );
  }
}

/// Top-level function to run inside an isolate
Future<Uint8List> _buildPdfDocument(Map<String, dynamic> payload) async {
  final DemplotReportData reportData = payload['reportData'];
  final Uint8List logoBytes = payload['logoBytes'];

  final pdf = pw.Document();
  final logoImage = pw.MemoryImage(logoBytes);
  final now = DateTime.now();
  final dateFormat = DateFormat('dd MMMM yyyy HH:mm');
  final shortDateFormat = DateFormat('dd/MM/yy');

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return [
          _buildHeader(reportData.header, logoImage),
          pw.SizedBox(height: 16),
          _buildExecutiveSummary(reportData.summary),
          pw.SizedBox(height: 16),
          _buildDailyRecordsTable(reportData.dailyRecords, shortDateFormat),
        ];
      },
      footer: (pw.Context context) {
        return _buildFooter(context, now, dateFormat);
      },
    ),
  );

  return pdf.save();
}

pw.Widget _buildHeader(DemplotReportHeader header, pw.MemoryImage logo) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Image(logo, width: 50, height: 50),
              pw.SizedBox(width: 16),
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
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                ],
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
          _buildHeaderInfoRow('Demplot', header.demplotName),
          _buildHeaderInfoRow('Periode', header.periodLabel),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildHeaderInfoRow('Komoditas', header.commodity),
          _buildHeaderInfoRow('Status Lahan', header.hst > 0 ? 'Sedang Ditanami' : 'Kosong'),
        ],
      ),
      if (header.hst > 0) ...[
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildHeaderInfoRow(
              'Tanggal Tanam', 
              DateFormat('dd MMMM yyyy').format(DateTime.parse(header.plantingDate))
            ),
            _buildHeaderInfoRow('Usia Tanaman', '${header.hst} Hari (${header.phase})'),
          ],
        ),
      ],
    ],
  );
}

pw.Widget _buildHeaderInfoRow(String label, String value) {
  return pw.Row(
    children: [
      pw.Text('$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
      pw.Text(value, style: const pw.TextStyle(color: PdfColors.black)),
    ],
  );
}

pw.Widget _buildExecutiveSummary(DemplotReportSummary summary) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        '1. Ringkasan Eksekutif',
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
          _buildTableRow(['Indikator Lahan', 'Nilai Rata-rata', 'Satuan'], isHeader: true),
          _buildTableRow(['Kelembapan Tanah', '${summary.avgMoisture.toStringAsFixed(1)}', '%']),
          _buildTableRow(['Suhu Udara', '${summary.avgTemp.toStringAsFixed(1)}', '°C']),
          _buildTableRow(['Kelembapan Udara (RH)', '${summary.avgHumidity.toStringAsFixed(1)}', '%']),
          _buildTableRow(['pH Tanah', '${summary.avgPh.toStringAsFixed(1)}', 'pH']),
          _buildTableRow(['Soil Health Score', '${summary.soilHealthScore}', '/100']),
        ],
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
          _buildTableRow(['Aktivitas Budidaya', 'Total', 'Keterangan'], isHeader: true),
          _buildTableRow(['Total Penyiraman', '${summary.totalWaterLiters.toStringAsFixed(1)} Liter', 'Total Volume']),
          _buildTableRow(['Frekuensi Pemupukan', '${summary.fertilizationCount} Kali', 'Total Siklus']),
          _buildTableRow(['Frekuensi Penyemprotan', '${summary.sprayingCount} Kali', 'Total Siklus']),
        ],
      ),
    ],
  );
}

pw.Widget _buildDailyRecordsTable(List<DailyReportItem> dailyRecords, DateFormat shortDateFormat) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        '2. Tabel Riwayat Harian',
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 12),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey400),
        columnWidths: {
          0: const pw.FlexColumnWidth(2), // Tanggal
          1: const pw.FlexColumnWidth(1.5), // Suhu
          2: const pw.FlexColumnWidth(1.5), // Kelembapan
          3: const pw.FlexColumnWidth(1.5), // pH & NPK
          4: const pw.FlexColumnWidth(3.5), // Log Aktivitas
        },
        children: [
          _buildTableRow(['Tanggal', 'Suhu (Min/Max/Avg)', 'Moisture (Min/Max/Avg)', 'Nutrisi (pH/NPK)', 'Aktivitas Hari Itu'], isHeader: true),
          ...dailyRecords.map((d) {
            final dateObj = DateTime.parse(d.date);
            final dateStr = '${d.dayName}, ${shortDateFormat.format(dateObj)}';
            final tempStr = '${d.minTemp}/${d.maxTemp}/${d.avgTemp} °C';
            final moistStr = '${d.minMoisture}/${d.maxMoisture}/${d.avgMoisture} %';
            final nutrisiStr = 'pH: ${d.avgPh}\nN:${d.avgN} P:${d.avgP} K:${d.avgK}';
            final actsStr = d.activities.isEmpty ? '-' : d.activities.join('\n');

            return _buildTableRow([dateStr, tempStr, moistStr, nutrisiStr, actsStr]);
          }),
        ],
      ),
    ],
  );
}

pw.TableRow _buildTableRow(List<String> cells, {bool isHeader = false, bool isFooter = false}) {
  return pw.TableRow(
    decoration: pw.BoxDecoration(
      color: isHeader ? PdfColors.grey200 : (isFooter ? PdfColors.green50 : null),
    ),
    children: cells.map((cell) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(
          cell,
          style: pw.TextStyle(
            fontWeight: (isHeader || isFooter) ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: 9,
            color: isHeader ? PdfColors.black : (isFooter ? PdfColors.green800 : PdfColors.grey800),
          ),
          textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
        ),
      );
    }).toList(),
  );
}

pw.Widget _buildFooter(pw.Context context, DateTime now, DateFormat format) {
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
