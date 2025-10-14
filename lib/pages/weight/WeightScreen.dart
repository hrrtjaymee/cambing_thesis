import 'package:cambing_thesis/core/theme/colors.dart';
import 'package:cambing_thesis/pages/camera/cameraScreen.dart';
import 'package:cambing_thesis/pages/history/historyScreen.dart';
import 'package:cambing_thesis/pages/weight/weightModel.dart';
import 'package:cambing_thesis/pages/weight/yolov8_processor.dart';
import 'package:cambing_thesis/pages/weight/model_preprocessor.dart';
import 'package:cambing_thesis/utils/image_metadata_helper.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cambing_thesis/pages/loading/Loadingscreen.dart';

class Weightscreen extends StatefulWidget {
  const Weightscreen({
    super.key, 
    required this.camera,
    this.imagePath,
    this.predictedWeight,
    this.segmentedImage, // Add segmented image parameter
  });

  final CameraDescription camera;
  final String? imagePath;
  final double? predictedWeight;
  final img.Image? segmentedImage; // Segmented image with red overlay

  @override
  State<Weightscreen> createState() {
    return _WeightScreenState();
  }
}

class _WeightScreenState extends State<Weightscreen> {
  final ImagePicker _picker = ImagePicker();
  String _weightDisplay = "---";
  img.Image? _processedImage;

  @override
  void initState() {
    super.initState();
    // If weight is already computed, display it
    if (widget.predictedWeight != null) {
      _weightDisplay = widget.predictedWeight!.toStringAsFixed(1);
    }
    // Store the segmented image
    if (widget.segmentedImage != null) {
      _processedImage = widget.segmentedImage;
    }
  }

  void backOnPressed(BuildContext context) {
    Navigator.pop(context);
  }

