import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/foundation.dart';

class YOLOv8Processor {
  static const String _modelPath = 'assets/models/yolov8x-seg_float32.tflite';
  static const int inputSize = 640;
  
  // YOLOv8 default parameters
  static const double confThreshold = 0.25;  // Confidence threshold
  static const double iouThreshold = 0.45;   // IoU threshold for NMS
  static const int maxDetections = 300;      // Maximum detections to keep

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

      print('🔍 Output shapes: detections=$outputShape0, prototypes=$outputShape1');

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
    print('⭐⭐⭐ POST PROCESS STARTING - CODE VERSION WITH NMS ⭐⭐⭐');
    
    final parsedDetections = _parseYOLOv8Output(
      detections,
      originalImage.width,
      originalImage.height,
    );

    print('📋 Before NMS: ${parsedDetections.length} raw detections');
    if (parsedDetections.isEmpty) return null;

    // Apply Non-Maximum Suppression per class
    final nmsDetections = _applyNMSPerClass(parsedDetections);
    
    if (nmsDetections.isEmpty) return null;

    // Print total number of detected objects after NMS
    print('🔢 Total objects detected by YOLOv8: ${nmsDetections.length}');
    
    // Print details of each detection
    for (int i = 0; i < nmsDetections.length; i++) {
      final det = nmsDetections[i];
      print('   Object $i: class=${det['class']}, score=${(det['score'] as double).toStringAsFixed(3)}, area=${(det['area'] as double).toStringAsFixed(0)}');
    }

    // Find the animal with the best hybrid score (confidence + area)
    final nearestAnimal = _findNearestByArea(nmsDetections);
    
    // Get the bounding box coordinates
    final bbox = nearestAnimal['bbox'] as List<double>;
    final x1 = bbox[0].toInt();
    final y1 = bbox[1].toInt();
    final x2 = bbox[2].toInt();
    final y2 = bbox[3].toInt();
    final boxWidth = x2 - x1;
    final boxHeight = y2 - y1;
    
    print('🎯 Applying segmentation overlay within bounding box: [$x1, $y1, $x2, $y2]');
    
    // Build segmentation mask cropped in prototype space (160x160) BEFORE scaling
    // This prevents mask bleed into nearby objects
    final objectMask = _buildSegmentationMaskForObject(
      nearestAnimal['maskCoeffs'] as List<double>,
      maskProtos,
      bbox,
      originalImage.width,
      originalImage.height,
    );
    
    // Create result image and apply red overlay using the object-specific mask
    final result = img.Image.from(originalImage);
    int overlayPixels = 0;
    
    for (int dy = 0; dy < boxHeight; dy++) {
      for (int dx = 0; dx < boxWidth; dx++) {
        final imgX = x1 + dx;
        final imgY = y1 + dy;
        
        if (imgX >= 0 && imgX < originalImage.width && imgY >= 0 && imgY < originalImage.height) {
          // Check if this pixel is part of the segmentation mask (threshold > 0.5 = 128)
          final maskPixel = objectMask.getPixel(dx, dy);
          if (maskPixel.r > 128) {
            overlayPixels++;
            final pixel = originalImage.getPixel(imgX, imgY);
            // Apply red overlay (70% original + 30% red)
            final r = (pixel.r * 0.7 + 255 * 0.3).round().clamp(0, 255);
            final g = (pixel.g * 0.7).round().clamp(0, 255);
            final b = (pixel.b * 0.7).round().clamp(0, 255);
            result.setPixelRgba(imgX, imgY, r, g, b, 255);
          }
        }
      }
    }
    
    print('🎨 Overlay applied to $overlayPixels pixels');
    print('✅ Segmentation and overlay complete');
    
