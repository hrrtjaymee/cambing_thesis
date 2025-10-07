import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cambing_thesis/core/theme/colors.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cambing_thesis/pages/weight/weightScreen.dart';

class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({super.key, required this.camera});

  final CameraDescription camera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    
    // Force landscape orientation when camera opens
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // create a CameraController.
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );

    // initialize the controller. 
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Restore original orientation when leaving camera
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _controller.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      
      // take a picture and get the file `image`where it was saved.
      final image = await _controller.takePicture();
      
      if (!mounted) return;
      
      // Show confirmation dialog
      _showConfirmationDialog(image);
      
    } catch (e) {
      // log the error to the console.
      print(e);
    }
  }

  Future<void> _showConfirmationDialog(XFile image) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Confirm Photo',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: const Text(
            'Do you want to process this photo for goat weight analysis?',
            style: TextStyle(fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                File(image.path).deleteSync();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Process Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                
                await SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.portraitDown,
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ]);
                
                // Navigate to weight screen with image path
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Weightscreen(
                      camera: widget.camera,
                      imagePath: image.path, // Pass the image path
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      
      if (image != null && mounted) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        
        // Navigate to weight screen with selected image
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => Weightscreen(
              camera: widget.camera,
              imagePath: image.path, // Pass the image path
            ),
          ),
        );
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _goBack() async {
    // Restore portrait orientation before navigating back
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                Positioned.fill(
                  child: CameraPreview(_controller),
                ),
                
                // Yellow bounding box overlay
                Positioned.fill(
                  child: CustomPaint(
                    painter: BoundingBoxPainter(),
                  ),
                ),
                
                // Upload from gallery button (centered at bottom)
                Positioned(
                  bottom: screenHeight * 0.15,
                  right: screenWidth * 0.03,
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library, color: Colors.black),
                      label: const Text(
                        'Upload from Gallery',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * .009, vertical: screenHeight * .04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(screenWidth * .09),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Capture button (positioned on right side in landscape)
                Positioned(
                  right: screenWidth * 0.07,
                  bottom: screenHeight * 0.35,
                  child: GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      width: screenWidth * 0.12,
                      height: screenWidth * 0.12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Back button
                Positioned(
                  top: screenHeight * 0.06,
                  left: screenWidth * 0.05,
                  child: SafeArea(
                    child: GestureDetector(
                      onTap: _goBack,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha:0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Camera loading
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }
        },
      ),
    );
  }
}

// Custom painter for the yellow bounding box
class BoundingBoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    // Calculate bounding box dimensions (positioned to the left)
    final double boxWidth = size.width * 0.65;
    final double boxHeight = size.height * 0.8;
    final double left = size.width * 0.05; // Move to left (5% from left edge)
    final double top = (size.height - boxHeight) / 2;
    
    // Draw the main rectangle with dashed lines
    _drawDashedRect(canvas, Rect.fromLTWH(left, top, boxWidth, boxHeight), paint);
    
    // Draw corner brackets
    final double cornerLength = 30;
    final paint2 = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    // Top-left corner
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), paint2);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), paint2);
    
    // Top-right corner
    canvas.drawLine(Offset(left + boxWidth - cornerLength, top), Offset(left + boxWidth, top), paint2);
    canvas.drawLine(Offset(left + boxWidth, top), Offset(left + boxWidth, top + cornerLength), paint2);
    
    // Bottom-left corner
    canvas.drawLine(Offset(left, top + boxHeight - cornerLength), Offset(left, top + boxHeight), paint2);
    canvas.drawLine(Offset(left, top + boxHeight), Offset(left + cornerLength, top + boxHeight), paint2);
    
    // Bottom-right corner
    canvas.drawLine(Offset(left + boxWidth - cornerLength, top + boxHeight), Offset(left + boxWidth, top + boxHeight), paint2);
    canvas.drawLine(Offset(left + boxWidth, top + boxHeight), Offset(left + boxWidth, top + boxHeight - cornerLength), paint2);
  }
  
  // Helper method to draw dashed rectangle
  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    const double dashWidth = 20.0;  // Increased from 10.0 to 20.0
    const double dashSpace = 8.0;
    
    // Draw top line (dashed)
    _drawDashedLine(canvas, Offset(rect.left, rect.top), Offset(rect.right, rect.top), dashWidth, dashSpace, paint);
    
    // Draw right line (dashed)
    _drawDashedLine(canvas, Offset(rect.right, rect.top), Offset(rect.right, rect.bottom), dashWidth, dashSpace, paint);
    
    // Draw bottom line (dashed)
    _drawDashedLine(canvas, Offset(rect.right, rect.bottom), Offset(rect.left, rect.bottom), dashWidth, dashSpace, paint);
    
    // Draw left line (dashed)
    _drawDashedLine(canvas, Offset(rect.left, rect.bottom), Offset(rect.left, rect.top), dashWidth, dashSpace, paint);
  }
  
  // Helper method to draw a single dashed line
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, double dashWidth, double dashSpace, Paint paint) {
    final double totalDistance = (end - start).distance;
    final Offset direction = (end - start) / totalDistance;
    
    double currentDistance = 0.0;
    bool drawDash = true;
    
    while (currentDistance < totalDistance) {
      final double segmentLength = drawDash ? dashWidth : dashSpace;
      final double remainingDistance = totalDistance - currentDistance;
      final double actualSegmentLength = segmentLength > remainingDistance ? remainingDistance : segmentLength;
      
      if (drawDash) {
        final Offset segmentStart = start + direction * currentDistance;
        final Offset segmentEnd = start + direction * (currentDistance + actualSegmentLength);
        canvas.drawLine(segmentStart, segmentEnd, paint);
      }
      
      currentDistance += actualSegmentLength;
      drawDash = !drawDash;
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}