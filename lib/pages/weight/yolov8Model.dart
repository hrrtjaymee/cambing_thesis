import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

extension ListReshapeExtension<T> on List<T> {
  List<List<T>> reshape(int rows, int cols) {
    final reshaped = List.generate(
      rows,
      (i) => this.sublist(i * cols, (i + 1) * cols),
    );
    return reshaped;
  }
}

class Yolov8 {
  static const String _modelPath = 'assets/models/yolov8x-seg_float32.tflite';
  bool _isModelLoaded = false;
  Interpreter? _interpreter;

  //load model
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
      _isModelLoaded = true;
    print('Yolov8 model loaded');
    } catch (e) {
      print('Failed to load Yolov8: $e');
    }
  }

  //preprocess image for yolov8 (resizing and normalizing to 0-1)
  Uint8List preprocess(img.Image image, int inputSize) {
    final resized = img.copyResize(image, width :inputSize, height: inputSize);
    Float32List imageAsList = Float32List(resized.width * resized.height * 3);

    int index = 0;
    for (int y = 0; y < resized.height; y++) {
      for (int x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel(x, y);
        imageAsList[index++] = (img.getRed(pixel) / 255.0);
        imageAsList[index++] = (img.getGreen(pixel) / 255.0);
        imageAsList[index++] = (img.getBlue(pixel) / 255.0);
      }
    }
    return imageAsList.buffer.asUint8List();
  }

  //parseDetection
  List<Map<String, dynamic>> parseDetections(
    List output0, // [numDetections, 6+numMaskCoeff]
    List output1, // [maskPrototypes, h, w]
    int imgWidth,
    int imgHeight,
    {double scoreThreshold = 0.5}) {
  
  final detections = <Map<String, dynamic>>[];

  for (var i = 0; i < output0.length; i++) {
    final det = output0[i];

    final x1 = det[0] * imgWidth;
    final y1 = det[1] * imgHeight;
    final x2 = det[2] * imgWidth;
    final y2 = det[3] * imgHeight;
    final score = det[4];
    final classId = det[5];

    if (score > scoreThreshold) {
      detections.add({
        "box": [x1, y1, x2, y2],
        "score": score,
        "classId": classId,
        "maskCoeff": det.sublist(6), // needed to reconstruct mask
      });
    }
  }

  if (detections.isEmpty) return [];

  // Pick the "nearest goat" → largest bounding box area
  detections.sort((a, b) {
    final boxA = a["box"];
    final boxB = b["box"];
    final areaA = (boxA[2] - boxA[0]) * (boxA[3] - boxA[1]);
    final areaB = (boxB[2] - boxB[0]) * (boxB[3] - boxB[1]);
    return areaB.compareTo(areaA);
  });

  // Return only the top detection (like your np.argmax)
  return [detections.first];
  }

  //apply red overlay
  img.Image applyRedOverlay(img.Image original, img.Image mask) {
  final output = img.Image.from(original); // start with original

  for (int y = 0; y < output.height; y++) {
    for (int x = 0; x < output.width; x++) {
      final m = mask.getPixel(x, y) & 0xFF; // mask alpha
      if (m > 128) {
        // Blend red overlay with original pixel
        final origPixel = output.getPixel(x, y);
        final r = (img.getRed(origPixel) * 0.7 + 255 * 0.3).toInt();
        final g = (img.getGreen(origPixel) * 0.7 + 0 * 0.3).toInt();
        final b = (img.getBlue(origPixel) * 0.7 + 0 * 0.3).toInt();
        output.setPixel(x, y, img.getColor(r, g, b));
      }
    }
  }
  return output;
}

img.Image buildMaskFromProtos(
    Map<String, dynamic> detection,
    List<double> maskProtos,
    int imgWidth,
    int imgHeight,
    List<int> protoShape) {
  // protoShape = outputShape1 from the interpreter, e.g., [numProtos, protoHeight, protoWidth]
  final numProtos = protoShape[0];
  final protoHeight = protoShape[1];
  final protoWidth = protoShape[2];

  // Reshape maskProtos from flat list to [numProtos][h*w]
  final proto3D = maskProtos.reshape(numProtos, protoHeight * protoWidth);

  final coeffs = detection['maskCoeff'] as List<double>;

  // Create mask buffer
  final mask = img.Image(protoWidth, protoHeight);

  for (int y = 0; y < protoHeight; y++) {
    for (int x = 0; x < protoWidth; x++) {
      double m = 0.0;
      for (int k = 0; k < numProtos; k++) {
        m += proto3D[k][y * protoWidth + x] * coeffs[k];
      }
      // Threshold mask at 0.5
      final pixelVal = (m > 0.5) ? 255 : 0;
      mask.setPixel(x, y, img.getColor(pixelVal, pixelVal, pixelVal));
    }
  }

  // Resize mask to original image size
  final resizedMask = img.copyResize(mask, width: imgWidth, height: imgHeight, interpolation: img.Interpolation.nearest);

  return resizedMask;
}

  // yolov8 inference
Future<img.Image?> runInference(img.Image inputImage) async {
  if (!_isModelLoaded || _interpreter == null) {
    print('Yolov8 not loaded');
    return null;
  }

  final inputSize = 640;

  // Preprocess input image → [1,640,640,3]
  final input = preprocess(inputImage, inputSize);
  var inputShape = _interpreter!.getInputTensor(0).shape;
  var inputBuffer = input.buffer.asFloat32List();

  // Get output shapes
  var outputShape0 = _interpreter!.getOutputTensor(0).shape; // detections
  var outputShape1 = _interpreter!.getOutputTensor(1).shape; // mask protos

  // Allocate buffers
  var output0 = List.filled(
    outputShape0.reduce((a, b) => a * b),
    0.0,
  );

  var output1 = List.filled(
    outputShape1.reduce((a, b) => a * b),
    0.0,
  );

  // Run model with multiple outputs
  _interpreter!.runForMultipleInputs([inputBuffer], {0: output0, 1: output1});
  print('✅ Inference done. Got detections and mask prototypes.');

  // Parse detections (get nearest goat)
  final detections = parseDetections(
    output0,
    output1,
    inputImage.width,
    inputImage.height,
  );

  if (detections.isEmpty) {
    print("❌ No goats detected.");
    return null;
  }

  final goat = detections.first; // nearest goat already chosen

  // Build mask from proto + coeffs
  final mask = buildMaskFromProtos(goat, output1, inputImage.width, inputImage.height, outputShape1);

  // Overlay red on goat
  final segmentedGoat = applyRedOverlay(inputImage, mask);

  print("✅ Segmented goat image created.");
  return segmentedGoat;
}

  
}

