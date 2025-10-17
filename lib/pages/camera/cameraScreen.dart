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
  XFile? _capturedImage; // Store the captured image
  FlashMode _currentFlashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    
    // Force landscape orientation when camera opens
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // create a CameraController
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );

    // initialize the controller and lock capture to landscape
    _initializeControllerFuture = _controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
        // Lock to landscapeLeft to match how you're holding the device
        _controller.lockCaptureOrientation(DeviceOrientation.landscapeLeft);
      }
    });
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
      
      // Lock focus and exposure before taking the picture
      await _controller.setFocusMode(FocusMode.locked);
      await _controller.setExposureMode(ExposureMode.locked);
      
      // take a picture and get the file `image`where it was saved.
      final image = await _controller.takePicture();
      
      if (!mounted) return;
      
      // Store the captured image and freeze the screen
      setState(() {
        _capturedImage = image;
      });
      
      // Show confirmation dialog on top of the frozen image
      _showConfirmationDialog(image);
      
    } catch (e) {
      // log the error to the console.
      print(e);
    }
  }

  Future<void> _showConfirmationDialog(XFile image) async {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent, 
      builder: (BuildContext context) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth * 0.65, // 45% of screen width for rectangular shape
              minWidth: screenWidth * 0.50, // Minimum 35% to prevent too narrow
            ),
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 10), // Reduce vertical padding
              titlePadding: const EdgeInsets.fromLTRB(24, 16, 24, 8), // Reduce title padding
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12), // Reduce actions padding
              title: const Text(
                'Confirm Photo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18, // Slightly smaller font
                ),
              ),
              content: const Text(
                'Process this photo for weight analysis?',
                style: TextStyle(fontSize: 14), // Smaller font and shorter text
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text(
                    'Retake',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                File(image.path).deleteSync();
                // Clear the captured image to resume camera preview
                setState(() {
                  _capturedImage = null;
                });
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
                
                // Navigate to processing screen (shows loading screen)
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WeightProcessingScreen(
                      camera: widget.camera,
                      imagePath: image.path,
                    ),
                  ),
                );
              },
            ),
          ],
            ),
          ),
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
        
        // Navigate to processing screen (shows loading screen)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WeightProcessingScreen(
              camera: widget.camera,
              imagePath: image.path,
            ),
          ),
        );
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _toggleFlash() async {
    try {
      // Cycle through flash modes: off -> auto -> always -> torch -> off
      FlashMode newFlashMode;
      switch (_currentFlashMode) {
        case FlashMode.off:
          newFlashMode = FlashMode.auto;
          break;
        case FlashMode.auto:
          newFlashMode = FlashMode.always;
          break;
        case FlashMode.always:
          newFlashMode = FlashMode.torch;
          break;
        case FlashMode.torch:
          newFlashMode = FlashMode.off;
          break;
      }
      
      await _controller.setFlashMode(newFlashMode);
      setState(() {
        _currentFlashMode = newFlashMode;
      });
    } catch (e) {
      print('Error toggling flash: $e');
    }
  }

  IconData _getFlashIcon() {
    switch (_currentFlashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.flashlight_on;
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
                // Show either camera preview or frozen captured image
                Positioned.fill(
                  child: _capturedImage == null
                      ? GestureDetector(
                          onTapDown: (TapDownDetails details) async {
                            // Calculate the tap position relative to the preview
                            final RenderBox renderBox = context.findRenderObject() as RenderBox;
                            final Offset localPosition = renderBox.globalToLocal(details.globalPosition);
                            
                            // Normalize the tap position to [0, 1] range
                            final double x = localPosition.dx / renderBox.size.width;
                            final double y = localPosition.dy / renderBox.size.height;
                            
                            // Set focus point
                            try {
                              await _controller.setFocusPoint(Offset(x, y));
                              await _controller.setExposurePoint(Offset(x, y));
                            } catch (e) {
                              print('Error setting focus: $e');
                            }
                          },
                          child: CameraPreview(_controller), // Live camera preview
                        )
                      : Image.file(                // Frozen captured image
                          File(_capturedImage!.path),
                          fit: BoxFit.cover,
                        ),
                ),
                
                // Yellow bounding box overlay (only show when live preview)
                if (_capturedImage == null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: BoundingBoxPainter(),
                    ),
                  ),
                
                // Upload from gallery button (centered at bottom)
                Positioned(
                  bottom: screenHeight * 0.15,
                  right: screenWidth * 0.025,
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
                  top: screenHeight * 0.001,
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
                
                // Flash button (top right, parallel to back button)
                Positioned(
                  top: screenHeight * 0.001,
                  right: screenWidth * 0.05,
                  child: SafeArea(
                    child: GestureDetector(
                      onTap: _toggleFlash,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha:0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getFlashIcon(),
                          color: _currentFlashMode == FlashMode.off 
                              ? Colors.white 
                              : Colors.yellow,
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
    final double boxHeight = size.height * 0.7;
    final double left = size.width * 0.08; // Move to left (5% from left edge)
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