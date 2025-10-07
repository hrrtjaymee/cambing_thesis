import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/foundation.dart';

/// YOLOv8 Segmentation Processor
/// Python equivalent:
///   results = model(img)[0]
///   boxes = results.boxes.xyxy.cpu().numpy()
///   areas = (boxes[:, 2] - boxes[:, 0]) * (boxes[:, 3] - boxes[:, 1])
///   nearest_idx = np.argmax(areas)
///   mask = results.masks.data[nearest_idx].cpu().numpy()
///   overlay[mask_resized > 0] = (0, 0, 255)
///   segmented_img = cv2.addWeighted(img, 0.7, overlay, 0.3, 0)
class YOLOv8Processor {
  static const String _modelPath = 'assets/models/yolov8x-seg_float32.tflite';
  static const int inputSize = 640;
  
  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  /// Load the YOLOv8 TensorFlow Lite model
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
      // Step 1: Preprocess - resize to 640x640 and normalize
      print('🔄 Preprocessing image for YOLOv8...');
      final preprocessedTensor = await compute(_preprocessForYOLOv8, inputImage);

      // Step 2: Run inference - results = model(img)[0]
      print('🔄 Running YOLOv8 inference...');
      final outputs = await _runInference(preprocessedTensor);
      
      if (outputs == null) {
        print('❌ Inference failed');
        return null;
      }

      // Step 3: Post-process matching Python exactly
      print('🔄 Post-processing with red overlay...');
      final segmentedImage = _postProcess(
        inputImage,
        outputs['detections']!,
        outputs['masks']!,
      );

      if (segmentedImage == null) {
        print('❌ No animals detected in the image.');
        return null;
      }

