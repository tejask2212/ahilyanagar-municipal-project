import 'package:flutter/material.dart';

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
              "assets/logo.png", // If you want to use the logo
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
                  null,
                ),
                buildTile(
                  context,
                  "Show Workers",
                  "Get a summarized report of attendance.",
                  Icons.summarize,
                  Colors.green,
                  null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTile(BuildContext context, String title, String subtitle,
      IconData icon, Color color, bool? isCheckIn) {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: Card(
        color: color,
        child: ListTile(
          leading: Icon(icon, color: Colors.white),
          title: Text(title, style: TextStyle(color: Colors.white, fontSize: 18)),
          subtitle: Text(subtitle, style: TextStyle(color: Colors.white70)),
          onTap: () {
            // Handle the tap action for these options
            if (title == "Show Monthly Report") {
              // Navigate to detailed report screen (replace with actual screen)
              print("Navigate to detailed report");
            } else if (title == "Show Workers") {
              // Navigate to generate summary (replace with actual screen)
              print("Navigate to generate summary");
            }
          },
        ),
      ),
    );
  }
}
