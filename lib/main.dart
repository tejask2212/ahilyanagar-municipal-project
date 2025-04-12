import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'SplashScreen.dart';
import 'super_admin_home_screen.dart'; // ✅ Import your super admin screen

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
                  return const SplashScreen();
                } else if (divisionSnapshot.hasError) {
                  return Center(child: Text("Error: ${divisionSnapshot.error}"));
                } else if (divisionSnapshot.hasData) {
                  final division = divisionSnapshot.data!;
                  if (division == 'SUPER_ADMIN') {
                    return SuperAdminHomeScreen(); // ✅ Show super admin screen
                  } else {
                    return HomeScreen(division: division);
                  }
                } else {
                  return Center(child: Text("No division data found"));
                }
              },
            );
          } else {
            return LoginScreen();
          }
        }

        return const SplashScreen();
      },
    );
  }

  Future<String> getUserDivision(String uid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Unknown Division';

    final safeEmail = user.email!.replaceAll('.', ',');

    // ✅ Check if the user is a Super Admin
    DatabaseReference superAdminRef = FirebaseDatabase.instance.ref("super_admins/$safeEmail");
    DatabaseEvent superAdminEvent = await superAdminRef.once();
    if (superAdminEvent.snapshot.exists) {
      return 'SUPER_ADMIN';
    }

    // ✅ Otherwise check division
    DatabaseReference officerRef = FirebaseDatabase.instance.ref("officer_emails/$safeEmail");
    DatabaseEvent officerEvent = await officerRef.once();
    if (officerEvent.snapshot.exists && officerEvent.snapshot.value != null) {
      return officerEvent.snapshot.value as String;
    } else {
      return 'Default Division';
    }
  }
}
