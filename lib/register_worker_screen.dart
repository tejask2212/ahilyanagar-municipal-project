import 'package:ahilyanagar/register_status.dart';
import 'package:ahilyanagar/scan_page.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'check_in_status.dart';
import 'check_in_success.dart';
import 'package:camera/camera.dart';
import 'check_out_status.dart';
import 'check_out_success.dart';
import 'dart:math';
import 'dart:io'; // Required for File operations
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class RegisterWorkerScreen extends StatefulWidget {
  final String division;

  RegisterWorkerScreen({required this.division});
  @override
  _RegisterWorkerScreenState createState() => _RegisterWorkerScreenState();
}

class _RegisterWorkerScreenState extends State<RegisterWorkerScreen> {
  final ImagePicker _picker = ImagePicker();
  Interpreter? _interpreter;
  bool isProcessing = false;
  String? scannedWorkerId;
  bool faceVectorExists = false;

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/mobile_face_net.tflite',
      );
    } catch (e) {
      print("Error loading model: $e");
    }
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Scan QR Code"),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // SVG Image
          Center(
            child: SvgPicture.asset('assets/scan_selfie.svg', height: 200),
          ),

          SizedBox(height: 30),
          // Scan QR Button
          ElevatedButton(
            onPressed: () => scanQRCode(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            child: Text(
              "Scan QR",
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> scanQRCode() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text("Scanning..."),
          content: SizedBox(
            height: 300,
            child: MobileScanner(
              onDetect: (BarcodeCapture capture) async {
                if (!isProcessing) {
                  isProcessing = true;
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String? workerId = barcodes.first.rawValue;
                    if (workerId != null) {
                      setState(() {
                        scannedWorkerId = workerId;
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("QR Scanned: $workerId")),
                      );

                      await checkWorkerData(workerId);
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

  void showAddFaceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Face Not Registered"),
        content: Text("No face record found. Please add a face."),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await registerWorker(scannedWorkerId!);
            },
            child: Text("Add Face"),
          ),
        ],
      ),
    );
  }

  void showFaceScanDialog() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CheckInStatusPage(
          statusMessage: "⚠️ Worker is already registered",
          isSuccess: false,
        ),
      ),
    );
  }

  Future<void> checkWorkerData(String workerId) async {
    DatabaseReference ref = FirebaseDatabase.instance.ref("workers/$workerId");
    DatabaseEvent event = await ref.once();

    if (event.snapshot.exists && event.snapshot.value != null) {
      var data = event.snapshot.value as Map<dynamic, dynamic>;

      setState(() {
        faceVectorExists = data.containsKey("feature_vector");
        scannedWorkerId = workerId;
        String division = data["division"] ?? "Not Specified";
        print("Division: $division");
      });

      if (faceVectorExists) {
        showFaceScanDialog();
      } else {
        showAddFaceDialog();
      }
    } else {
      await registerWorker(workerId);
    }
  }

  List<double> normalizeVector(List<double> vector) {
    double norm = sqrt(vector.fold(0, (sum, v) => sum + v * v));
    return norm == 0 ? vector : vector.map((v) => v / norm).toList();
  }

  double cosineSimilarity(List<double> vectorA, List<double> vectorB) {
    if (vectorA.length != vectorB.length) return -1;

    double dotProduct = 0.0;
    for (int i = 0; i < vectorA.length; i++) {
      dotProduct += vectorA[i] * vectorB[i];
    }
    return dotProduct; // Already normalized
  }

  Future<void> registerWorker(String workerId) async {
    String? workerName = await promptForInput("Enter Worker Name");
    if (workerName == null || workerName.isEmpty) return;

    String? mobileNumber = await promptForInput("Enter Mobile Number");
    if (mobileNumber == null || mobileNumber.isEmpty) return;

    String? division = await promptForDivision();
    if (division == null || division.isEmpty) return;

    img.Image? faceImage = await captureAndDetectFace();
    if (faceImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No face detected. Please try again.")),
      );
      return;
    }

    if (_interpreter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Model not loaded. Please try again later.")),
      );
      return;
    }

    List<double> featureVector = await compute(
      extractFeatureVectorTopLevel,
      FeatureExtractionData(faceImage: faceImage, interpreter: _interpreter!),
    );

    if (featureVector.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Feature extraction failed. Try again.")),
      );
      return;
    }

    DatabaseReference ref = FirebaseDatabase.instance.ref("workers/$workerId");

    await ref.set({
      "worker_id": workerId,
      "name": workerName,
      "mobile": mobileNumber,
      "division": division,
      "feature_vector": featureVector.join(','),
    }).then((_) async {
      setState(() {
        faceVectorExists = true;
      });

      DateTime now = DateTime.now();
      String formattedDate = DateFormat("dd MMM yyyy").format(now);
      String formattedTime = DateFormat("hh:mm a").format(now);

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/registered_face.jpg';
      final file = File(filePath);
      await file.writeAsBytes(img.encodeJpg(faceImage));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RegisterStatus(
            statusMessage: "✅ Worker Registered Successfully",
            isSuccess: true,
            name: workerName,
            employeeId: workerId,
            division: division,
            date: formattedDate,
            imagePath: filePath,
          ),
        ),
      );

      // ✅ Delay for 2 seconds, then return to the home screen
      Future.delayed(Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.pop(context); // Go back to the previous screen
      });
    }).catchError((error) {
      print("Firebase Write Error: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error storing worker data. Try again.")),
      );
    });
  }

  Future<String?> promptForDivision() async {
    List<String> divisions = [
      "Chhatrapati Sambhajinagar",
      "Satara",
      "Dhule",
      "Pune",
      "Khau Gali",
      "Sinhagad Road"
    ]; // List of divisions
    String? selectedDivision = divisions.first;

    return await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Select Division"),
              content: DropdownButton<String>(
                value: selectedDivision,
                onChanged: (String? newValue) {
                  setState(() {
                    selectedDivision = newValue;
                  });
                },
                items:
                    divisions.map<DropdownMenuItem<String>>((String division) {
                  return DropdownMenuItem<String>(
                    value: division,
                    child: Text(division),
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, selectedDivision);
                  },
                  child: Text("OK"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, null);
                  },
                  child: Text("Cancel"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> promptForInput(String title) async {
    TextEditingController controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: title),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, controller.text.trim());
              },
              child: Text("OK"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, null);
              },
              child: Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  Future<img.Image?> captureAndDetectFace() async {
    try {
      // Try to get image from either camera
      final XFile? pickedImage = await _getImageWithRetry();
      if (pickedImage == null) return null;

      // Process the image with proper error handling
      return await _processCapturedImage(pickedImage);
    } catch (e, stackTrace) {
      print("Error in captureAndDetectFace: $e");
      print("Stack trace: $stackTrace");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error capturing image. Please try again.")),
        );
      }
      return null;
    }
  }

  static List<double> extractFeatureVectorTopLevel(FeatureExtractionData data) {
    return extractFeatureVector(data.faceImage, data.interpreter);
  }

  // Feature extraction logic
  static List<double> extractFeatureVector(
    img.Image face,
    Interpreter interpreter,
  ) {
    img.Image resizedFace = img.copyResize(face, width: 112, height: 112);
    var input = Float32List(112 * 112 * 3);
    var buffer = input.buffer.asFloat32List();

    for (int y = 0; y < 112; y++) {
      for (int x = 0; x < 112; x++) {
        var pixel = resizedFace.getPixel(x, y);
        int index = (y * 112 + x) * 3;
        buffer[index] = pixel.r / 255.0;
        buffer[index + 1] = pixel.g / 255.0;
        buffer[index + 2] = pixel.b / 255.0;
      }
    }

    var output = List.filled(192, 0.0).reshape([1, 192]);
    interpreter.run(input.reshape([1, 112, 112, 3]), output);
    return output[0];
  }

  Future<XFile?> _getImageWithRetry() async {
    try {
      final frontImage = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (frontImage != null) {
        print("Front camera image captured: ${frontImage.path}");
        return frontImage;
      }
    } catch (e) {
      print("Front camera attempt failed: $e");
    }

    try {
      final backImage = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (backImage != null) {
        print("Back camera image captured: ${backImage.path}");
        return backImage;
      }
    } catch (e) {
      print("Back camera attempt failed: $e");
    }

    return null;
  }

  Future<img.Image?> _processCapturedImage(XFile pickedImage) async {
    try {
      final imageBytes = await pickedImage.readAsBytes();
      img.Image? image =
          await _decodeImageWithOrientation(imageBytes, pickedImage.path);
      if (image == null) return null;

      final faces = await _detectFaces(pickedImage.path);
      print("Number of faces detected: ${faces.length}");

      if (faces.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("No face detected! Please try again.")),
          );
        }
        return null;
      }

      return _processBestFace(image, faces);
    } catch (e) {
      print("Error processing captured image: $e");
      return null;
    }
  }

  Future<img.Image?> _decodeImageWithOrientation(
      Uint8List bytes, String path) async {
    try {
      // First attempt to decode normally
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      // Apply orientation correction
      return img.bakeOrientation(image);
    } catch (e) {
      print("Error decoding image with orientation: $e");
      return null;
    }
  }

  Future<List<Face>> _detectFaces(String imagePath) async {
    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode:
            FaceDetectorMode.fast, // Changed to fast for back camera
        enableContours: true, // Helps with rotated faces
        enableClassification: false,
        minFaceSize: 0.15, // Smaller minimum face size
      ),
    );

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      return await faceDetector.processImage(inputImage);
    } finally {
      faceDetector.close();
    }
  }

  img.Image _processBestFace(img.Image image, List<Face> faces) {
    // Find the most centered face
    Face bestFace = faces.reduce((a, b) {
      final aCenter = _faceCenter(a, image.width, image.height);
      final bCenter = _faceCenter(b, image.width, image.height);
      final imageCenter = Point(image.width / 2, image.height / 2);

      final aDistance = _distance(aCenter, imageCenter);
      final bDistance = _distance(bCenter, imageCenter);

      return aDistance < bDistance ? a : b;
    });

    // Add padding around the face
    final padding =
        min(bestFace.boundingBox.width, bestFace.boundingBox.height) * 0.25;

    final rect = Rect.fromLTRB(
      max(0, bestFace.boundingBox.left - padding),
      max(0, bestFace.boundingBox.top - padding),
      min(image.width.toDouble(), bestFace.boundingBox.right + padding),
      min(image.height.toDouble(), bestFace.boundingBox.bottom + padding),
    );

    return img.copyCrop(
      image,
      x: rect.left.toInt(),
      y: rect.top.toInt(),
      width: rect.width.toInt(),
      height: rect.height.toInt(),
    );
  }

  Point<double> _faceCenter(Face face, int imageWidth, int imageHeight) {
    return Point(
      face.boundingBox.left + face.boundingBox.width / 2,
      face.boundingBox.top + face.boundingBox.height / 2,
    );
  }

  double _distance(Point<double> a, Point<double> b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  Future<img.Image?> _processImageFile(String imagePath) async {
    try {
      // Read and properly orient the image
      final File imageFile = File(imagePath);
      final Uint8List bytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        print("Failed to decode image");
        return null;
      }

      // Apply orientation correction
      image = img.bakeOrientation(image);

      // Face detection
      final inputImage = InputImage.fromFilePath(imagePath);
      final faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableContours: false,
          enableClassification: false,
        ),
      );

      final faces = await faceDetector.processImage(inputImage);
      faceDetector.close();

      if (faces.isEmpty) {
        print("No faces detected");
        return null;
      }

      // Process the largest face
      return _cropLargestFace(image, faces);
    } catch (e) {
      print("Error processing image: $e");
      return null;
    }
  }

  img.Image _cropLargestFace(img.Image image, List<Face> faces) {
    // Find largest face
    Face largestFace = faces.reduce((a, b) =>
        (a.boundingBox.width * a.boundingBox.height) >
                (b.boundingBox.width * b.boundingBox.height)
            ? a
            : b);

    // Add 20% padding
    final padding =
        min(largestFace.boundingBox.width, largestFace.boundingBox.height) *
            0.2;

    final rect = Rect.fromLTRB(
      max(0, largestFace.boundingBox.left - padding),
      max(0, largestFace.boundingBox.top - padding),
      min(image.width.toDouble(), largestFace.boundingBox.right + padding),
      min(image.height.toDouble(), largestFace.boundingBox.bottom + padding),
    );

    return img.copyCrop(
      image,
      x: rect.left.toInt(),
      y: rect.top.toInt(),
      width: rect.width.toInt(),
      height: rect.height.toInt(),
    );
  }

  img.Image cropFace(img.Image image, Rect faceBounds) {
    int x = max(0, faceBounds.left.toInt());
    int y = max(0, faceBounds.top.toInt());
    int width = min(image.width - x, faceBounds.width.toInt());
    int height = min(image.height - y, faceBounds.height.toInt());

    return img.copyCrop(image, x: x, y: y, width: width, height: height);
  }

  img.Image _fixImageRotation(img.Image image, String path) {
    var decodedImage = img.decodeImage(File(path).readAsBytesSync());
    if (decodedImage == null) return image;
    return img.bakeOrientation(decodedImage);
  }
}

// Helper class to pass data to the isolate
class FeatureExtractionData {
  final img.Image faceImage;
  final Interpreter interpreter;

  FeatureExtractionData({required this.faceImage, required this.interpreter});
}
