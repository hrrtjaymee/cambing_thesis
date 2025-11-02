import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Goat Weight Prediction Model using ResNet
/// Takes preprocessed segmented image (224x224x3) and predicts weight in kg
class GoatWeightModel {
  // Update this path to match your actual model file name in assets/models/
  static const String _modelPath = 'assets/models/resnet-1.tflite';
  
  Interpreter? _interpreter;
  bool _isModelLoaded = false;
  final _maxWeight = 55.0;

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
  /// Input: Float32List from ModelPreprocessor
  ///        - Shape: [1, 224, 224, 3] flattened to 150,528 elements
  ///        - Values: RGB normalized based on model type
  ///          - ResNet: [0, 1]
  ///          - MobileNetV2: [-1, 1]
  /// 
  /// Output: Weight in kilograms (float)
  double predict(Float32List input, List<int> inputShape) {
    if (!_isModelLoaded || _interpreter == null) {
      print('❌ Weight model not loaded');
      return 0.0;
    }

    try {
      // Verify input size matches expected shape
      final expectedSize = inputShape.reduce((a, b) => a * b);
      if (input.length != expectedSize) {
        print('⚠️ Warning: Input size ${input.length} != expected $expectedSize');
      }

      // Reshape input for TensorFlow Lite (wraps Float32List in proper shape)
      final inputTensor = input.reshape(inputShape);
      
      // Allocate output buffer
      final output = List.filled(1, 0.0).reshape([1, 1]);

      // Run inference
      _interpreter!.run(inputTensor, output);

      final predictedWeight = output[0][0] * _maxWeight;
      
      // Truncate to 1 decimal place without rounding
      final truncated = (predictedWeight * 10).truncateToDouble() / 10;
      
      print('✅ Predicted weight: ${truncated.toStringAsFixed(1)} kg');
      
      return truncated;
      
    } catch (e) {
      print('❌ Weight prediction error: $e');
      return 0.0;
    }
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
