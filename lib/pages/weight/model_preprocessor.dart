import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Preprocessing helper for ResNet model
/// Takes the YOLOv8 segmented image and prepares it for weight prediction
class ModelPreprocessor {
  final int targetWidth;
  final int targetHeight;

  ModelPreprocessor({
    required this.targetWidth,
    required this.targetHeight,
  });

  Float32List preprocess(img.Image segmentedImage) {
    // Resize image
    final resized = img.copyResize(
      segmentedImage,
      width: targetWidth,
      height: targetHeight,
    );

    // Create flat tensor with RGB values normalized to [0,1]
    final tensor = Float32List(targetWidth * targetHeight * 3);
    int index = 0;

    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        final pixel = resized.getPixel(x, y);
        tensor[index++] = pixel.r / 255.0; // Red
        tensor[index++] = pixel.g / 255.0; // Green
        tensor[index++] = pixel.b / 255.0; // Blue
      }
    }

    return tensor;
  }
}