    return result;
  }

  double _sigmoid(double x) => 1.0 / (1.0 + math.exp(-x));

  // Build segmentation mask for a specific object by cropping in prototype space FIRST
  // This prevents mask bleed into nearby objects
  img.Image _buildSegmentationMaskForObject(
    List<double> maskCoeffs,
    List<double> maskProtos,
    List<double> bbox,
    int targetWidth,
    int targetHeight,
  ) {
    const int inputSize = 640;
    const int protoH = 160;
    const int protoW = 160;
    const int numProtos = 32;

    print('🔍 Building mask: bbox=$bbox, image=${targetWidth}x${targetHeight}, proto_tensor_size=${maskProtos.length}');
    print('   Expected proto size: ${numProtos * protoH * protoW} (${numProtos}x${protoH}x${protoW})');

    // YOLOv8 TFLite exports prototypes as [1, protoH, protoW, numProtos] (channels last)
    // Reshape prototypes: extract 32 channels from HxWxC format
    final protoReshaped = List<List<double>>.generate(numProtos, (c) {
      return List<double>.generate(protoH * protoW, (i) {
        final y = i ~/ protoW;
        final x = i % protoW;
        // Index: batch=0, y, x, channel=c
        final idx = (y * protoW + x) * numProtos + c;
        return maskProtos[idx];
      });
    });

    // Dequantize prototypes (normalize to reasonable range)
    // YOLOv8 prototypes are typically in [-1, 1] range after training
    for (int c = 0; c < numProtos; c++) {
      double minVal = double.infinity;
      double maxVal = double.negativeInfinity;
      
      for (int i = 0; i < protoH * protoW; i++) {
        final val = protoReshaped[c][i];
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
      }
      
      // Normalize to [0, 1] range for better numerical stability
      final range = maxVal - minVal;
      if (range > 0) {
        for (int i = 0; i < protoH * protoW; i++) {
          protoReshaped[c][i] = (protoReshaped[c][i] - minVal) / range;
        }
      }
    }

    print('   Prototypes reshaped and dequantized (channels last format)');

    // Combine prototypes using coefficients: mask = sigmoid(sum(coeff_i * proto_i))
    final maskFloat = List<double>.filled(protoH * protoW, 0.0);
    for (int k = 0; k < numProtos; k++) {
      final coeff = maskCoeffs[k];
      final proto = protoReshaped[k];
      for (int i = 0; i < protoH * protoW; i++) {
        maskFloat[i] += coeff * proto[i];
      }
    }

    // Apply sigmoid to get probabilities
    for (int i = 0; i < maskFloat.length; i++) {
      maskFloat[i] = _sigmoid(maskFloat[i]);
    }

    // Create 160x160 mask with threshold > 0.5
    final maskTiny = img.Image(width: protoW, height: protoH);
    for (int y = 0; y < protoH; y++) {
      for (int x = 0; x < protoW; x++) {
        final maskVal = maskFloat[y * protoW + x];
        final v = maskVal > 0.5 ? 255 : 0;
        maskTiny.setPixelRgba(x, y, v, v, v, 255);
      }
    }

    // Calculate letterbox transformation (same as preprocessing)
    final scale = math.min(inputSize / targetWidth, inputSize / targetHeight);
    final newW = (targetWidth * scale).round();
    final newH = (targetHeight * scale).round();
    final padX = ((inputSize - newW) / 2.0).round();
    final padY = ((inputSize - newH) / 2.0).round();

    // Convert bbox from original image space to 640x640 letterbox space
    final x1 = bbox[0];
    final y1 = bbox[1];
    final x2 = bbox[2];
    final y2 = bbox[3];
    
    final x1_letterbox = (x1 * scale + padX).round();
    final y1_letterbox = (y1 * scale + padY).round();
    final x2_letterbox = (x2 * scale + padX).round();
    final y2_letterbox = (y2 * scale + padY).round();
    
    // Scale bbox to 160x160 prototype space
    final protoScale = protoW / inputSize;
    final x1_proto = (x1_letterbox * protoScale).round().clamp(0, protoW - 1);
    final y1_proto = (y1_letterbox * protoScale).round().clamp(0, protoH - 1);
    final x2_proto = (x2_letterbox * protoScale).round().clamp(0, protoW);
    final y2_proto = (y2_letterbox * protoScale).round().clamp(0, protoH);
    
    final cropWidth = (x2_proto - x1_proto).clamp(1, protoW);
    final cropHeight = (y2_proto - y1_proto).clamp(1, protoH);
    
    print('   Bbox in proto space: [$x1_proto, $y1_proto, $x2_proto, $y2_proto] → crop=${cropWidth}x${cropHeight}');
    
    // Crop mask in prototype space (160x160) - this prevents bleed!
    final croppedMask = img.copyCrop(
      maskTiny,
      x: x1_proto,
      y: y1_proto,
      width: cropWidth,
      height: cropHeight,
    );
    
    // Calculate bbox dimensions in original image space
    final bboxWidth = (x2 - x1).round();
    final bboxHeight = (y2 - y1).round();
    
    // Resize cropped mask to match object's size in original image
    final resizedMask = img.copyResize(
      croppedMask,
      width: bboxWidth,
      height: bboxHeight,
      interpolation: img.Interpolation.linear,
    );

    return resizedMask;
  }

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

      // Apply YOLOv8 default confidence threshold
      if (maxScore > confThreshold) {
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
        final padX = ((inputSize - newW) / 2).round();  // MUST round to match preprocessing
        final padY = ((inputSize - newH) / 2).round();  // MUST round to match preprocessing

        // Convert from letterbox coordinates to original coordinates
        final cx = (xCenter - padX) / ratio;
        final cy = (yCenter - padY) / ratio;
        final w = width / ratio;
        final h = height / ratio;

        final x1 = (cx - w / 2).clamp(0.0, origW);
        final y1 = (cy - h / 2).clamp(0.0, origH);
        final x2 = (cx + w / 2).clamp(0.0, origW);
        final y2 = (cy + h / 2).clamp(0.0, origH);

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

  // Non-Maximum Suppression (NMS) applied per class
  // Detections of different classes won't suppress each other
  List<Map<String, dynamic>> _applyNMSPerClass(List<Map<String, dynamic>> detections) {
    print('🔄 Starting per-class NMS with ${detections.length} detections...');
    if (detections.isEmpty) return detections;
    
    // Group detections by class
    final Map<int, List<Map<String, dynamic>>> detectionsByClass = {};
    for (var det in detections) {
      final classId = det['class'] as int;
      detectionsByClass.putIfAbsent(classId, () => []).add(det);
    }
    
    final allKept = <Map<String, dynamic>>[];
    int totalBefore = 0;
    
    // Apply NMS separately for each class
    for (var entry in detectionsByClass.entries) {
      final classId = entry.key;
      final classDetections = entry.value;
      totalBefore += classDetections.length;
      
      // Sort by confidence score (highest first)
      classDetections.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
      
      final kept = <Map<String, dynamic>>[];
      final suppressed = List<bool>.filled(classDetections.length, false);
      
      for (int i = 0; i < classDetections.length; i++) {
        if (suppressed[i]) continue;
        
        kept.add(classDetections[i]);
        
        final bboxA = classDetections[i]['bbox'] as List<double>;
        
        // Suppress overlapping boxes with lower confidence (within same class)
        for (int j = i + 1; j < classDetections.length; j++) {
          if (suppressed[j]) continue;
          
          final bboxB = classDetections[j]['bbox'] as List<double>;
          final iou = _calculateIoU(bboxA, bboxB);
          
          if (iou > iouThreshold) {
            suppressed[j] = true;
          }
        }
      }
      
      allKept.addAll(kept);
      print('   Class $classId: ${classDetections.length} detections → ${kept.length} kept');
    }
    
    // Limit to max detections across all classes
    if (allKept.length > maxDetections) {
      allKept.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
      allKept.removeRange(maxDetections, allKept.length);
    }
    
    print('📊 Per-class NMS: $totalBefore detections → ${allKept.length} kept (iou_threshold=$iouThreshold, max_det=$maxDetections)');
    return allKept;
  }

  // Calculate Intersection over Union (IoU) between two bounding boxes
  double _calculateIoU(List<double> boxA, List<double> boxB) {
    final x1A = boxA[0], y1A = boxA[1], x2A = boxA[2], y2A = boxA[3];
    final x1B = boxB[0], y1B = boxB[1], x2B = boxB[2], y2B = boxB[3];
    
    // Calculate intersection area
    final xLeft = math.max(x1A, x1B);
    final yTop = math.max(y1A, y1B);
    final xRight = math.min(x2A, x2B);
    final yBottom = math.min(y2A, y2B);
    
    if (xRight < xLeft || yBottom < yTop) return 0.0;
    
    final intersectionArea = (xRight - xLeft) * (yBottom - yTop);
    
    // Calculate union area
    final boxAArea = (x2A - x1A) * (y2A - y1A);
    final boxBArea = (x2B - x1B) * (y2B - y1B);
    final unionArea = boxAArea + boxBArea - intersectionArea;
    
    return intersectionArea / unionArea;
  }

  Map<String, dynamic> _findNearestByArea(List<Map<String, dynamic>> detections) {
    // Hybrid scoring: combine confidence and area (normalized)
    // This selects an animal that is both clearly detected AND close to camera
    
    // Find max area for normalization
    double maxArea = 0.0;
    for (var det in detections) {
      final area = det['area'] as double;
      if (area > maxArea) maxArea = area;
    }
    
    // Calculate hybrid score for each detection
    Map<String, dynamic>? best;
    double bestScore = 0.0;
    
    for (var det in detections) {
      final confidence = det['score'] as double;
      final area = det['area'] as double;
      
      // Normalize area to 0-1 range
      final normalizedArea = maxArea > 0 ? area / maxArea : 0.0;
      
      // Hybrid score: 60% confidence + 40% area
      // This balances detection quality with proximity to camera
      final hybridScore = (confidence * 0.6) + (normalizedArea * 0.4);
      
      if (hybridScore > bestScore) {
        bestScore = hybridScore;
        best = det;
      }
    }
    
    print('🎯 Selected animal: confidence=${(best!['score'] as double).toStringAsFixed(3)}, area=${(best['area'] as double).toStringAsFixed(0)}, hybrid_score=${bestScore.toStringAsFixed(3)}');
    
    return best;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    print('✅ YOLOv8 processor disposed');
  }
}
