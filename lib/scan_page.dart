import 'package:firebase_database/firebase_database.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';

class ScanPage extends StatefulWidget {
  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool isProcessing = false; // Prevent multiple scans
  String? scannedEmployeeId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Scan QR for Attendance")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "1️⃣ Scan QR Code for Attendance",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => scanQRCode(),
              child: Text("Scan QR"),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Function to Scan QR Code
  void scanQRCode() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text("Scanning..."),
          content: SizedBox(
            height: 300,
            child: MobileScanner(
              onDetect: (BarcodeCapture capture) {
                if (!isProcessing) {
                  isProcessing = true;
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String? employeeId = barcodes.first.rawValue;
                    if (employeeId != null) {
                      setState(() {
                        scannedEmployeeId = employeeId;
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("QR Scanned: $employeeId")),
                      );

                      // ✅ Mark attendance after QR scan
                      markAttendance(employeeId);
                    }
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }

  // 🔹 Function to Mark Attendance
  void markAttendance(String employeeId) async {
    DateTime now = DateTime.now();
    String formattedDate = "${now.day}-${now.month}-${now.year}";
    String formattedTime = _formatTime(now);

    DatabaseReference ref = FirebaseDatabase.instance.ref("workers/$employeeId/attendance/$formattedDate");

    DatabaseEvent event = await ref.once();
    if (event.snapshot.exists && (event.snapshot.value as Map).containsKey("check_in")) {
      await ref.update({"check_out": formattedTime});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Check-Out recorded at $formattedTime")),
      );
    } else {
      await ref.update({"check_in": formattedTime});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Check-In recorded at $formattedTime")),
      );
    }
  }

  // 🔹 Helper function to format time
  String _formatTime(DateTime time) {
    int hour = time.hour;
    String period = hour >= 12 ? "PM" : "AM";
    hour = hour % 12;
    if (hour == 0) hour = 12;
    String minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute $period";
  }
}
