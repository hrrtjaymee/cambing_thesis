import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';

class GoatWeightModel {
  late Interpreter _interpreter;

  GoatWeightModel._(this._interpreter);

  static Future<GoatWeightModel> create({required String modelPath}) async {
    final interpreter = await Interpreter.fromAsset(modelPath);
    return GoatWeightModel._(interpreter);
  }

  double predict(Float32List inputData, List<int> inputShape) {
    // Reshape input to match model input
    var reshapedInput = inputData.reshape(inputShape);

    // Prepare output buffer based on model output shape
    var outputShape = _interpreter.getOutputTensor(0).shape; // e.g. [1,1]
    var outputBuffer = List.filled(
      outputShape.reduce((a, b) => a * b),
      0.0,
    ).reshape(outputShape);

    // Run inference
    _interpreter.run(reshapedInput, outputBuffer);

    return outputBuffer[0][0].toDouble();
  }
}