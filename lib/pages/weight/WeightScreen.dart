import 'package:cambing_thesis/core/theme/colors.dart';
import 'package:cambing_thesis/pages/camera/cameraScreen.dart';
import 'package:cambing_thesis/pages/history/historyScreen.dart';
import 'package:cambing_thesis/pages/weight/weightModel.dart';
import 'package:cambing_thesis/pages/weight/yolov8Model.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:cambing_thesis/core/theme/text_styles.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';

// Extension for reshaping lists - needed for weight model
extension ListReshapeExtension<T> on List<T> {
  List<List<List<List<T>>>> reshape4D(int batch, int height, int width, int channels) {
    return List.generate(batch, (b) => 
      List.generate(height, (h) => 
        List.generate(width, (w) => 
          List.generate(channels, (c) => 
            this[b * height * width * channels + h * width * channels + w * channels + c]
          )
        )
      )
    );
  }
}

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
  GoatWeightModel? _weightModel;
  final Yolov8 _yolov8Model = Yolov8();
  final ImagePicker _picker = ImagePicker();
  double? _predictedWeight;
  bool _isProcessing = false;
  String _weightDisplay = "---";
  String _currentStep = "";

  @override
  void initState() {
    super.initState();
    _initializeModels();
  }

  Future<void> _initializeModels() async {
    setState(() {
      _isProcessing = true;
      _weightDisplay = "Loading models...";
      _currentStep = "Initializing...";
    });

    try {
      // Load both models
      await _yolov8Model.loadModel();
      _weightModel = await GoatWeightModel.create(modelPath: 'assets/models/test_model.tflite');
      
      if (_weightModel != null && widget.imagePath != null) {
        await _processImagePipeline();
      } else if (_weightModel == null) {
        setState(() {
          _weightDisplay = "Model Error";
          _currentStep = "Failed to load weight model";
        });
      }
    } catch (e) {
      print('Error initializing models: $e');
      setState(() {
        _weightDisplay = "Error";
        _currentStep = "Model initialization failed";
      });
    }
  }

  Future<void> _processImagePipeline() async {
    if (widget.imagePath == null || _weightModel == null) return;
    
    setState(() {
      _isProcessing = true;
      _weightDisplay = "Processing...";
      _currentStep = "Starting pipeline...";
    });

    try {
      // Step 1: Load original image
      setState(() {
        _currentStep = "Loading image...";
      });
      
      final imageFile = File(widget.imagePath!);
      final bytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      // Step 2: Run YOLOv8 segmentation
      setState(() {
        _currentStep = "Detecting and segmenting goat...";
      });
      
      final segmentedImage = await _yolov8Model.runInference(originalImage);
      
      if (segmentedImage == null) {
        setState(() {
          _weightDisplay = "No Goat Found";
          _currentStep = "No goat detected in image";
        });
        return;
      }

      // Step 3: Preprocess segmented image for weight model
      setState(() {
        _currentStep = "Preprocessing for weight prediction...";
      });
      
      final preprocessedData = _preprocessImageForWeightModel(segmentedImage);
      
      // Step 4: Predict weight using preprocessed data
      setState(() {
        _currentStep = "Predicting weight...";
      });
      
      final weight = _weightModel!.predict(preprocessedData, [1, 224, 224, 3]);
      
      setState(() {
        _predictedWeight = weight;
        _weightDisplay = weight.toStringAsFixed(1);
        _currentStep = "Prediction complete";
      });
      
    } catch (e) {
      print('Error in image pipeline: $e');
      setState(() {
        _weightDisplay = "Error";
        _currentStep = "Processing failed: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Float32List _preprocessImageForWeightModel(img.Image image) {
    // Resize image to model input size (224x224)
    final resizedImage = img.copyResize(image, width: 224, height: 224);
    
    // Convert to Float32List with normalization (0-1)
    Float32List imageAsList = Float32List(224 * 224 * 3);
    
    int index = 0;
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resizedImage.getPixel(x, y);
        imageAsList[index++] = img.getRed(pixel) / 255.0;
        imageAsList[index++] = img.getGreen(pixel) / 255.0;
        imageAsList[index++] = img.getBlue(pixel) / 255.0;
      }
    }
    
    return imageAsList;
  }

  @override
  void dispose() {
    // Note: Add dispose method to models if needed
    super.dispose();
  }

  void onPressed() {}

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
