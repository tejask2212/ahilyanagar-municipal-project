import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'monthly_report_screen.dart';
import 'worker_report_screen.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Attendance Report")),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Image.asset(
              "assets/logo.png",
              height: 150,
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                buildTile(
                  context,
                  "Show Monthly Report",
                  "See detailed attendance records.",
                  Icons.assignment_turned_in,
                  Colors.blue,
                ),
                buildTile(
                  context,
                  "Show Workers",
                  "Get a summarized report of attendance.",
                  Icons.summarize,
                  Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: color,
        child: ListTile(
          leading: Icon(icon, color: Colors.white),
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
          onTap: () async {
            String? division = await getUserDivision();
            if (division == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Division not found for user.")),
              );
              return;
            }

            if (title == "Show Monthly Report") {
              final DateTime? selectedDate = await showMonthYearPicker(context);
              if (selectedDate == null) return;

              final month = selectedDate.month;
              final year = selectedDate.year;

              final summary = await fetchMonthlyAttendanceSummary(division, month, year);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MonthlyReportScreen(
                    presentCount: summary.presentCount,
                    absentCount: summary.absentCount,
                    holidayCount: summary.holidayCount,
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkerReportScreen(division: division),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Future<DateTime?> showMonthYearPicker(BuildContext context) async {
    int selectedMonth = DateTime.now().month;
    int selectedYear = DateTime.now().year;

    return await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Month and Year'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<int>(
                value: selectedMonth,
                items: List.generate(12, (index) {
                  return DropdownMenuItem(
                    value: index + 1,
                    child: Text(DateFormat.MMMM().format(DateTime(0, index + 1))),
                  );
                }),
                onChanged: (value) {
                  if (value != null) selectedMonth = value;
                },
              ),
              DropdownButton<int>(
                value: selectedYear,
                items: List.generate(5, (index) {
                  int year = DateTime.now().year - 2 + index;
                  return DropdownMenuItem(value: year, child: Text('$year'));
                }),
                onChanged: (value) {
                  if (value != null) selectedYear = value;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context, DateTime(selectedYear, selectedMonth)),
            ),
          ],
        );
      },
    );
  }

  Future<String?> getUserDivision() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final email = user.email?.replaceAll('.', ',');
    if (email == null) return null;

    final dbRef = FirebaseDatabase.instance.ref();
    final snapshot = await dbRef.child('officer_emails').child(email).once();

    return snapshot.snapshot.value?.toString();
  }
}

class AttendanceSummary {
  final int presentCount;
  final int absentCount;
  final int holidayCount;
  final double averagePercentage;

  AttendanceSummary({
    required this.presentCount,
    required this.absentCount,
    required this.holidayCount,
    required this.averagePercentage,
  });
}

Future<AttendanceSummary> fetchMonthlyAttendanceSummary(String division, int month, int year) async {
  final dbRef = FirebaseDatabase.instance.ref();
  final holidaySnapshot = await dbRef.child('holidays').once();
  final holidayData = holidaySnapshot.snapshot.value as Map?;
  final holidayFormat = DateFormat('dd MMMM yyyy');
  final workingFormat = DateFormat('dd MMM yyyy');

  Set<String> holidayDates = {};
  if (holidayData != null) {
    holidayData.forEach((key, value) {
      try {
        final d = holidayFormat.parse(key);
        if (d.month == month && d.year == year) {
          holidayDates.add(workingFormat.format(d));
        }
      } catch (_) {}
    });
  }

  final today = DateTime.now();
final lastDayOfRange = (today.year == year && today.month == month)
    ? today.day
    : DateUtils.getDaysInMonth(year, month);

final List<String> monthDates = List.generate(lastDayOfRange, (i) {
  final date = DateTime(year, month, i + 1);
  return workingFormat.format(date);
});


  final workingDays = monthDates.where((d) => !holidayDates.contains(d)).toList();
  final holidayCount = holidayDates.length;

  final workersSnapshot = await dbRef.child('workers').once();
  final workersData = workersSnapshot.snapshot.value as Map?;
  if (workersData == null) {
    return AttendanceSummary(presentCount: 0, absentCount: 0, holidayCount: holidayCount, averagePercentage: 0);
  }

  int totalPresent = 0;
  int totalAbsent = 0;
  double totalPercentage = 0;
  int workerCount = 0;

  for (final entry in workersData.entries) {
    final worker = entry.value;
    if (worker['division'] == division) {
      workerCount++;
      final attendance = Map<String, dynamic>.from(worker['attendance'] ?? {});
      int present = 0;

      for (String date in workingDays) {
        final record = attendance[date];
        if (record != null) {
          final checkIn = record['check_in'];
          final checkOut = record['check_out'];
          if (checkIn != null && checkIn.toString().isNotEmpty &&
              checkOut != null && checkOut.toString().isNotEmpty) {
            present++;
          }
        }
      }

      int workingDayCount = workingDays.length;
      totalPresent += present;
      totalAbsent += (workingDayCount - present);
      if (workingDayCount > 0) {
        totalPercentage += (present / workingDayCount) * 100;
      }
    }
  }

  double avgPercentage = workerCount == 0 ? 0 : totalPercentage / workerCount;

  return AttendanceSummary(
    presentCount: totalPresent,
    absentCount: totalAbsent,
    holidayCount: holidayCount,
    averagePercentage: avgPercentage,
  );
}