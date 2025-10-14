import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/foundation.dart';

class YOLOv8Processor {
  static const String _modelPath = 'assets/models/yolov8x-seg_float32.tflite';
  static const int inputSize = 640;

  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      _isModelLoaded = true;
      print('✅ YOLOv8 model loaded successfully');
    } catch (e) {
      print('❌ Failed to load YOLOv8 model: $e');
      rethrow;
    }
  }

  Future<img.Image?> processImage(img.Image inputImage) async {
    if (!_isModelLoaded || _interpreter == null) {
      print('❌ YOLOv8 model not loaded');
      return null;
    }

    try {
      final preprocessedTensor = await compute(_preprocessForYOLOv8, inputImage);
      final outputs = await _runInference(preprocessedTensor);
      if (outputs == null) return null;

      final segmentedImage = _postProcess(
        inputImage,
        outputs['detections']!,
        outputs['masks']!,
      );

      if (segmentedImage == null) {
        print('❌ No animals detected.');
        return null;
      }

      print('✅ Segmented image ready');
      return segmentedImage;
    } catch (e) {
      print('❌ YOLOv8 processing error: $e');
      return null;
    }
  }

  static List<List<List<List<double>>>> _preprocessForYOLOv8(img.Image image) {
    final origW = image.width;
    final origH = image.height;
    final target = inputSize;
    // Use the ratio that makes the LARGER dimension fit in target
    final ratio = math.min(target / origW, target / origH);

    final newW = (origW * ratio).round();
    final newH = (origH * ratio).round();

    final resized = img.copyResize(image, width: newW, height: newH, interpolation: img.Interpolation.linear);
    final canvas = img.Image(width: target, height: target);
    img.fill(canvas, color: img.ColorRgb8(0, 0, 0));

    final dx = ((target - newW) / 2).round();
    final dy = ((target - newH) / 2).round();
    img.compositeImage(canvas, resized, dstX: dx, dstY: dy);

    final tensor = List.generate(
      1,
      (_) => List.generate(
        target,
        (y) => List.generate(
          target,
          (x) {
            final pixel = canvas.getPixel(x, y);
            return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
          },
        ),
      ),
    );

    return tensor;
  }

  Future<Map<String, List<double>>?> _runInference(
    List<List<List<List<double>>>> inputTensor,
  ) async {
    try {
      final outputShape0 = _interpreter!.getOutputTensor(0).shape;
      final outputShape1 = _interpreter!.getOutputTensor(1).shape;

      final output0 = List.generate(
        outputShape0[0],
        (_) => List.generate(
          outputShape0[1],
          (_) => List.filled(outputShape0[2], 0.0),
        ),
      );

      final output1 = List.generate(
        outputShape1[0],
        (_) => List.generate(
          outputShape1[1],
          (_) => List.generate(
            outputShape1[2],
            (_) => List.filled(outputShape1[3], 0.0),
          ),
        ),
      );

      _interpreter!.runForMultipleInputs([inputTensor], {0: output0, 1: output1});

      final flatOutput0 = <double>[];
      for (var batch in output0) {
        for (var row in batch) {
          flatOutput0.addAll(row);
        }
      }

      final flatOutput1 = <double>[];
      for (var batch in output1) {
        for (var channel in batch) {
          for (var row in channel) {
            flatOutput1.addAll(row);
          }
        }
      }

      return {'detections': flatOutput0, 'masks': flatOutput1};
    } catch (e) {
      print('❌ Inference error: $e');
      return null;
    }
  }

  img.Image? _postProcess(
    img.Image originalImage,
    List<double> detections,
    List<double> maskProtos,
  ) {
    final parsedDetections = _parseYOLOv8Output(
      detections,
      originalImage.width,
      originalImage.height,
    );

    if (parsedDetections.isEmpty) return null;

    // Find the goat with the largest bounding box area
    final nearestAnimal = _findNearestByArea(parsedDetections);
    final bbox = nearestAnimal['bbox'] as List<double>;
    
    // Get bounding box coordinates
    final x1 = bbox[0].toInt().clamp(0, originalImage.width - 1);
    final y1 = bbox[1].toInt().clamp(0, originalImage.height - 1);
    final x2 = bbox[2].toInt().clamp(0, originalImage.width - 1);
    final y2 = bbox[3].toInt().clamp(0, originalImage.height - 1);
    
    print('📦 Applying overlay to bbox: [$x1, $y1, $x2, $y2]');
    
    // Create result image and apply red overlay only within bounding box
    final result = img.Image.from(originalImage);
    
    for (int y = y1; y <= y2; y++) {
      for (int x = x1; x <= x2; x++) {
        final pixel = originalImage.getPixel(x, y);
        // Apply red overlay (70% original + 30% red)
        final r = (pixel.r * 0.7 + 255 * 0.3).round().clamp(0, 255);
        final g = (pixel.g * 0.7).round().clamp(0, 255);
        final b = (pixel.b * 0.7).round().clamp(0, 255);
        result.setPixelRgba(x, y, r, g, b, 255);
      }
    }
    
    final bboxPixels = (x2 - x1 + 1) * (y2 - y1 + 1);
    final totalPixels = originalImage.width * originalImage.height;
    print('🎨 Overlay applied to $bboxPixels pixels (${(bboxPixels * 100 / totalPixels).toStringAsFixed(1)}% of image)');
    print('✅ Overlay complete');
    
    return result;
  }

  double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

  List<Map<String, dynamic>> _parseYOLOv8Output(
    List<double> output,
    int imgWidth,
    int imgHeight,
  ) {
    const numDetections = 8400;
    final detections = <Map<String, dynamic>>[];

  for (int i = 0; i < numDetections; i++) {
      // YOLOv8 outputs normalized coordinates (0-1), convert to pixels in 640x640 space
      final xCenter = output[i + 0 * numDetections] * inputSize;
      final yCenter = output[i + 1 * numDetections] * inputSize;
      final width = output[i + 2 * numDetections] * inputSize;
      final height = output[i + 3 * numDetections] * inputSize;
      final objLogit = output[i + 4 * numDetections];
      final objProb = _sigmoid(objLogit);

      double maxScore = 0.0;
      int maxClass = -1;
      for (int classIdx = 0; classIdx < 80; classIdx++) {
        final classLogit = output[i + (5 + classIdx) * numDetections];
        final classProb = _sigmoid(classLogit);
        final score = objProb * classProb;
        if (score > maxScore) {
          maxScore = score;
          maxClass = classIdx;
        }
      }

      // Accept any animal detection with reasonable confidence (training code didn't filter by class)
      if (maxScore > 0.25) {
        print('🔍 Detection found: class=$maxClass, score=$maxScore, xCenter=$xCenter, yCenter=$yCenter, width=$width, height=$height');
        
        final maskCoeffs = <double>[];
        for (int k = 0; k < 32; k++) {
          // Mask coefficients start at index 84 (4 box + 80 classes)
          maskCoeffs.add(output[i + (84 + k) * numDetections]);
        }

        // Must match preprocessing letterbox calculation exactly
        final origW = imgWidth.toDouble();
        final origH = imgHeight.toDouble();
        // Choose ratio that makes the larger dimension fit in 640
        final ratio = math.min(inputSize / origW, inputSize / origH);
        final newW = (origW * ratio).round();
        final newH = (origH * ratio).round();
        final padX = ((inputSize - newW) / 2.0);
        final padY = ((inputSize - newH) / 2.0);

        print('📏 Conversion: origW=$origW, origH=$origH, ratio=$ratio, padX=$padX, padY=$padY');

        // Convert from letterbox coordinates to original coordinates
        final cx = (xCenter - padX) / ratio;
        final cy = (yCenter - padY) / ratio;
        final w = width / ratio;
        final h = height / ratio;

        print('📍 Center: cx=$cx, cy=$cy, w=$w, h=$h');

        final x1 = (cx - w / 2).clamp(0.0, origW);
        final y1 = (cy - h / 2).clamp(0.0, origH);
        final x2 = (cx + w / 2).clamp(0.0, origW);
        final y2 = (cy + h / 2).clamp(0.0, origH);
        
        print('📦 Final BBox: [$x1, $y1, $x2, $y2]');

        detections.add({
          'bbox': [x1, y1, x2, y2],
          'score': maxScore,
          'class': maxClass,
          'area': (x2 - x1) * (y2 - y1),
          'maskCoeffs': maskCoeffs,
        });
      }
    }

    return detections;
  }

  Map<String, dynamic> _findNearestByArea(List<Map<String, dynamic>> detections) {
    return detections.reduce((a, b) =>
        (a['area'] as double) > (b['area'] as double) ? a : b);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    print('✅ YOLOv8 processor disposed');
  }
}