  void historyOnPressed(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen())
    );
  }

  void cameraOnPressed(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TakePictureScreen(camera: widget.camera))
    );
  }

  void galleryOnPressed() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      
      if (image != null && mounted) {
        // Navigate to processing screen (will show loading screen)
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
      print('Error picking image from gallery: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top image section - display segmented goat image with red overlay (55% of available space)
            Expanded(
              flex: 55,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                child: _processedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        img.encodeJpg(_processedImage!),
                        fit: BoxFit.contain,
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                      ),
                    ),
              ),
            ),
            
            // Bottom section - weight display and actions (45% of available space)
            Expanded(
              flex: 45,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Weight display section
                    Column(
                      children: [
                        Text(
                          "Your goat weighs",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            Text(
                              _weightDisplay,
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFFA500), // Orange/yellow color
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "kilograms",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    // Action buttons
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Redo button - reprocess the image from YOLOv8
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey[400]!, width: 2),
                              ),
                              child: IconButton(
                                onPressed: () {
                                  if (widget.imagePath != null) {
                                    // Reprocess the same image
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => WeightProcessingScreen(
                                          camera: widget.camera,
                                          imagePath: widget.imagePath!,
                                        ),
                                      ),
                                    );
                                  } else {
                                    // Fallback to camera if no image path
                                    cameraOnPressed(context);
                                  }
                                },
                                icon: const Icon(Icons.refresh, size: 32),
                                color: Colors.grey[700],
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                            const SizedBox(width: 32),
                            // Delete button - go back to previous screen
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey[400]!, width: 2),
                              ),
                              child: IconButton(
                                onPressed: () => backOnPressed(context),
                                icon: const Icon(Icons.delete_outline, size: 32),
                                color: Colors.grey[700],
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Save button
                        TextButton(
                          onPressed: _saveWeight,
                          child: const Text(
                            "SAVE",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveWeight() async {
    if (_processedImage == null || _weightDisplay == "---" || _weightDisplay == "Error") {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid weight to save'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Create directory
      final directory = Directory('/storage/emulated/0/Pictures/CambingThesis');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Create filename with format: cambing_YYYYMMDD_HHMMSS
      final now = DateTime.now();
      final dateTimeStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final filePath = '${directory.path}/cambing_$dateTimeStr.jpg';
      
      // Save the image
      final imageBytes = img.encodeJpg(_processedImage!);
      await File(filePath).writeAsBytes(imageBytes);

      // Save EXIF metadata
      await ImageMetadataHelper.saveMetadata(
        imagePath: filePath,
        weight: _weightDisplay,
        isSegmented: true,
      );

      // Notify Android MediaStore to scan the new file
      try {
        const platform = MethodChannel('com.example.cambing_thesis/gallery');
        await platform.invokeMethod('scanFile', {'path': filePath});
        print('📱 MediaStore notified about new file');
      } catch (e) {
        print('⚠️ Could not notify MediaStore: $e');
      }

      print('💾 Image saved: $filePath');
      print('📝 EXIF metadata written: weight=$_weightDisplay kg, segmented=true, date=${now.toIso8601String()}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: ${_weightDisplay} kg to Gallery'),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate back to home screen
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      print('❌ Error saving image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save image: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

/// Processing Screen - Shows loading screen while processing image
class WeightProcessingScreen extends StatefulWidget {
  WeightProcessingScreen({
    super.key,
    required this.camera,
    required this.imagePath,
  }) {
    print('🏗️ WeightProcessingScreen constructor called with imagePath: $imagePath');
  }

  final CameraDescription camera;
  final String imagePath;

  @override
  State<WeightProcessingScreen> createState() {
    print('🔧 Creating WeightProcessingScreen state');
    return _WeightProcessingScreenState();
  }
}

class _WeightProcessingScreenState extends State<WeightProcessingScreen> {
  final YOLOv8Processor _yolov8Processor = YOLOv8Processor();
  final ResNetPreprocessor _resnetPreprocessor = ResNetPreprocessor(
    targetWidth: 224,
    targetHeight: 224,
  );
  GoatWeightModel? _weightModel;

  @override
  void initState() {
    super.initState();
    print('🎬 WeightProcessingScreen initialized');
    // Start processing after a frame to ensure UI is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processImagePipeline();
    });
  }

  Future<void> _processImagePipeline() async {
    img.Image? segmentedImageResult;
    
    try {
      print('🔄 Starting image processing pipeline...');
      
      // Ensure loading screen is visible for at least a moment
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Load models
      print('📦 Loading YOLOv8 model...');
      await _yolov8Processor.loadModel();
      print('✅ YOLOv8 model loaded');
      
      print('📦 Loading weight prediction model...');
      _weightModel = GoatWeightModel();
      await _weightModel!.loadModel();
      print('✅ Weight model loaded');

      // Load image
      print('🖼️ Loading image from ${widget.imagePath}');
      final imageBytes = await File(widget.imagePath).readAsBytes();
      final originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        print('❌ Failed to decode image');
        throw Exception('Failed to decode image');
      }
      print('✅ Image loaded: ${originalImage.width}x${originalImage.height}');

      // YOLOv8 segmentation
      print('🔍 Running YOLOv8 segmentation...');
      final segmentedImage = await _yolov8Processor.processImage(originalImage);

      if (segmentedImage == null) {
        print('❌ No goat detected in image');
        _navigateToResult(null, null, error: "No goat detected");
        return;
      }
      print('✅ Segmentation complete');
      
      segmentedImageResult = segmentedImage;

      // Preprocess for ResNet
      print('⚙️ Preprocessing for weight prediction...');
      final preprocessedData = _resnetPreprocessor.preprocess(segmentedImage);
      print('✅ Preprocessing complete');

      // Predict weight
      print('🧮 Predicting weight...');
      final weight = _weightModel!.predict(preprocessedData, [1, 224, 224, 3]);
      print('✅ Weight predicted: ${weight.toStringAsFixed(1)} kg');

      print('✅ Processing complete! Navigating to result screen...');
      _navigateToResult(weight, segmentedImageResult);
    } catch (e) {
      print('❌ Error in image pipeline: $e');
      _navigateToResult(null, segmentedImageResult, error: "Processing failed");
    }
  }

  void _navigateToResult(double? weight, img.Image? segmentedImage, {String? error}) {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Weightscreen(
          camera: widget.camera,
          predictedWeight: weight,
          segmentedImage: segmentedImage,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _yolov8Processor.dispose();
    _weightModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('🎨 Building WeightProcessingScreen with loading screen');
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Loadingscreen(),
        ),
      ),
    );
  }
}
