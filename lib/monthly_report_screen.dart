import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/rendering.dart';

class MonthlyReportScreen extends StatefulWidget {
  final int presentCount;
  final int absentCount;

  MonthlyReportScreen({
    required this.presentCount,
    required this.absentCount, required int holidayCount,
  });

  @override
  _MonthlyReportScreenState createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final GlobalKey _chartKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final total = widget.presentCount + widget.absentCount;
    final presentPercent = total == 0 ? 0.0 : (widget.presentCount / total) * 100;
    final absentPercent = total == 0 ? 0.0 : (widget.absentCount / total) * 100;

    return Scaffold(
      appBar: AppBar(
        title: Text("Monthly Attendance Pie Chart"),
      ),
      body: total == 0
          ? Center(
              child: Text("No attendance data available for this month."),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  RepaintBoundary(
                    key: _chartKey,
                    child: SizedBox(
                      height: 250,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                          sections: [
                            PieChartSectionData(
                              value: presentPercent,
                              title: 'Present\n${presentPercent.toStringAsFixed(1)}%',
                              color: Colors.green,
                              radius: 100,
                              titleStyle: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            PieChartSectionData(
                              value: absentPercent,
                              title: 'Absent\n${absentPercent.toStringAsFixed(1)}%',
                              color: Colors.red,
                              radius: 100,
                              titleStyle: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => downloadAsPdf(context),
                      icon: Icon(Icons.download),
                      label: Text("Download Report"),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        textStyle: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> downloadAsPdf(BuildContext context) async {
    try {
      RenderRepaintBoundary boundary =
          _chartKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final pdf = pw.Document();
      final chartImage = pw.MemoryImage(pngBytes);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text("Monthly Attendance Report",
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Image(chartImage, width: 300),
                pw.SizedBox(height: 20),
                pw.Text("Present: ${widget.presentCount}", style: pw.TextStyle(fontSize: 16)),
                pw.Text("Absent: ${widget.absentCount}", style: pw.TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to capture chart: $e")),
      );
    }
  }
}
