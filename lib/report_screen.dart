import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'monthly_report_screen.dart';
import 'worker_report_screen.dart';
import 'daily_report_screen.dart';

class ReportScreen extends StatelessWidget {
  final String? divisionOverride;
  const ReportScreen({super.key, this.divisionOverride});

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
                buildTile(
                  context,
                  "View Daily Report",
                  "Check daily attendance summary.",
                  Icons.today,
                  Colors.orange,
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
        child: GestureDetector(
          onTap: () async {
            String? division = divisionOverride ?? await getUserDivision();
            bool isSuperAdmin = await checkIfSuperAdmin();

            if (title == "Show Monthly Report") {
              final DateTime? selectedDate = await showMonthYearPicker(context);
              if (selectedDate == null) return;

              String? selectedDivision = division;

              if (isSuperAdmin) {
                selectedDivision =
                    await showDivisionPickerWithAverageOption(context);
                if (selectedDivision == null) return;
              }

              final summary = await fetchMonthlyAttendanceSummary(
                selectedDivision == "ALL_DIVISIONS_AVERAGE"
                    ? null
                    : selectedDivision,
                selectedDate.month,
                selectedDate.year,
                isSuperAdmin && selectedDivision == "ALL_DIVISIONS_AVERAGE",
              );

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
            } else if (title == "Show Workers") {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkerReportScreen(
                    division: division,
                    isSuperAdmin: isSuperAdmin,
                  ),
                ),
              );
            } else if (title == "View Daily Report") {
              if (isSuperAdmin) {
                final selectedDivision = await showDivisionPicker(context);
                if (selectedDivision == null) return;
                division = selectedDivision;
              }

              final selectedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 1)),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().subtract(const Duration(days: 1)),
              );

              if (selectedDate == null || division == null) return;

              final report =
                  await fetchDailyAttendanceSummary(division, selectedDate);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DailyReportScreen(
                    date: selectedDate,
                    division: division!,
                    present: report['present']!,
                    absent: report['absent']!,
                    notConfirmed: report['not_confirmed']!,
                  ),
                ),
              );
            }
          },
          child: ListTile(
            leading: Icon(icon, color: Colors.white),
            title: Text(title,
                style: const TextStyle(color: Colors.white, fontSize: 18)),
            subtitle:
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
          ),
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
                items: List.generate(
                  12,
                  (index) => DropdownMenuItem(
                    value: index + 1,
                    child:
                        Text(DateFormat.MMMM().format(DateTime(0, index + 1))),
                  ),
                ),
                onChanged: (value) => selectedMonth = value!,
              ),
              DropdownButton<int>(
                value: selectedYear,
                items: List.generate(5, (index) {
                  int year = DateTime.now().year - 2 + index;
                  return DropdownMenuItem(value: year, child: Text('$year'));
                }),
                onChanged: (value) => selectedYear = value!,
              ),
            ],
          ),
          actions: [
            TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context)),
            TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(
                    context, DateTime(selectedYear, selectedMonth))),
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
    final superAdminSnapshot =
        await dbRef.child('super_admins').child(email).once();
    if (superAdminSnapshot.snapshot.exists) return null;

    final snapshot = await dbRef.child('officer_emails').child(email).once();
    return snapshot.snapshot.value?.toString();
  }

  Future<bool> checkIfSuperAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final email = user.email?.replaceAll('.', ',');
    if (email == null) return false;

    final dbRef = FirebaseDatabase.instance.ref();
    final superAdminSnapshot =
        await dbRef.child('super_admins').child(email).once();
    return superAdminSnapshot.snapshot.exists;
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

