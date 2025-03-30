import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'scan_page.dart';

class HomeScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Attendance App"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            child: Image.asset(
              "assets/logo.png",
              height: 150, // Increased size
              width: 1580, // Adjust width accordingly
              fit: BoxFit.contain,
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                buildTile(context, "Check-In", "Check-in for your attendance.", Icons.access_time, Colors.blue),
                buildTile(context, "Check-Out", "Check-out to complete your attendance.", Icons.exit_to_app, Colors.green),
                buildTile(context, "Settings", "Application settings, URL and KEY with QR code.", Icons.settings, Colors.teal),
                buildTile(context, "Report", "View your attendance report.", Icons.assignment, Colors.red),
                buildTile(context, "About", "About this App.", Icons.info, Colors.purple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTile(BuildContext context, String title, String subtitle, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.all(8.0),
      child: Card(
        color: color,
        child: ListTile(
          leading: Icon(icon, color: Colors.white),
          title: Text(title, style: TextStyle(color: Colors.white, fontSize: 18)),
          subtitle: Text(subtitle, style: TextStyle(color: Colors.white70)),
          onTap: () {
            if (title == "Check-In" || title == "Check-Out") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ScanPage()),
              );
            }
          },
        ),
      ),
    );
  }
}
