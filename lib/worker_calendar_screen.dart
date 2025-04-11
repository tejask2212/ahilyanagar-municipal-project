import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';


class WorkerCalendarScreen extends StatefulWidget {
  final String workerId;
  final String workerName;
  final DateTime startDate;
  final DateTime endDate;

  WorkerCalendarScreen({
    required this.workerId,
    required this.workerName,
    required this.startDate,
    required this.endDate,
  });

  @override
  _WorkerCalendarScreenState createState() => _WorkerCalendarScreenState();
}

class _WorkerCalendarScreenState extends State<WorkerCalendarScreen> {
  Map<DateTime, String> attendanceMap = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchAttendance();
  }

  Future<void> fetchAttendance() async {
  final dbRef = FirebaseDatabase.instance.ref();
  
  // 1. Fetch holidays
  final holidaySnapshot = await dbRef.child('holidays').once();
  final holidaysData = holidaySnapshot.snapshot.value as Map?;
  final dateFormat = DateFormat('dd MMM yyyy');
  final holidayFormat = DateFormat('dd MMMM yyyy'); // Because your holidays use full month names

  Set<DateTime> holidayDates = {};
  if (holidaysData != null) {
    holidaysData.forEach((key, value) {
      try {
        DateTime holidayDate = holidayFormat.parse(key);
        holidayDates.add(DateTime(holidayDate.year, holidayDate.month, holidayDate.day));
      } catch (e) {
        print("Invalid holiday date: $key");
      }
    });
  }

  // 2. Fetch attendance
  final snapshot = await dbRef
      .child('workers')
      .child(widget.workerId)
      .child('attendance')
      .once();

  final rawData = snapshot.snapshot.value as Map?;
  Map<DateTime, String> tempMap = {};

  if (rawData != null) {
    rawData.forEach((dateStr, record) {
      try {
        DateTime date = dateFormat.parse(dateStr);
        final normalizedDate = DateTime(date.year, date.month, date.day);

        if (normalizedDate.isAfter(widget.startDate.subtract(Duration(days: 1))) &&
            normalizedDate.isBefore(widget.endDate.add(Duration(days: 1)))) {
          
          if (holidayDates.contains(normalizedDate)) {
            tempMap[normalizedDate] = 'holiday';
            return;
          }

          final checkIn = record['check_in'];
          final checkOut = record['check_out'];

          if (checkIn != null &&
              checkIn.toString().isNotEmpty &&
              (checkOut == null || checkOut.toString().isEmpty)) {
            tempMap[normalizedDate] = 'only_checkin';
          } else if ((checkIn != null && checkIn.toString().isNotEmpty) &&
              (checkOut != null && checkOut.toString().isNotEmpty)) {
            tempMap[normalizedDate] = 'present';
          } else {
            tempMap[normalizedDate] = 'absent';
          }
        }
      } catch (e) {
        print("Error parsing date: $e");
      }
    });
  }

  // 3. Fill missing dates
  final today = DateTime.now();
  final todayNormalized = DateTime(today.year, today.month, today.day);

  DateTime current = widget.startDate;
  while (current.isBefore(widget.endDate.add(Duration(days: 1)))) {
    final normalizedCurrent = DateTime(current.year, current.month, current.day);

    if (!tempMap.containsKey(normalizedCurrent)) {
      if (holidayDates.contains(normalizedCurrent)) {
        tempMap[normalizedCurrent] = 'holiday';
      } else if (normalizedCurrent.isAfter(todayNormalized)) {
        // Future date - skip
      } else if (normalizedCurrent.isAtSameMomentAs(todayNormalized)) {
        tempMap[normalizedCurrent] = 'not confirmed';
      } else {
        tempMap[normalizedCurrent] = 'absent';
      }
    }

    current = current.add(Duration(days: 1));
  }

  setState(() {
    attendanceMap = tempMap;
    loading = false;
  });
}



  Color getColorForStatus(String? status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'not confirmed':
        return Colors.black;
      case 'holiday':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.transparent;
    }
  }

  Future<void> printAttendanceReport() async {
    final pdf = pw.Document();
    final formatter = DateFormat('dd/MM/yyyy');

    final sortedDates = attendanceMap.keys.toList()..sort();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Attendance Report for ${widget.workerName}',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['Date', 'Status'],
                data: sortedDates.map((date) {
                  final status = attendanceMap[date] ?? 'N/A';
                  return [formatter.format(date), status];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFEEEEEE),
                ),
                cellPadding: const pw.EdgeInsets.all(8),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.workerName}'s Attendance"),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TableCalendar(
                  focusedDay: widget.startDate,
                  firstDay: widget.startDate,
                  lastDay: widget.endDate,
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      return buildAttendanceCell(day);
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return buildAttendanceCell(day);
                    },
                  ),
                ),
                SizedBox(height: 16),
                buildLegend(),
                SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: Icon(Icons.print),
                  label: Text("Print Report"),
                  onPressed: printAttendanceReport,
                ),
              ],
            ),
    );
  }

  Widget buildAttendanceCell(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final status = attendanceMap[normalizedDay];
    final color = getColorForStatus(status);

    return Container(
      margin: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: color != Colors.transparent ? color : null,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: (color == Colors.black || color == Colors.red)
              ? Colors.white
              : Colors.white,
        ),
      ),
    );
  }

  Widget buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        children: [
          legendItem(Colors.green, "Present"),
          legendItem(Colors.black, "Not Confirmed"),
          legendItem(Colors.red, "Absent"),
          legendItem(Colors.orange, "Holiday"),
        ],
      ),
    );
  }

  Widget legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 16, color: color),
        SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
