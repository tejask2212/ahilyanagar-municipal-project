import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'login_screen.dart';
import 'register_worker_screen.dart';
import 'about_screen.dart';
import 'report_screen.dart';
import 'scan_page.dart';

class HomeScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String division;
  static Map<String, dynamic>? _cachedRegionCenter;

  HomeScreen({required this.division});

  void logout(BuildContext context) async {
    await _auth.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }

  Future<Map<String, dynamic>?> _fetchRegionCenter() async {
    // Return cached data if available
    if (_cachedRegionCenter != null) {
      return _cachedRegionCenter;
    }

    try {
      final DatabaseReference ref =
          FirebaseDatabase.instance.ref('regions/$division');
      final DataSnapshot snapshot =
          await ref.get().timeout(const Duration(seconds: 5));

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>?;

        if (data != null &&
            data.containsKey('latitude') &&
            data.containsKey('longitude')) {
          _cachedRegionCenter = {
            'lat': data['latitude'] is num
                ? data['latitude'].toDouble()
                : double.tryParse(data['latitude'].toString()) ?? 0.0,
            'lng': data['longitude'] is num
                ? data['longitude'].toDouble()
                : double.tryParse(data['longitude'].toString()) ?? 0.0,
            'radius': data['radius'] is num
                ? data['radius'].toDouble()
                : double.tryParse(data['radius']?.toString() ?? '100') ??
                    200.0, // Adjust radius to 100 meters
          };
          return _cachedRegionCenter;
        } else {
          debugPrint('Error: Missing latitude or longitude in Firebase data.');
          return null;
        }
      } else {
        debugPrint('Error: Region data does not exist in Firebase.');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching region center: $e');
      return null;
    }
  }

  Future<bool> _checkLocationPermission(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Please enable location services. Opening settings...')),
        );
        await Geolocator
            .openLocationSettings(); // 💡 Opens location settings screen
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Location permission permanently denied')),
        );
      }
      return false;
    }

    return true;
  }

  Future<bool> isWithinGeofence(BuildContext context) async {
    try {
      // Check permissions first
      if (!await _checkLocationPermission(context)) {
        return false;
      }

      // Get current position with high accuracy
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best, // Use high accuracy
        ).timeout(const Duration(seconds: 10)); // Increase timeout
      } catch (e) {
        position = await Geolocator.getLastKnownPosition();
        if (position == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Unable to determine device location: $e')),
            );
          }
          return false;
        }
      }

      // Fetch region center (cached if possible)
      Map<String, dynamic>? regionCenter = await _fetchRegionCenter();

      if (regionCenter == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Region not configured in Firebase')),
          );
        }
        return false;
      }

      // Calculate distance
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        regionCenter['lat']!,
        regionCenter['lng']!,
      );

      debugPrint(
          'Current Position: ${position.latitude}, ${position.longitude}');
      debugPrint(
          'Region Center: ${regionCenter['lat']}, ${regionCenter['lng']}');
      debugPrint('Distance: $distance meters');

      // Check if within geofence
      if (distance > regionCenter['radius']) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('You are not within the allowed area')),
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking location: $e')),
        );
      }
      return false;
    }
  }

  Future<void> _handleTileTap(
      BuildContext context, String title, bool? isCheckIn) async {
    if (isCheckIn != null) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      try {
        if (await isWithinGeofence(context)) {
          if (context.mounted) {
            Navigator.pop(context); // Close dialog
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ScanPage(isCheckIn: isCheckIn, officerDivision: division),
              ),
            );
          }
        } else {
          if (context.mounted) {
            Navigator.pop(context); // Close dialog
          }
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    } else {
      Widget? destination;
      switch (title) {
        case "Register":
          destination = RegisterWorkerScreen(division: division);
          break;
        case "Report":
          destination = ReportScreen();
          break;
        case "About":
          destination = AboutScreen();
          break;
      }
      if (destination != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination!),
        );
      }
    }
  }

  Widget buildTile(BuildContext context, String title, String subtitle,
      IconData icon, Color color, bool? isCheckIn) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: color,
        child: ListTile(
          leading: Icon(icon, color: Colors.white),
          title: Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 18)),
          subtitle:
              Text(subtitle, style: const TextStyle(color: Colors.white70)),
          onTap: () => _handleTileTap(context, title, isCheckIn),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance App"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Image.asset(
              "assets/logo.png",
              height: 150,
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.error, size: 150),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                buildTile(
                  context,
                  "Check-In",
                  "Check-in for your attendance.",
                  Icons.access_time,
                  Colors.blue,
                  true,
                ),
                buildTile(
                  context,
                  "Check-Out",
                  "Check-out to complete your attendance.",
                  Icons.exit_to_app,
                  Colors.green,
                  false,
                ),
                buildTile(
                  context,
                  "Register",
                  "Register a new worker with this.",
                  Icons.person,
                  Colors.teal,
                  null,
                ),
                buildTile(
                  context,
                  "Report",
                  "View your attendance report.",
                  Icons.assignment,
                  Colors.red,
                  null,
                ),
                buildTile(
                  context,
                  "About",
                  "About this App.",
                  Icons.info,
                  Colors.purple,
                  null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
