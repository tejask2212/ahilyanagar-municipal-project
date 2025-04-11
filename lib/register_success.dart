import 'package:flutter/material.dart';
import 'dart:io';

class RegisterSuccess extends StatelessWidget {
  final String name;
  final String employeeId;
  final String checkInTime;
  final String date;
  final String imagePath;
  final String division;

  RegisterSuccess({
    required this.name,
    required this.employeeId,
    required this.checkInTime,
    required this.date,
    required this.imagePath,
    required this.division,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50, // Light background for contrast
      appBar: AppBar(
        title: Text("Check-In Successful"),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: SingleChildScrollView( // Wrap with SingleChildScrollView to avoid overflow
        child: Center(
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
                    backgroundImage: File(imagePath).existsSync()
                        ? FileImage(File(imagePath)) // If image exists, load it
                        : AssetImage("assets/default_image.png")
                            as ImageProvider, // Default image
                  ),
                  SizedBox(height: 20),
                  Text(
                    "✅ Registration Successful!",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Divider(thickness: 1, color: Colors.grey.shade300),
                  SizedBox(height: 10),
                  infoRow("👤 Name", name),
                  infoRow("🆔 Employee ID", employeeId),
                  infoRow("📍 Division", division),
                  infoRow("⏰ Check-In Time", checkInTime),
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
          // Instead of Expanded, use a flexible approach with overflow handling
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                overflow: TextOverflow.ellipsis, // Handling overflow gracefully
              ),
              maxLines: 1, // Ensuring one line for text
            ),
          ),
        ],
      ),
    );
  }
}
