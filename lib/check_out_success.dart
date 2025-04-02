import 'package:flutter/material.dart';
import 'dart:io';

class CheckOutSuccessPage extends StatelessWidget {
  final String name;
  final String employeeId;
  final String checkOutTime;
  final String date;
  final String imagePath;

  CheckOutSuccessPage({
    required this.name,
    required this.employeeId,
    required this.checkOutTime,
    required this.date,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      appBar: AppBar(
        title: Text("Check-Out Successful"),
        backgroundColor: Colors.red,
        centerTitle: true,
      ),
      body: Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: Colors.white,
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 50),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      File(imagePath).existsSync()
                          ? FileImage(File(imagePath)) // Use image if it exists
                          : AssetImage("assets/default_image.png")
                              as ImageProvider, // Default image
                ),

                SizedBox(height: 20),
                Text(
                  "✅ Check-Out Successful!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                Divider(thickness: 1, color: Colors.grey.shade300),
                SizedBox(height: 10),
                infoRow("👤 Name", name),
                infoRow("🆔 Employee ID", employeeId),
                infoRow("⏰ Check-Out Time", checkOutTime),
                infoRow("📅 Date", date),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "Go Back",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
