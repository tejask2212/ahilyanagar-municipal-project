import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_screen.dart';
import 'report_screen.dart';
import 'register_worker_screen.dart';
import 'about_screen.dart';
import 'package:intl/intl.dart';

class SuperAdminHomeScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  void showMarkHolidayDialog(BuildContext context) async {
    DateTime? selectedDate;
    String occasion = '';

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text("Mark Holiday"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2022),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) selectedDate = picked;
                },
                child: Text("Select Date"),
              ),
              TextField(
                decoration: InputDecoration(labelText: "Occasion"),
                onChanged: (val) => occasion = val,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (selectedDate != null && occasion.isNotEmpty) {
                  final formattedDate =
                      DateFormat('dd MMMM yyyy').format(selectedDate!);
                  await FirebaseDatabase.instance
                      .ref()
                      .child('holidays')
                      .child(formattedDate)
                      .set({'name': occasion});

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Holiday marked successfully.")),
                  );
                }
              },
              child: Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Super Admin Panel"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Logo section
          Container(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Image.asset(
              "assets/logo.png",
              height: 150,
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
          // Tiles section
          buildTile(
            context,
            "Report",
            "View reports for all workers.",
            Icons.assignment,
            Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReportScreen(divisionOverride: null),
                ),
              );
            },
          ),
          buildTile(
            context,
            "Mark Holiday",
            "Add holidays to the calendar.",
            Icons.event,
            Colors.orange,
            onTap: () => showMarkHolidayDialog(context),
          ),
          buildTile(
            context,
            "Register",
            "Register a new worker with this.",
            Icons.person,
            Colors.teal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      RegisterWorkerScreen(division: 'super_admin'),
                ),
              );
            },
          ),
          buildTile(
            context,
            "About",
            "About this App.",
            Icons.info,
            Colors.purple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AboutScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget buildTile(BuildContext context, String title, String subtitle,
      IconData icon, Color color,
      {required VoidCallback onTap}) {
    return Card(
      color: color,
      margin: EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.white70)),
        onTap: onTap,
      ),
    );
  }
}
