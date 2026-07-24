import 'dart:async';
import 'dart:io';

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
class ImageMetadata {

  const ImageMetadata({
    this.metadataString,
    this.imageSize,
  });
  final String? metadataString;
  final Size? imageSize;
}

/// Stateless async service. Loads image dimensions and builds a human-readable
/// metadata string. Used by ImagePreviewWidget to populate the top bar subtitle.
class ImageMetadataLoader {
  /// Loads metadata for [filePath].
  /// Returns an [ImageMetadata] record with `metadataString` and `imageSize`.
  /// Returns null values on error or missing file.
  static Future<ImageMetadata> load(
    String filePath,
    BuildContext context,
    Future<void> firstFrame,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return const ImageMetadata();
    }

    try {
      final isSvg = filePath.toLowerCase().endsWith('.svg');
      if (isSvg) {
        return const ImageMetadata(
          metadataString: 'Vector Graphic • Scalable',
        );
      }

      await firstFrame;

      if (!context.mounted) return const ImageMetadata();

      final buffer = await ui.ImmutableBuffer.fromFilePath(filePath);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final size = Size(descriptor.width.toDouble(), descriptor.height.toDouble());
      descriptor.dispose();
      buffer.dispose();

      final mp = (size.width * size.height / 1000000).toStringAsFixed(1);
      final metadataString = '${size.width.toInt()}x${size.height.toInt()} px • $mp MP';

      return ImageMetadata(
        metadataString: metadataString,
        imageSize: size,
      );
    } on TimeoutException {
      // Silently catch timeouts to prevent log spam for very slow images
      return const ImageMetadata();
    } catch (e) {
      if (e.toString().contains('Invalid image data') || e.toString().contains('Exception: Exception')) {
        // Silently catch unsupported formats
        return const ImageMetadata();
      }
      debugPrint('Error loading image metadata: $e');
      return const ImageMetadata();
    }
  }
}
