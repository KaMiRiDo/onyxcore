import 'dart:async';
import 'dart:io';

import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
class ImageMetadata {
  final String? metadataString;
  final Size? imageSize;

  const ImageMetadata({
    this.metadataString,
    this.imageSize,
  });
}

/// Stateless async service. Loads image dimensions and builds a human-readable
/// metadata string. Used by ImagePreviewWidget to populate the top bar subtitle.
class ImageMetadataLoader {
  /// Loads metadata for [filePath].
  /// Returns an [ImageMetadata] record with [metadataString] and [imageSize].
  /// Returns null values on error or missing file.
  static Future<ImageMetadata> load(
    String filePath,
    BuildContext context,
    Future<void> firstFrame,
  ) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      return const ImageMetadata(metadataString: null, imageSize: null);
    }

    try {
      final isSvg = filePath.toLowerCase().endsWith('.svg');
      if (isSvg) {
        return const ImageMetadata(
          metadataString: 'Vector Graphic • Scalable',
          imageSize: null,
        );
      }

      await firstFrame;

      if (!context.mounted) return const ImageMetadata();

      // Read image header in a background isolate to prevent main thread blocking
      final size = await Isolate.run(() {
        final bytes = file.readAsBytesSync();
        final decoder = img.findDecoderForNamedImage(filePath);
        if (decoder != null) {
          final info = decoder.startDecode(bytes);
          if (info != null) {
            return Size(info.width.toDouble(), info.height.toDouble());
          }
        }
        return null;
      });

      if (size == null) {
        return const ImageMetadata(metadataString: null, imageSize: null);
      }

      final mp = (size.width * size.height / 1000000).toStringAsFixed(1);
      final metadataString = '${size.width.toInt()}x${size.height.toInt()} px • $mp MP';

      return ImageMetadata(
        metadataString: metadataString,
        imageSize: size,
      );
    } on TimeoutException {
      // Silently catch timeouts to prevent log spam for very slow images
      return const ImageMetadata(metadataString: null, imageSize: null);
    } catch (e) {
      if (e.toString().contains('Invalid image data')) {
        // Silently catch unsupported formats (e.g. attempting to read a video or raw file as an image)
        return const ImageMetadata(metadataString: null, imageSize: null);
      }
      debugPrint('Error loading image metadata: $e');
      return const ImageMetadata(metadataString: null, imageSize: null);
    }
  }
}
