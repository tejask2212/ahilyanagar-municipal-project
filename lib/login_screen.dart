import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'home_screen.dart';
import 'signup_screen.dart';
import 'super_admin_home_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String errorMessage = '';

  void login() async {
    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final emailKey = email.replaceAll('.', ',');
      final dbRef = FirebaseDatabase.instance.ref();

      // Check if super admin
      final superAdminSnapshot = await dbRef.child('super_admins/$emailKey').once();
      if (superAdminSnapshot.snapshot.exists) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SuperAdminHomeScreen()),
        );
        return;
      }

      // Else, check division officer
      final divisionSnapshot = await dbRef.child('officer_emails/$emailKey').once();
      if (divisionSnapshot.snapshot.exists) {
        String division = divisionSnapshot.snapshot.value.toString();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(division: division)),
        );
      } else {
        setState(() => errorMessage = "No division assigned to this officer.");
      }
    } catch (e) {
      setState(() => errorMessage = "Invalid credentials! Please try again.");
    }
  }

  void resetPassword() async {
    if (emailController.text.trim().isEmpty) {
      setState(() => errorMessage = "Enter your email to reset password.");
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password reset link sent to your email.")),
      );
    } catch (e) {
      setState(() => errorMessage = "Error: Unable to send reset email.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Login")),
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset("assets/AMC.png", height: 100),
              SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: "Email"),
              ),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(labelText: "Password"),
                obscureText: true,
              ),
              SizedBox(height: 10),
              Text(errorMessage, style: TextStyle(color: Colors.red)),
              SizedBox(height: 10),
              ElevatedButton(onPressed: login, child: Text("Login")),
              TextButton(
                onPressed: resetPassword,
                child: Text("Forgot Password?"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SignUpScreen()));
                },
                child: Text("Don't have an account? Sign Up here"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
