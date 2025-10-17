import 'package:cambing_thesis/pages/home/Homepage.dart';
import 'package:cambing_thesis/pages/splash/Splashscreen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize cameras with error handling
  try {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      runApp(MyApp(camera: cameras.first));
    } else {
      runApp(const ErrorApp(errorMessage: 'No cameras found on this device'));
    }
  } catch (e) {
    print('Error initializing cameras: $e');
    runApp(ErrorApp(errorMessage: 'Failed to initialize camera: $e'));
  }
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;
  
  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Splashscreen(
        nextScreen: Home(camera: camera),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String errorMessage;
  
  const ErrorApp({super.key, required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Camera Error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}