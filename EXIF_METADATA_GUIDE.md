# EXIF Metadata Implementation Guide

## Overview
This implementation uses EXIF metadata to track whether images have been processed by YOLOv8 segmentation. This is a production-ready approach where metadata travels with the image file.

## How It Works

### 1. **When Saving Images** (`_saveWeight()`)
```dart
// Save image
await File(filePath).writeAsBytes(imageBytes);

// Add EXIF metadata
await ImageMetadataHelper.saveMetadata(
  imagePath: filePath,
  isSegmented: true,
  weight: _weightDisplay,
  modelVersion: 'yolov8x-seg',
);
```

**Metadata Stored:**
- `isSegmented`: Boolean flag (true/false)
- `weight`: Weight value (e.g., "20.2")
- `processedDate`: ISO timestamp
- `modelVersion`: "yolov8x-seg"
- `appVersion`: "1.0.0"

### 2. **When Loading Images** (`_processImagePipeline()`)
```dart
// Check if image is already segmented
final isSegmented = await ImageMetadataHelper.isImageSegmented(imagePath);

if (isSegmented) {
  // Skip YOLOv8, load directly
  final existingWeight = await ImageMetadataHelper.getWeight(imagePath);
  // Display cached weight
} else {
  // Run full YOLOv8 pipeline
  final segmentedImage = await _yolov8Processor.processImage(originalImage);
}
```

## Workflow Scenarios

### Scenario 1: Fresh Camera Photo
1. User takes photo → No EXIF metadata
2. System runs YOLOv8 segmentation
3. Predicts weight with ResNet
4. User presses SAVE → Image saved WITH metadata

### Scenario 2: Gallery - Already Segmented Image
1. User selects saved segmented image from gallery
2. System checks EXIF → `isSegmented: true`
3. Loads cached weight from metadata
4. **YOLOv8 is skipped** (saves processing time!)

### Scenario 3: Gallery - New Image
1. User selects external image (no metadata)
2. System checks EXIF → No metadata found
3. Runs full YOLOv8 pipeline
4. Predicts weight
5. User can save with metadata

### Scenario 4: Redo Processing
1. User presses "Redo" button
2. Uses stored `_originalImage` from memory
3. Re-runs YOLOv8 segmentation
4. Updates weight prediction
5. Does NOT save automatically

## Benefits

✅ **Performance**: Skip YOLOv8 for already-processed images  
✅ **Data Integrity**: Metadata travels with image  
✅ **User Experience**: Instant load for saved images  
✅ **Production Ready**: Industry-standard approach  
✅ **Shareable**: Image + metadata can be shared together  

## File Structure
```
lib/
├── utils/
│   └── image_metadata_helper.dart  # EXIF operations
├── pages/
│   └── weight/
│       └── weightScreen.dart       # Uses metadata helper
```

## Saved Images Location
```
/storage/emulated/0/Pictures/CambingThesis/
├── goat_20.2kg_1728665432.jpg    (with EXIF metadata embedded)
├── goat_18.5kg_1728665555.jpg    (with EXIF metadata embedded)
└── ...
```

## API Methods Available

### Check if Image is Segmented
```dart
final bool isSegmented = await ImageMetadataHelper.isImageSegmented(imagePath);
```

### Get Full Metadata
```dart
final metadata = await ImageMetadataHelper.getMetadata(imagePath);
// Returns: {isSegmented: true, weight: "20.2", processedDate: "...", ...}
```

### Get Specific Values
```dart
final weight = await ImageMetadataHelper.getWeight(imagePath);
final date = await ImageMetadataHelper.getProcessedDate(imagePath);
```

### Save Metadata
```dart
await ImageMetadataHelper.saveMetadata(
  imagePath: filePath,
  isSegmented: true,
  weight: "20.2",
  modelVersion: "yolov8x-seg",
);
```

### Copy Metadata Between Images
```dart
await ImageMetadataHelper.copyMetadata(
  sourcePath: originalPath,
  destPath: newPath,
);
```

### Remove Metadata
```dart
await ImageMetadataHelper.removeMetadata(imagePath);
```

## Testing

### Test Case 1: Save and Reload
1. Take photo, save with weight
2. Select same image from gallery
3. Should load instantly without YOLOv8

### Test Case 2: External Image
1. Add external goat photo to gallery
2. Select it in app
3. Should run full YOLOv8 pipeline

### Test Case 3: Share Image
1. Save processed image
2. Share via any app
3. Recipient's app should see metadata

## Debugging

To view metadata manually:
```dart
final metadata = await ImageMetadataHelper.getMetadata(imagePath);
print('Metadata: $metadata');
```

Console output:
```
Metadata saved to /path/to/image.jpg: {
  isSegmented: true,
  weight: 20.2,
  processedDate: 2025-10-11T14:30:52.123Z,
  modelVersion: yolov8x-seg,
  appVersion: 1.0.0
}
```

## Migration from JSON (if needed)

If you had JSON sidecar files before, you can migrate:
```dart
// Read old JSON file
final jsonFile = File(imagePath.replaceAll('.jpg', '.json'));
if (await jsonFile.exists()) {
  final metadata = jsonDecode(await jsonFile.readAsString());
  
  // Write to EXIF
  await ImageMetadataHelper.saveMetadata(
    imagePath: imagePath,
    isSegmented: metadata['isSegmented'],
    weight: metadata['weight'],
  );
  
  // Delete old JSON file
  await jsonFile.delete();
}
```

## Notes

- EXIF metadata is stored in the JPEG file's metadata header
- Does not increase file size significantly (~1-2 KB)
- Compatible with all major photo viewers
- Persists through most sharing methods
- Some social media apps may strip EXIF (Instagram, etc.)
