import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'worker_calendar_screen.dart';

class WorkerReportScreen extends StatefulWidget {
  final String division;
  WorkerReportScreen({required this.division});

  @override
  _WorkerReportScreenState createState() => _WorkerReportScreenState();
}

class _WorkerReportScreenState extends State<WorkerReportScreen> {
  List<Map<String, dynamic>> workers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadWorkers();
  }

  Future<void> loadWorkers() async {
    final dbRef = FirebaseDatabase.instance.ref();
    final snapshot = await dbRef.child('workers').once();

    final data = snapshot.snapshot.value as Map?;
    if (data == null) return;

    List<Map<String, dynamic>> filtered = [];

    data.forEach((key, value) {
      if (value['division'] == widget.division) {
        filtered.add({'id': key, 'name': value['name']});
      }
    });

    setState(() {
      workers = filtered;
      loading = false;
    });
  }

  void onWorkerSelected(Map<String, dynamic> worker) async {
    final DateTimeRange? pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
      helpText: 'Select Attendance Date Range',
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkerCalendarScreen(
            workerId: worker['id'],
            workerName: worker['name'],
            startDate: pickedRange.start,
            endDate: pickedRange.end,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("Select Worker"),
        backgroundColor: Colors.teal,
        elevation: 0,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: Colors.teal))
          : workers.isEmpty
              ? Center(child: Text("No workers found"))
              : ListView.builder(
                  padding: EdgeInsets.all(12),
                  itemCount: workers.length,
                  itemBuilder: (_, index) {
                    final worker = workers[index];
                    return GestureDetector(
                      onTap: () => onWorkerSelected(worker),
                      child: Card(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          leading: CircleAvatar(
                            backgroundColor: Colors.teal,
                            child: Text(
                              worker['name'][0].toUpperCase(),
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            worker['name'],
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          trailing: Icon(Icons.calendar_today, color: Colors.teal),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
