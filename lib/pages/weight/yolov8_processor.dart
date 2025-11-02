import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:flutter_vision/flutter_vision.dart';

/// YOLOv8 Segmentation Class using flutter_vision
/// Handles image processing and red overlay application
class YOLOv8Segmentation {
  static const String _modelPath = 'assets/models/yolov8x-seg_float32.tflite';
  static const String _labelsPath = 'assets/labels.txt';
  
  static const double iouThreshold = 0.45;
  static const double confThreshold = 0.25;
  static const double classThreshold = 0.5;

  final FlutterVision _vision = FlutterVision();
  bool _isModelLoaded = false;

  /// Load the YOLOv8 segmentation model
  Future<void> loadModel() async {
    try {
      await _vision.loadYoloModel(
        labels: _labelsPath,
        modelPath: _modelPath,
        modelVersion: "yolov8seg",
        quantization: false,
        numThreads: 2,
        useGpu: false,
      );
      _isModelLoaded = true;
      print(' YOLOv8 Segmentation model loaded successfully');
    } catch (e) {
      print(' Failed to load YOLOv8 model: $e');
      rethrow;
    }
  }

  /// Main processing pipeline
  /// Returns the original image with red segmentation overlay
  Future<img.Image?> processImage(img.Image inputImage) async {
    if (!_isModelLoaded) {
      print(' YOLOv8 model not loaded');
      return null;
    }

    try {
      print(' Starting YOLOv8 segmentation pipeline...');
      
      // Convert image to bytes
      final imageBytes = img.encodeJpg(inputImage);
      
      // Run inference using flutter_vision
      final results = await _vision.yoloOnImage(
        bytesList: imageBytes,
        imageHeight: inputImage.height,
        imageWidth: inputImage.width,
        iouThreshold: iouThreshold,
        confThreshold: confThreshold,
        classThreshold: classThreshold,
      );

      print(' Inference complete: ${results.length} detections');

      if (results.isEmpty) {
        print(' No objects detected');
        return null;
      }

      // Select best detection and apply red overlay
      final result = _applyRedOverlay(inputImage, results);
      
      print(' YOLOv8 segmentation pipeline complete!');
      return result;
    } catch (e) {
      print(' YOLOv8 processing error: $e');
      return null;
    }
  }

  /// Select best detection and apply red overlay to segmentation mask
  /// 
  /// This method:
  /// 1. Transforms polygon coordinates from YOLOv8's coordinate space to original image space
  /// 2. Applies red overlay using ray casting for point-in-polygon checks
  /// 3. Uses the blending formula: blended = 0.7 * image + 0.3 * red
  /// 
  /// The output is consistent and pixel-perfect, suitable for the weight prediction model.
  img.Image _applyRedOverlay(
    img.Image original,
    List<Map<String, dynamic>> results,
  ) {
    // Select best detection (hybrid: 60% confidence + 40% area)
    final bestDetection = _selectBestDetection(results);
    
    // Debug: print all available fields
    print(' Available fields in detection: ${bestDetection.keys.toList()}');
    
    final box = bestDetection['box'] as List<dynamic>;
    final tag = bestDetection['tag'] as String;
    final polygons = bestDetection['polygons'] as List<dynamic>?;
    
    final confidence = box[4];
    print(' Best detection: $tag (conf=${confidence.toStringAsFixed(3)})');
    
    if (polygons == null || polygons.isEmpty) {
      print(' No segmentation mask available');
      return original;
    }

    // Create result image
    final result = img.Image.from(original);
    
    // Get bounding box origin in original image coordinates
    final x1 = box[0] as double;
    final y1 = box[1] as double;
    
    // Convert polygons to mask points
    // Polygon coordinates are bbox-relative (origin at bbox top-left)
    // Just offset by bbox position
    final maskPoints = <math.Point<int>>[];
    for (final point in polygons) {
      final x = x1 + (point['x'] as double);
      final y = y1 + (point['y'] as double);
      maskPoints.add(math.Point(x.round(), y.round()));
    }

    // Apply red overlay directly using polygon fill
    // blended = 0.7 * image + 0.3 * red
    
    // Get bounding box for optimization
    int minX = original.width;
    int minY = original.height;
    int maxX = 0;
    int maxY = 0;
    
    for (final point in maskPoints) {
      minX = math.min(minX, point.x);
      minY = math.min(minY, point.y);
      maxX = math.max(maxX, point.x);
      maxY = math.max(maxY, point.y);
    }
    
    // Clamp to image bounds
    minX = math.max(0, minX);
    minY = math.max(0, minY);
    maxX = math.min(original.width - 1, maxX);
    maxY = math.min(original.height - 1, maxY);
    
    // Apply blended red overlay to each pixel in polygon
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        if (_isPointInPolygon(math.Point(x, y), maskPoints)) {
          final pixel = original.getPixel(x, y);
          // Red overlay: 70% original + 30% red
          final r = (pixel.r * 0.7 + 255 * 0.3).round().clamp(0, 255);
          final g = (pixel.g * 0.7).round().clamp(0, 255);
          final b = (pixel.b * 0.7).round().clamp(0, 255);
          result.setPixelRgba(x, y, r, g, b, 255);
        }
      }
    }

    return result;
  }

  /// Select best detection (hybrid: 60% confidence + 40% area)
  Map<String, dynamic> _selectBestDetection(List<Map<String, dynamic>> detections) {
    // Calculate areas
    double maxArea = 0.0;
    for (final det in detections) {
      final box = det['box'] as List<dynamic>;
      final x1 = box[0] as double;
      final y1 = box[1] as double;
      final x2 = box[2] as double;
      final y2 = box[3] as double;
      final area = (x2 - x1) * (y2 - y1);
      if (area > maxArea) maxArea = area;
    }

    Map<String, dynamic>? best;
    double bestScore = 0.0;

    for (final det in detections) {
      final box = det['box'] as List<dynamic>;
      final x1 = box[0] as double;
      final y1 = box[1] as double;
      final x2 = box[2] as double;
      final y2 = box[3] as double;
      final conf = box[4] as double;
      final area = (x2 - x1) * (y2 - y1);
      
      final normArea = maxArea > 0 ? area / maxArea : 0.0;
      final hybridScore = conf * 0.6 + normArea * 0.4;

      if (hybridScore > bestScore) {
        bestScore = hybridScore;
        best = det;
      }
    }

    return best!;
  }

  /// Check if point is inside polygon using ray casting algorithm
  bool _isPointInPolygon(math.Point<int> point, List<math.Point<int>> polygon) {
    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].y > point.y) != (polygon[j].y > point.y) &&
          (point.x < (polygon[j].x - polygon[i].x) * 
                     (point.y - polygon[i].y) / 
                     (polygon[j].y - polygon[i].y) + 
                     polygon[i].x)) {
        inside = !inside;
      }
      j = i;
    }

    return inside;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _vision.closeYoloModel();
    _isModelLoaded = false;
    print(' YOLOv8 Segmentation disposed');
  }
}
