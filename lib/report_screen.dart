import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'monthly_report_screen.dart';

class ReportScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Attendance Report")),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
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
      padding: EdgeInsets.all(8.0),
      child: Card(
        color: color,
        child: ListTile(
          leading: Icon(icon, color: Colors.white),
          title: Text(title, style: TextStyle(color: Colors.white, fontSize: 18)),
          subtitle: Text(subtitle, style: TextStyle(color: Colors.white70)),
          onTap: () async {
            if (title == "Show Monthly Report") {
              String? division = await getUserDivision();
              if (division == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Division not found for user.")),
                );
                return;
              }

              final DateTime? selectedDate = await showMonthYearPicker(context);
              if (selectedDate == null) return;

              final month = selectedDate.month;
              final year = selectedDate.year;

              final workers = await fetchMonthlyAttendanceData(division, month, year);

              int presentCount = workers.where((w) => w['status'] == 'present').length;
              int absentCount = workers.where((w) => w['status'] == 'absent').length;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MonthlyReportScreen(
                    presentCount: presentCount,
                    absentCount: absentCount,
                  ),
                ),
              );
            } else {
              print("Navigate to another screen");
            }
          },
        ),
      ),
    );
  }

  /// Show a custom Month-Year picker using dropdowns
  Future<DateTime?> showMonthYearPicker(BuildContext context) async {
    int selectedMonth = DateTime.now().month;
    int selectedYear = DateTime.now().year;

    return await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Month and Year'),
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
              child: Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text('OK'),
              onPressed: () =>
                  Navigator.pop(context, DateTime(selectedYear, selectedMonth)),
            ),
          ],
        );
      },
    );
  }

  /// Get the logged-in officer's division from Firebase
  Future<String?> getUserDivision() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final email = user.email?.replaceAll('.', ',');
    if (email == null) return null;

    final dbRef = FirebaseDatabase.instance.ref();
    final snapshot = await dbRef.child('officer_emails').child(email).once();

    return snapshot.snapshot.value?.toString();
  }

  /// Fetch attendance for a specific month and year
  Future<List<Map<String, dynamic>>> fetchMonthlyAttendanceData(
      String division, int month, int year) async {
    final dbRef = FirebaseDatabase.instance.ref();
    final workersSnapshot = await dbRef.child('workers').once();

    final workersData = workersSnapshot.snapshot.value as Map<dynamic, dynamic>;

    List<Map<String, dynamic>> workersList = [];

    final dateFormat = DateFormat('dd MMM yyyy');

    workersData.forEach((id, workerData) {
      if (workerData['division'] == division) {
        final attendance = Map<String, dynamic>.from(workerData['attendance'] ?? {});
        bool isPresentInMonth = false;

        attendance.forEach((dateStr, record) {
          try {
            DateTime date = dateFormat.parse(dateStr);
            if (date.month == month && date.year == year) {
              final checkIn = record['check_in'];
              final checkOut = record['check_out'];

              if ((checkIn != null && checkIn.toString().isNotEmpty) ||
                  (checkOut != null && checkOut.toString().isNotEmpty)) {
                isPresentInMonth = true;
              }
            }
          } catch (e) {
            // Skip any bad date format
          }
        });

        workersList.add({
          'name': workerData['name'],
          'status': isPresentInMonth ? 'present' : 'absent',
          'division': workerData['division'],
        });
      }
    });

    return workersList;
  }
}
