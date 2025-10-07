import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Goat Weight Prediction Model using ResNet
/// Takes preprocessed segmented image (224x224x3) and predicts weight in kg
class GoatWeightModel {
  // Update this path to match your actual model file name in assets/models/
  static const String _modelPath = 'assets/models/test_model.tflite';
  
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  /// Load the ResNet weight prediction model
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      _isModelLoaded = true;
      
      // Print model info for debugging
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      
      print('✅ Weight prediction model loaded');
      print('   Input shape: $inputShape');
      print('   Output shape: $outputShape');
    } catch (e) {
      print('❌ Failed to load weight model: $e');
      print('   Make sure test_model.tflite exists in assets/models/');
      rethrow;
    }
  }

  /// Predict goat weight from preprocessed segmented image
  /// 
  /// Input: Float32List from ResNetPreprocessor
  ///        - Shape: [1, 224, 224, 3] flattened to 150,528 elements
  ///        - Values: RGB normalized to [0, 1]
  /// 
  /// Output: Weight in kilograms (float)
  double predict(Float32List input, List<int> inputShape) {
    if (!_isModelLoaded || _interpreter == null) {
      print('❌ Weight model not loaded');
      return 0.0;
    }

    try {
      // Reshape flat Float32List to 4D tensor [1, 224, 224, 3]
      final reshapedInput = _reshapeInput(input, inputShape);
      
      // Allocate output buffer with proper shape [1, 1]
      final output = List.generate(1, (_) => List.filled(1, 0.0));

      // Run inference
      _interpreter!.run(reshapedInput, output);

      final predictedWeight = output[0][0];
      print('✅ Predicted weight: ${predictedWeight.toStringAsFixed(2)} kg');
      
      return predictedWeight;
      
    } catch (e) {
      print('❌ Weight prediction error: $e');
      return 0.0;
    }
  }

  /// Reshape flat Float32List to 4D tensor for ResNet input
  /// Converts [150528] → [1, 224, 224, 3]
  List<List<List<List<double>>>> _reshapeInput(
    Float32List flatInput,
    List<int> shape,
  ) {
    final batch = shape[0];      // 1
    final height = shape[1];     // 224
    final width = shape[2];      // 224
    final channels = shape[3];   // 3

    // Verify input size matches expected shape
    final expectedSize = batch * height * width * channels;
    if (flatInput.length != expectedSize) {
      print('⚠️ Warning: Input size ${flatInput.length} != expected $expectedSize');
    }

    // Create 4D tensor structure
    final reshaped = List.generate(
      batch,
      (b) => List.generate(
        height,
        (h) => List.generate(
          width,
          (w) => List.generate(
            channels,
            (c) {
              // Calculate flat index: [b][h][w][c]
              final index = b * height * width * channels +
                  h * width * channels +
                  w * channels +
                  c;
              return flatInput[index];
            },
          ),
        ),
      ),
    );

    return reshaped;
  }

  /// Get model information (useful for debugging)
  Map<String, dynamic>? getModelInfo() {
    if (!_isModelLoaded || _interpreter == null) {
      return null;
    }

    return {
      'inputShape': _interpreter!.getInputTensor(0).shape,
      'outputShape': _interpreter!.getOutputTensor(0).shape,
      'inputType': _interpreter!.getInputTensor(0).type.toString(),
      'outputType': _interpreter!.getOutputTensor(0).type.toString(),
    };
  }

  /// Clean up resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    print('✅ Weight model disposed');
  }
}
