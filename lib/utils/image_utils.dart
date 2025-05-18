import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import '../models/detection_model.dart';

class ImageUtils {
  /// Convert from raw pixel coordinates to normalized 0-1000 range coordinates
  static Future<BoundingBox> convertToNormalizedBoundingBox(
    String imagePath,
    BoundingBox originalBox,
  ) async {
    // Get original image dimensions
    final File imageFile = File(imagePath);
    final image = await _getImageDimensions(imageFile);

    if (image == null) {
      // If we can't get dimensions, return the original
      return originalBox;
    } // Check if coordinates are already in 0-1000 range
    if (originalBox.x2 <= 1000 && originalBox.y2 <= 1000) {
      return originalBox;
    }

    // Convert from pixel coordinates to 0-1000 range
    int normalizedX1 =
        (originalBox.x1 * 1000 / image.width).round().clamp(0, 1000);
    int normalizedY1 =
        (originalBox.y1 * 1000 / image.height).round().clamp(0, 1000);
    int normalizedX2 =
        (originalBox.x2 * 1000 / image.width).round().clamp(0, 1000);
    int normalizedY2 =
        (originalBox.y2 * 1000 / image.height).round().clamp(0, 1000);

    return BoundingBox(
      x1: normalizedX1,
      y1: normalizedY1,
      x2: normalizedX2,
      y2: normalizedY2,
    );
  }

  // Get the dimensions of an image
  static Future<ui.Image?> _getImageDimensions(File imageFile) async {
    try {
      final Uint8List bytes = await imageFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      // Silent error - just return null
      return null;
    }
  }
}