Future<AttendanceSummary> fetchMonthlyAttendanceSummary(
  String? division,
  int month,
  int year,
  bool isSuperAdmin,
) async {
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

  final workingDays =
      monthDates.where((d) => !holidayDates.contains(d)).toList();
  final holidayCount = holidayDates.length;

  final workersSnapshot = await dbRef.child('workers').once();
  final workersData = workersSnapshot.snapshot.value as Map?;
  if (workersData == null) {
    return AttendanceSummary(
      presentCount: 0,
      absentCount: 0,
      holidayCount: holidayCount,
      averagePercentage: 0,
    );
  }

  int totalPresent = 0;
  int totalAbsent = 0;
  double totalPercentage = 0;
  int workerCount = 0;

  for (final entry in workersData.entries) {
    final worker = entry.value;

    if (isSuperAdmin || worker['division'] == division) {
      workerCount++;
      final attendance = Map<String, dynamic>.from(worker['attendance'] ?? {});
      int present = 0;

      for (String date in workingDays) {
        final record = attendance[date];
        if (record != null) {
          final checkIn = record['check_in'];
          final checkOut = record['check_out'];
          if (checkIn != null &&
              checkIn.toString().isNotEmpty &&
              checkOut != null &&
              checkOut.toString().isNotEmpty) {
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

Future<Map<String, int>> fetchDailyAttendanceSummary(
    String division, DateTime date) async {
  final dbRef = FirebaseDatabase.instance.ref();
  final workersSnapshot = await dbRef.child('workers').once();
  final workersData = workersSnapshot.snapshot.value as Map?;
  if (workersData == null)
    return {'present': 0, 'absent': 0, 'not_confirmed': 0};

  final workingFormat = DateFormat('dd MMM yyyy');
  final formattedDate = workingFormat.format(date);

  int present = 0;
  int absent = 0;
  int notConfirmed = 0;

  for (final entry in workersData.entries) {
    final worker = entry.value;

    if (worker['division'] == division) {
      final attendance = Map<String, dynamic>.from(worker['attendance'] ?? {});
      final record = attendance[formattedDate];

      if (record == null) {
        absent++;
      } else {
        final checkIn = record['check_in'];
        final checkOut = record['check_out'];

        final hasCheckIn = checkIn?.toString().isNotEmpty ?? false;
        final hasCheckOut = checkOut?.toString().isNotEmpty ?? false;

        if (hasCheckIn && hasCheckOut) {
          present++;
        } else {
          notConfirmed++;
        }
      }
    }
  }

  return {
    'present': present,
    'absent': absent,
    'not_confirmed': notConfirmed,
  };
}

Future<String?> showDivisionPicker(BuildContext context) async {
  final dbRef = FirebaseDatabase.instance.ref();
  final officerEmailsSnapshot = await dbRef.child('officer_emails').once();
  final officerEmails = officerEmailsSnapshot.snapshot.value as Map?;

  if (officerEmails == null || officerEmails.isEmpty) {
    print("No divisions found in the database.");
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Error"),
          content: const Text("No divisions found in the database."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
    return null;
  }

  final divisionList =
      officerEmails.values.toSet().toList(); // Getting unique divisions
  print("Division list: $divisionList");

  return await showDialog<String>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: const Text("Select Division"),
        children: divisionList
            .map((division) => SimpleDialogOption(
                  onPressed: () {
                    print("Selected division: $division");
                    Navigator.pop(context, division);
                  },
                  child: Text(division),
                ))
            .toList(),
      );
    },
  );
}

Future<String?> showDivisionPickerWithAverageOption(
    BuildContext context) async {
  final dbRef = FirebaseDatabase.instance.ref();
  final officerEmailsSnapshot = await dbRef.child('officer_emails').once();
  final officerEmails = officerEmailsSnapshot.snapshot.value as Map?;

  if (officerEmails == null || officerEmails.isEmpty) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Error"),
          content: const Text("No divisions found in the database."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
    return null;
  }

  final divisionList = officerEmails.values.toSet().toList()..sort();
  divisionList.insert(0, "All Divisions (Average)");

  return await showDialog<String>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: const Text("Select Division"),
        children: divisionList.map((division) {
          final value = division == "All Divisions (Average)"
              ? "ALL_DIVISIONS_AVERAGE"
              : division;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, value),
            child: Text(division),
          );
        }).toList(),
      );
    },
  );
}
