import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'home_screen.dart'; // Replace with the screen you want after login
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(),  // Use AuthWrapper for user authentication check
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Check if the user is already logged in
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          if (snapshot.hasData) {
            // If the user is logged in, fetch the user's division (or other necessary data)
            // Example of fetching the division from Firebase:
            return FutureBuilder<String>(
              future: getUserDivision(snapshot.data!.uid), // Your function to get the division
              builder: (context, divisionSnapshot) {
                if (divisionSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (divisionSnapshot.hasError) {
                  return Center(child: Text("Error: ${divisionSnapshot.error}"));
                } else if (divisionSnapshot.hasData) {
                  // Pass the division value to HomeScreen
                  return HomeScreen(division: divisionSnapshot.data!);
                } else {
                  return Center(child: Text("No division data found"));
                }
              },
            );
          } else {
            // If no user is logged in, show the LoginScreen
            return LoginScreen();
          }
        }

        // While checking auth state, show loading indicator
        return Center(child: CircularProgressIndicator());
      },
    );
  }

  Future<String> getUserDivision(String uid) async {
    // Fetch the division from your Firebase database or other source
    // Example: return Firebase database or shared preferences for division.
    // Replace this with your actual logic to fetch the division from the user's data.
    DatabaseReference ref = FirebaseDatabase.instance.ref("users/$uid/division");
    DatabaseEvent event = await ref.once();
    
    if (event.snapshot.exists && event.snapshot.value != null) {
      return event.snapshot.value as String;
    } else {
      return 'Default Division'; // Default or error handling
    }
  }
}
