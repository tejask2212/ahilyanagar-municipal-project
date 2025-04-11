import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'SplashScreen.dart'; // ✅ Import your custom splash screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData) {
            return FutureBuilder<String>(
              future: getUserDivision(snapshot.data!.uid),
              builder: (context, divisionSnapshot) {
                if (divisionSnapshot.connectionState == ConnectionState.waiting) {
                  return const SplashScreen(); // ✅ Custom splash instead of spinner
                } else if (divisionSnapshot.hasError) {
                  return Center(child: Text("Error: ${divisionSnapshot.error}"));
                } else if (divisionSnapshot.hasData) {
                  return HomeScreen(division: divisionSnapshot.data!);
                } else {
                  return Center(child: Text("No division data found"));
                }
              },
            );
          } else {
            return LoginScreen();
          }
        }

        // ✅ Show splash screen during initial auth check
        return const SplashScreen();
      },
    );
  }

  Future<String> getUserDivision(String uid) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return 'Unknown Division';

  final safeEmail = user.email!.replaceAll('.', ',');
  DatabaseReference ref = FirebaseDatabase.instance.ref("officer_emails/$safeEmail");
  DatabaseEvent event = await ref.once();

  if (event.snapshot.exists && event.snapshot.value != null) {
    return event.snapshot.value as String;
  } else {
    return 'Default Division';
  }
}
}
