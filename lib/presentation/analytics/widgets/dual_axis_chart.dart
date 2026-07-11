import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../../../core/theme/app_theme.dart';

class DualAxisChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;

    final textStyleGrey = const TextStyle(color: Colors.grey, fontSize: 10);

    // 1. Gambar Garis Horizontal Grid (Y-Axis Ticks)
    const int yAxisDivisions = 10;
    for (int i = 0; i <= yAxisDivisions; i++) {
      double y = size.height - (size.height * (i / yAxisDivisions));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      // Label Kiri (Moisture 35 - 45)
      _drawText(canvas, "${35 + i}", Offset(-20, y - 6), textStyleGrey,
          alignRight: true);

      // Label Kanan (Temp 22.0 - 26.0)
      double tempVal = 22.0 + (i * 0.4);
      _drawText(canvas, tempVal.toStringAsFixed(1),
          Offset(size.width + 10, y - 6), textStyleGrey);
    }

    // Y-Axis Titles (Rotated)
    _drawRotatedText(
        canvas, "Moisture (%)", const Offset(-35, 120), textStyleGrey);
    _drawRotatedText(
        canvas, "Temperature (°C)", Offset(size.width + 35, 120), textStyleGrey,
        isRight: true);

    // X-Axis Labels
    final labelsX = [
      "Oct 1",
      "Oct 5",
      "Oct 10",
      "Oct 15",
      "Oct 20",
      "Oct 25",
      "Oct 30"
    ];
    for (int i = 0; i < labelsX.length; i++) {
      double x = (size.width / (labelsX.length - 1)) * i;
      _drawText(
          canvas, labelsX[i], Offset(x - 12, size.height + 10), textStyleGrey);
    }

    // 2. Data Points & Jalur Hijau (Moisture)
    // Mensimulasikan bentuk kurva pada mockup
    final List<Offset> greenPoints = [
      Offset(0, size.height), // Oct 1
      Offset(size.width * 0.16, size.height * 0.7), // Oct 5
      Offset(size.width * 0.33, size.height * 0.35), // Oct 10
      Offset(size.width * 0.5, size.height * 0.6), // Oct 15
      Offset(size.width * 0.66, size.height * 0.1), // Oct 20 (Peak)
      Offset(size.width * 0.83, size.height * 0.45), // Oct 25
      Offset(size.width, size.height * 0.25), // Oct 30
    ];

    final greenPath = Path();
    greenPath.moveTo(greenPoints[0].dx, greenPoints[0].dy);
    // Menggunakan kurva bezier sederhana di antara titik-titik
    for (int i = 0; i < greenPoints.length - 1; i++) {
      final p0 = greenPoints[i];
      final p1 = greenPoints[i + 1];
      greenPath.quadraticBezierTo(
          p0.dx + (p1.dx - p0.dx) / 2,
          p0.dy, // Control point
          p1.dx,
          p1.dy // End point
          );
    }

    // Area Fill Hijau
    final fillPath = Path.from(greenPath);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final greenGradient = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(0, size.height),
      [AppTheme.primaryColor.withOpacity(0.2), Colors.white.withOpacity(0.0)],
    );

    canvas.drawPath(fillPath, Paint()..shader = greenGradient);

    // Garis Hijau
    canvas.drawPath(
        greenPath,
        Paint()
          ..color = AppTheme.primaryColor
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke);

    // Titik-titik (Dots) Hijau
    final dotPaintWhite = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final dotPaintGreen = Paint()
      ..color = AppTheme.primaryColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var point in greenPoints) {
      canvas.drawCircle(point, 4, dotPaintWhite);
      canvas.drawCircle(point, 4, dotPaintGreen);
    }

    // Legend kecil di dekat Peak (Oct 20)
    _drawText(
        canvas,
        "Avg Moisture (%)",
        Offset(greenPoints[4].dx + 10, greenPoints[4].dy - 5),
        const TextStyle(
            color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold));

    // 3. Data Points & Jalur Merah Putus-putus (Suhu)
    final List<Offset> redPoints = [
      Offset(0, size.height * 0.1), // Oct 1 (Tinggi)
      Offset(size.width * 0.16, size.height * 0.3), // Oct 5
      Offset(size.width * 0.33, size.height * 0.8), // Oct 10 (Rendah)
      Offset(size.width * 0.5, size.height * 0.55), // Oct 15
      Offset(size.width * 0.66, size.height * 0.95), // Oct 20 (Sangat Rendah)
      Offset(size.width * 0.83, size.height * 0.75), // Oct 25
      Offset(size.width, size.height * 0.4), // Oct 30
    ];

    final redPath = Path();
    redPath.moveTo(redPoints[0].dx, redPoints[0].dy);
    for (int i = 0; i < redPoints.length - 1; i++) {
      final p0 = redPoints[i];
      final p1 = redPoints[i + 1];
      redPath.quadraticBezierTo(
          p0.dx + (p1.dx - p0.dx) / 2, p0.dy, p1.dx, p1.dy);
    }

    _drawDashedPath(
        canvas,
        redPath,
        Paint()
          ..color = Colors.red
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);

    // Titik-titik (Dots) Merah
    final dotPaintRed = Paint()
      ..color = Colors.red
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (var point in redPoints) {
      canvas.drawCircle(point, 3, dotPaintWhite);
      canvas.drawCircle(point, 3, dotPaintRed);
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style,
      {bool alignRight = false}) {
    final textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr);
    textPainter.layout();
    if (alignRight) {
      textPainter.paint(
          canvas, Offset(offset.dx - textPainter.width, offset.dy));
    } else {
      textPainter.paint(canvas, offset);
    }
  }

  void _drawRotatedText(
      Canvas canvas, String text, Offset offset, TextStyle style,
      {bool isRight = false}) {
    final textPainter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr);
    textPainter.layout();

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.rotate(isRight ? 1.5708 : -1.5708); // 90 degrees in radians
    textPainter.paint(canvas, Offset(-textPainter.width / 2, 0));
    canvas.restore();
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const double dashWidth = 5.0;
    const double dashSpace = 4.0;
    double distance = 0.0;

    for (ui.PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        final ui.Path extractPath =
            pathMetric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
      distance = 0.0;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
