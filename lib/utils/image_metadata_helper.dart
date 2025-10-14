import 'dart:convert';
import 'package:native_exif/native_exif.dart';

/// Helper class for managing image metadata using EXIF
/// Stores segmentation status, weight, and processing date in image EXIF data
class ImageMetadataHelper {
  /// Check if an image has already been segmented by YOLOv8
  /// Returns true if the image contains segmentation metadata
  static Future<bool> isImageSegmented(String imagePath) async {
    try {
      final exif = await Exif.fromPath(imagePath);
      final userComment = await exif.getAttribute('UserComment');
      await exif.close();

      if (userComment == null) return false;

      final metadata = jsonDecode(userComment);
      return metadata['isSegmented'] == true;
    } catch (e) {
      print('Error checking image metadata: $e');
      return false;
    }
  }

  /// Get metadata from an image
  /// Returns a map with isSegmented, weight, processedDate, modelVersion
  static Future<Map<String, dynamic>?> getMetadata(String imagePath) async {
    try {
      final exif = await Exif.fromPath(imagePath);
      final userComment = await exif.getAttribute('UserComment');
      await exif.close();

      if (userComment == null) return null;

      return jsonDecode(userComment) as Map<String, dynamic>;
    } catch (e) {
      print('Error reading metadata: $e');
      return null;
    }
  }

  /// Save metadata to an image file
  /// Marks image as segmented with weight and processing information
  static Future<void> saveMetadata({
    required String imagePath,
    required bool isSegmented,
    required String weight,
    String? modelVersion,
  }) async {
    try {
      final metadata = {
        'isSegmented': isSegmented,
        'weight': weight,
        'processedDate': DateTime.now().toIso8601String(),
        'modelVersion': modelVersion ?? 'yolov8x-seg',
        'appVersion': '1.0.0',
      };

      final exif = await Exif.fromPath(imagePath);
      await exif.writeAttribute('UserComment', jsonEncode(metadata));
      await exif.close();

      print('Metadata saved to $imagePath: $metadata');
    } catch (e) {
      print('Error saving metadata: $e');
      throw Exception('Failed to save metadata: $e');
    }
  }

  /// Get the weight from image metadata
  /// Returns null if no weight is found
  static Future<String?> getWeight(String imagePath) async {
    final metadata = await getMetadata(imagePath);
    return metadata?['weight'] as String?;
  }

  /// Get the processed date from image metadata
  /// Returns null if no date is found
  static Future<DateTime?> getProcessedDate(String imagePath) async {
    final metadata = await getMetadata(imagePath);
    final dateStr = metadata?['processedDate'] as String?;
    if (dateStr == null) return null;
    
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      print('Error parsing date: $e');
      return null;
    }
  }

  /// Copy EXIF data from one image to another
  /// Useful for preserving metadata when processing images
  static Future<void> copyMetadata({
    required String sourcePath,
    required String destPath,
  }) async {
    try {
      final sourceExif = await Exif.fromPath(sourcePath);
      final destExif = await Exif.fromPath(destPath);

      // Copy UserComment (our custom metadata)
      final userComment = await sourceExif.getAttribute('UserComment');
      if (userComment != null) {
        await destExif.writeAttribute('UserComment', userComment);
      }

      await sourceExif.close();
      await destExif.close();
    } catch (e) {
      print('Error copying metadata: $e');
    }
  }

  /// Remove metadata from an image
  /// Useful for clearing segmentation markers
  static Future<void> removeMetadata(String imagePath) async {
    try {
      final exif = await Exif.fromPath(imagePath);
      await exif.writeAttribute('UserComment', '');
      await exif.close();
    } catch (e) {
      print('Error removing metadata: $e');
    }
  }
}