      print('✅ Segmented image saved (ready for ResNet)');
      return segmentedImage;
      
    } catch (e) {
      print('❌ Error in YOLOv8 processing: $e');
      return null;
    }
  }

  /// Preprocess image for YOLOv8 model
  /// Python: img = cv2.imread(input_image)
  /// Output: 4D tensor [1, 640, 640, 3] normalized to [0,1]
  static List<List<List<List<double>>>> _preprocessForYOLOv8(img.Image image) {
    final resized = img.copyResize(image, width: inputSize, height: inputSize);

    final tensor = List.generate(
      1, // batch
      (_) => List.generate(
        inputSize, // height
        (y) => List.generate(
          inputSize, // width
          (x) {
            final pixel = resized.getPixel(x, y);
            return [
              pixel.r / 255.0, // Red channel normalized [0,1]
              pixel.g / 255.0, // Green channel normalized [0,1]
              pixel.b / 255.0, // Blue channel normalized [0,1]
            ];
          },
        ),
      ),
    );

    return tensor;
  }

  /// Run YOLOv8 inference
  /// Returns detection boxes and segmentation masks
  Future<Map<String, List<double>>?> _runInference(
    List<List<List<List<double>>>> inputTensor,
  ) async {
    try {
      // Get output tensor shapes
      final outputShape0 = _interpreter!.getOutputTensor(0).shape; // [1, 116, 8400]
      final outputShape1 = _interpreter!.getOutputTensor(1).shape; // [1, 32, 160, 160]

      print('📊 Output shapes: $outputShape0, $outputShape1');

      // Create properly shaped output buffers
      // Output 0: [1, 116, 8400] - detections
      final output0 = List.generate(
        outputShape0[0],
        (_) => List.generate(
          outputShape0[1],
          (_) => List.filled(outputShape0[2], 0.0),
        ),
      );

      // Output 1: [1, 32, 160, 160] - mask prototypes
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

      // Run inference
      _interpreter!.runForMultipleInputs(
        [inputTensor],
        {0: output0, 1: output1},
      );

      // Flatten outputs for processing
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

      print('📊 Flattened outputs: detections=${flatOutput0.length}, masks=${flatOutput1.length}');

      return {
        'detections': flatOutput0,
        'masks': flatOutput1,
      };
    } catch (e) {
      print('❌ Inference error: $e');
      return null;
    }
  }

  /// Post-process: Find nearest animal and apply red overlay
  /// Python equivalent:
  ///   if results.masks is None or len(results.masks) == 0:
  ///       print("❌ No animals detected in the image.")
  ///   boxes = results.boxes.xyxy.cpu().numpy()
  ///   areas = (boxes[:, 2] - boxes[:, 0]) * (boxes[:, 3] - boxes[:, 1])
  ///   nearest_idx = np.argmax(areas)
  ///   mask = results.masks.data[nearest_idx].cpu().numpy()
  ///   overlay[mask_resized > 0] = (0, 0, 255)
  ///   segmented_img = cv2.addWeighted(img, 0.7, overlay, 0.3, 0)
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

    if (parsedDetections.isEmpty) {
      print('❌ No animals detected (${parsedDetections.length} detections found)');
      return null;
    }

    final nearestAnimal = _findNearestByArea(parsedDetections);
    print('✅ Found nearest animal: area=${nearestAnimal['area'].toStringAsFixed(0)}, score=${nearestAnimal['score'].toStringAsFixed(2)}');

    final mask = _buildSegmentationMask(
      nearestAnimal['maskCoeffs'] as List<double>,
      maskProtos,
      originalImage.width,
      originalImage.height,
    );

    final segmentedImage = _applyRedOverlay(originalImage, mask);

    return segmentedImage;
  }

  /// Parse YOLOv8 output tensor to extract detection boxes and mask coefficients
  /// Output format: [1, 116, 8400] where:
  /// - 0-3: bbox (x_center, y_center, width, height)
  /// - 4-83: class scores (80 classes)
  /// - 84-115: mask coefficients (32 values)
  List<Map<String, dynamic>> _parseYOLOv8Output(
    List<double> output,
    int imgWidth,
    int imgHeight,
  ) {
    const numDetections = 8400;
    final detections = <Map<String, dynamic>>[];

    for (int i = 0; i < numDetections; i++) {
      // Extract bbox (scaled from 640x640 to original size)
      final xCenter = output[i + 0 * numDetections] * imgWidth / inputSize;
      final yCenter = output[i + 1 * numDetections] * imgHeight / inputSize;
      final width = output[i + 2 * numDetections] * imgWidth / inputSize;
      final height = output[i + 3 * numDetections] * imgHeight / inputSize;

      // Convert to corner format (x1, y1, x2, y2)
      final x1 = (xCenter - width / 2).clamp(0, imgWidth.toDouble());
      final y1 = (yCenter - height / 2).clamp(0, imgHeight.toDouble());
      final x2 = (xCenter + width / 2).clamp(0, imgWidth.toDouble());
      final y2 = (yCenter + height / 2).clamp(0, imgHeight.toDouble());

      // Find max class confidence (features 4-83)
      double maxScore = 0.0;
      int maxClass = -1;
      for (int classIdx = 0; classIdx < 80; classIdx++) {
        final score = output[i + (4 + classIdx) * numDetections];
        if (score > maxScore) {
          maxScore = score;
          maxClass = classIdx;
        }
      }

      // Apply confidence threshold (lowered to 0.25 for better detection)
      // COCO class 19 = sheep (closest to goat in COCO dataset)
      // You can also accept: 19 (sheep), 20 (cow), 17 (dog), 18 (horse) for other animals
      const targetClass = 19; // sheep/goat
      
      if (maxScore > 0.25 && maxClass == targetClass) {
        // Extract mask coefficients (features 84-115)
        final maskCoeffs = <double>[];
        for (int k = 0; k < 32; k++) {
          maskCoeffs.add(output[i + (84 + k) * numDetections]);
        }

        detections.add({
          'bbox': [x1, y1, x2, y2],
          'score': maxScore,
          'class': maxClass,
          'area': (x2 - x1) * (y2 - y1),
          'maskCoeffs': maskCoeffs,
        });
      }
    }

    print('🔍 Found ${detections.length} detections');
    if (detections.isNotEmpty) {
      print('   Top detection: class=${detections[0]['class']}, score=${detections[0]['score'].toStringAsFixed(2)}');
    }

    return detections;
  }

  /// Find nearest animal by largest bounding box area
  /// Python: areas = (boxes[:, 2] - boxes[:, 0]) * (boxes[:, 3] - boxes[:, 1])
  ///         nearest_idx = np.argmax(areas)
  Map<String, dynamic> _findNearestByArea(List<Map<String, dynamic>> detections) {
    return detections.reduce((a, b) => 
      (a['area'] as double) > (b['area'] as double) ? a : b
    );
  }

  /// Build segmentation mask from mask prototypes and coefficients
  /// Python: mask = results.masks.data[nearest_idx].cpu().numpy()
  ///         mask = (mask * 255).astype("uint8")
  ///         mask_resized = cv2.resize(mask, (img.shape[1], img.shape[0]))
  img.Image _buildSegmentationMask(
    List<double> maskCoeffs,
    List<double> maskProtos,
    int targetWidth,
    int targetHeight,
  ) {
    const protoHeight = 160;
    const protoWidth = 160;
    const numProtos = 32;

    // Reshape mask protos: [1, 32, 160, 160] → [32][160*160]
    final protoReshaped = <List<double>>[];
    for (int p = 0; p < numProtos; p++) {
      final proto = <double>[];
      for (int i = 0; i < protoHeight * protoWidth; i++) {
        proto.add(maskProtos[p * protoHeight * protoWidth + i]);
      }
      protoReshaped.add(proto);
    }

    // Apply mask coefficients to prototypes
    final mask = img.Image(width: protoWidth, height: protoHeight);
    for (int y = 0; y < protoHeight; y++) {
      for (int x = 0; x < protoWidth; x++) {
        double maskValue = 0.0;
        final idx = y * protoWidth + x;
        
        // Linear combination: mask = sum(coeff[k] * proto[k])
        for (int k = 0; k < numProtos; k++) {
          maskValue += maskCoeffs[k] * protoReshaped[k][idx];
        }

        // Threshold at 0.5 and convert to 0-255
        final pixelValue = maskValue > 0.5 ? 255 : 0;
        mask.setPixelRgba(x, y, pixelValue, pixelValue, pixelValue, 255);
      }
    }

    // Resize mask to original image size
    // Mimics Python: mask_resized = cv2.resize(mask, (img.shape[1], img.shape[0]))
    return img.copyResize(
      mask,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.nearest,
    );
  }

  /// Apply red overlay with alpha blending
  /// Python: overlay = img.copy()
  ///         overlay[mask_resized > 0] = (0, 0, 255)
  ///         segmented_img = cv2.addWeighted(img, 0.7, overlay, 0.3, 0)
  img.Image _applyRedOverlay(img.Image original, img.Image mask) {
    final result = img.Image.from(original);

    for (int y = 0; y < original.height; y++) {
      for (int x = 0; x < original.width; x++) {
        final maskPixel = mask.getPixel(x, y);
        
        // If mask is active (white pixel)
        if (maskPixel.r > 128) {
          final origPixel = original.getPixel(x, y);
          
          // Alpha blending: 0.7 * original + 0.3 * red
          final r = (origPixel.r * 0.7 + 255 * 0.3).round().clamp(0, 255);
          final g = (origPixel.g * 0.7 + 0 * 0.3).round().clamp(0, 255);
          final b = (origPixel.b * 0.7 + 0 * 0.3).round().clamp(0, 255);
          
          result.setPixelRgba(x, y, r, g, b, origPixel.a);
        }
      }
    }

    return result;
  }

  /// Clean up resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    print('✅ YOLOv8 processor disposed');
  }
}
