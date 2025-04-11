import 'package:ahilyanagar/register_success.dart';
import 'package:flutter/material.dart';
import 'check_in_success.dart';
import 'register_success.dart';

class RegisterStatus extends StatelessWidget {
  final String statusMessage;
  final bool isSuccess;
  final String? name;
  final String? employeeId;
  final String? checkInTime;
  final String? date;
  final String? imagePath;
  final String? division;

  RegisterStatus({
    required this.statusMessage,
    required this.isSuccess,
    this.name,
    this.employeeId,
    this.checkInTime,
    this.date,
    this.imagePath,
    this.division,
  });

  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(seconds: isSuccess ? 2 : 3), () {
      if (!context.mounted) return; // ✅ Prevent navigation error if widget is unmounted

      if (isSuccess) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RegisterSuccess(
              name: name ?? "Unknown", // ✅ Provide default values
              employeeId: employeeId ?? "0000",
              checkInTime: checkInTime ?? "N/A",
              date: date ?? "N/A",
              division: division ?? "N/A",
              imagePath: imagePath ?? "assets/default_image.png",
            ),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isSuccess
                ? Icon(Icons.check_circle, color: Colors.green, size: 100)
                : Icon(Icons.error, color: Colors.red, size: 100),
            SizedBox(height: 20),
            Text(
              statusMessage,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
