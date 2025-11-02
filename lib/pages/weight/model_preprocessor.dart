import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Model type for preprocessing
enum PreprocessingModel {
  resnet,
  mobilenetv2,
}

/// Preprocessing helper for weight prediction models
/// Supports ResNet (normalized to [0,1]) and MobileNetV2 (normalized to [-1,1])
class ModelPreprocessor {
  final int targetWidth;
  final int targetHeight;
  final PreprocessingModel modelType;

  ModelPreprocessor({
    required this.targetWidth,
    required this.targetHeight,
    this.modelType = PreprocessingModel.resnet,
  });

  /// Converts [segmentedImage] into a Float32List
  /// - ResNet: normalized to [0,1]
  /// - MobileNetV2: normalized to [-1,1]
  Float32List preprocess(img.Image segmentedImage) {
    // Resize image
    final resized = img.copyResize(
      segmentedImage,
      width: targetWidth,
      height: targetHeight,
    );

    // Allocate tensor (width * height * 3 channels)
    final tensor = Float32List(targetWidth * targetHeight * 3);
    int index = 0;

    if (modelType == PreprocessingModel.mobilenetv2) {
      // MobileNetV2 preprocessing: [0,255] → [-1,1]
      for (int y = 0; y < targetHeight; y++) {
        for (int x = 0; x < targetWidth; x++) {
          final pixel = resized.getPixel(x, y);
          tensor[index++] = (pixel.r / 127.5) - 1.0; // Red
          tensor[index++] = (pixel.g / 127.5) - 1.0; // Green
          tensor[index++] = (pixel.b / 127.5) - 1.0; // Blue
        }
      }
    } else {
      // ResNet preprocessing: [0,255] → [0,1]
      for (int y = 0; y < targetHeight; y++) {
        for (int x = 0; x < targetWidth; x++) {
          final pixel = resized.getPixel(x, y);
          tensor[index++] = pixel.r / 255.0; // Red
          tensor[index++] = pixel.g / 255.0; // Green
          tensor[index++] = pixel.b / 255.0; // Blue
        }
      }
    }

    return tensor;
  }
}
