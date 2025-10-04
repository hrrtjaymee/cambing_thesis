import 'package:cambing_thesis/pages/home/Homepage.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Don't block the UI - cameras will be initialized when needed
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder<List<CameraDescription>>(
        future: availableCameras(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text('Error: ${snapshot.error}')),
            );
          }
          
          final cameras = snapshot.data!;
          return Scaffold(
            body: Home(camera: cameras[0]),
          );
        },
      ),
    );
  }
}