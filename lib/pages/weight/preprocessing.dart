import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart';

class ImagePreprocessor {
  final int targetWidth;
  final int targetHeight;

  ImagePreprocessor({required this.targetWidth, required this.targetHeight});

  Future<Float32List> preprocess(String path) async {
    final bytes = await File(path).readAsBytes();
    Image? image = decodeImage(bytes);

    if (image == null) {
      throw Exception("Could not decode image at $path");
    }

    // Resize image
    Image resized = copyResize(
      image,
      width: targetWidth,
      height: targetHeight,
    );

    // Normalize pixels (0–1 range)
    Float32List floatData =
        Float32List(targetWidth * targetHeight * 3); // RGB
    int index = 0;

    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        int pixel = resized.getPixel(x, y);

        floatData[index++] = (getRed(pixel) / 255.0);
        floatData[index++] = (getGreen(pixel) / 255.0);
        floatData[index++] = (getBlue(pixel) / 255.0);
      }
    }

    return floatData;
  }
}