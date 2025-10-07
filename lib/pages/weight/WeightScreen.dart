import 'package:cambing_thesis/core/theme/colors.dart';
import 'package:cambing_thesis/pages/camera/cameraScreen.dart';
import 'package:cambing_thesis/pages/history/historyScreen.dart';
import 'package:cambing_thesis/pages/weight/weightModel.dart';
import 'package:cambing_thesis/pages/weight/yolov8_processor.dart';
import 'package:cambing_thesis/pages/weight/resnet_preprocessor.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:cambing_thesis/core/theme/text_styles.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class Weightscreen extends StatefulWidget {
  const Weightscreen({
    super.key, 
    required this.camera,
    this.imagePath,
  });

  final CameraDescription camera;
  final String? imagePath;

  @override
  State<Weightscreen> createState() {
    return _WeightScreenState();
  }
}

class _WeightScreenState extends State<Weightscreen> {
  final YOLOv8Processor _yolov8Processor = YOLOv8Processor();
  final ResNetPreprocessor _resnetPreprocessor = ResNetPreprocessor(
    targetWidth: 224,
    targetHeight: 224,
  );
  GoatWeightModel? _weightModel;
  
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String _weightDisplay = "---";
  String _currentStep = "";

  @override
  void initState() {
    super.initState();
    _initializeModels();
  }

  Future<void> _initializeModels() async {
    _updateStatus("Initializing models...", processing: true);

    try {
      // Load YOLOv8 model
      await _yolov8Processor.loadModel();
      
      // Load weight prediction model
      _weightModel = GoatWeightModel();
      await _weightModel!.loadModel();

      _updateStatus("Models ready", displayText: "Ready", processing: false);

      // If image path provided, process it
      if (widget.imagePath != null) {
        await _processImagePipeline();
      }
    } catch (e) {
      print('Error initializing models: $e');
      _updateStatus("Model loading failed", displayText: "Error", processing: false);
    }
  }

  /// Complete ML Pipeline:
  /// 1. Load image from gallery/camera
  /// 2. YOLOv8 segmentation with red overlay
  /// 3. ResNet preprocessing
  /// 4. Weight prediction
  Future<void> _processImagePipeline() async {
    if (widget.imagePath == null || _weightModel == null) return;

    _updateStatus("Starting pipeline...", processing: true);

    try {
      // Step 1: Load original image
      _updateStatus("Loading image...");
      final imageBytes = await File(widget.imagePath!).readAsBytes();
      final originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      // Step 2: YOLOv8 segmentation with red overlay
      _updateStatus("Running YOLOv8 segmentation...");
      final segmentedImage = await _yolov8Processor.processImage(originalImage);

      if (segmentedImage == null) {
        _updateStatus("No goat detected", displayText: "No Goat Found", processing: false);
        return;
      }

      // Step 3: Preprocess for ResNet/weight model
      _updateStatus("Preprocessing for weight prediction...");
      final preprocessedData = _resnetPreprocessor.preprocess(segmentedImage);

      // Step 4: Predict weight
      _updateStatus("Predicting weight...");
      final weight = _weightModel!.predict(preprocessedData, [1, 224, 224, 3]);

      _updateStatus(
        "Complete",
        displayText: "${weight.toStringAsFixed(1)}",
        processing: false,
      );
    } catch (e) {
      print('Error in image pipeline: $e');
      _updateStatus(
        "Processing failed",
        displayText: "Error",
        processing: false,
      );
    }
  }

  @override
  void dispose() {
    _yolov8Processor.dispose();
    super.dispose();
  }

  void _updateStatus(String step, {String? displayText, bool? processing}) {
    setState(() {
      _currentStep = step;
      if (displayText != null) _weightDisplay = displayText;
      if (processing != null) _isProcessing = processing;
    });
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
        // Navigate to new WeightScreen with the selected image
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => Weightscreen(
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          height: screenHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: screenHeight * 0.5,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(screenWidth * 0.15),
                    bottomRight: Radius.circular(screenWidth * 0.15),
                  ),
                ),
              ),
              // Buttons positioned at the top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => backOnPressed(context),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Icon(
                                Icons.arrow_back,
                                size: 28.0,
                              ),
                              Text('BACK'),
                            ]
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.foreground,
                            padding: EdgeInsets.all(screenWidth * 0.05),
                            textStyle: AppTextStyles.body,
                          )
                        ),
                        TextButton(
                          onPressed: () => historyOnPressed(context),
                          child: const Text('HISTORY'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.foreground,
                            padding: EdgeInsets.all(screenWidth * 0.05),
                            textStyle: AppTextStyles.body,
                          )
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Goat image - positioned to overlap (responsive)
              Positioned(
                top: screenHeight * 0.10, 
                left: 0,
                right: 0,
                child: Center(
                  child: Image.asset(
                    "assets/images/goat-image.png", 
                    width: screenWidth * 0.85, 
                    height: screenHeight * 0.45,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Weight content - update this section
              Positioned(
                top: screenHeight * 0.55, 
                left: 0,
                right: 0,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05), 
                  child: Column(
                    children: [
                      const Text(
                        "Your goat weighs",
                        style: AppTextStyles.weight_heading,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      _isProcessing 
                        ? Column(
                            children: [
                              const CircularProgressIndicator(color: AppColors.primary),
                              SizedBox(height: screenHeight * 0.01),
                              Text(
                                _currentStep,
                                style: AppTextStyles.body.copyWith(fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : Text(
                            _weightDisplay,
                            style: AppTextStyles.weight_value,
                            textAlign: TextAlign.center,
                          ),
                      const Text(
                        "kilograms",
                        style: AppTextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: screenHeight * 0.04),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ElevatedButton(
                            onPressed: () => cameraOnPressed(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: const CircleBorder(),
                              padding: EdgeInsets.all(screenWidth * 0.05), 
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: screenWidth * 0.08, 
                            ),
                          ),
                          ElevatedButton(
                            onPressed: galleryOnPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.background,
                              side: BorderSide(color: AppColors.primary, width: screenWidth * .015),
                              shape: const CircleBorder(),
                              padding: EdgeInsets.all(screenWidth * 0.05), 
                            ),
                            child: Image.asset("assets/images/image-icon.png", width: screenWidth * .08),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ]
          ),
        ),
      ),
    );
  }
}
