import 'package:flutter/material.dart';
import 'check_out_success.dart';

class CheckOutStatusPage extends StatelessWidget {
  final String statusMessage;
  final bool isSuccess;
  final String? name;
  final String? employeeId;
  final String? checkOutTime;
  final String? date;
  final String? imagePath;
  final String? division;

  CheckOutStatusPage({
    required this.statusMessage,
    required this.isSuccess,
    this.name,
    this.employeeId,
    this.checkOutTime,
    this.date,
    this.imagePath,
    this.division,
  });

  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(seconds: isSuccess ? 2 : 3), () {
      if (isSuccess) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CheckOutSuccessPage(
              name: name!,
              employeeId: employeeId!,
              checkOutTime: checkOutTime!,
              division: division!,
              date: date!,
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
