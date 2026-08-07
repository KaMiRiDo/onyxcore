import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:onyxcore/core/cache/metadata_cache.dart';

/// Data source for media metadata extraction using ultra-fast header parsing and FFprobe fallback.
///
/// Extracts image aspect ratios and caches them persistently without freezing the UI or spawning thousands of processes.
class MediaMetadataDatasource {
  MediaMetadataDatasource(this._cache);

  final MetadataCache _cache;

  /// Get the cached aspect ratio for an image, or null if not cached.
  double? getCachedAspectRatio(String path) {
    return _cache.aspectRatios[path];
  }

  /// Extract the aspect ratio for an image using fast pure-Dart header parsing in an isolate.
  ///
  /// Returns the ratio (width/height) and caches it for future use.
  Future<Map<String, double>> extractAspectRatios(List<String> paths) async {
    final result = <String, double>{};
    final missing = <String>[];

    for (final path in paths) {
      final cached = _cache.aspectRatios[path];
      if (cached != null) {
        result[path] = cached;
      } else {
        missing.add(path);
      }
    }

    if (missing.isEmpty) {
      return result;
    }

    final ratios = await Isolate.run(() {
      final resMap = <String, double>{};
      for (final path in missing) {
        final parsedRatio = _parseImageDimensions(path);
        resMap[path] = parsedRatio ?? 1.0;
      }
      return resMap;
    });

    for (final entry in ratios.entries) {
      await _cache.saveRatio(entry.key, entry.value);
    }
    result.addAll(ratios);

    return result;
  }

  /// Fast pure-Dart parser for JPEG, PNG, GIF, BMP, and WebP dimensions.
  /// Reads only the first few bytes/segments of the file without decoding pixel data.
  static double? _parseImageDimensions(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      final raf = file.openSync();
      try {
        final length = raf.lengthSync();
        if (length < 24) return null;

        final header = raf.readSync(32);
        if (header.length < 24) return null;

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if (header[0] == 0x89 &&
            header[1] == 0x50 &&
            header[2] == 0x4E &&
            header[3] == 0x47) {
          final w = (header[16] << 24) |
              (header[17] << 16) |
              (header[18] << 8) |
              header[19];
          final h = (header[20] << 24) |
              (header[21] << 16) |
              (header[22] << 8) |
              header[23];
          if (w > 0 && h > 0) return w / h;
        }

        // GIF: GIF87a / GIF89a
        if (header[0] == 0x47 &&
            header[1] == 0x49 &&
            header[2] == 0x46) {
          final w = header[6] | (header[7] << 8);
          final h = header[8] | (header[9] << 8);
          if (w > 0 && h > 0) return w / h;
        }

        // BMP: 'B' 'M'
        if (header.length >= 26 && header[0] == 0x42 && header[1] == 0x4D) {
          final w = header[18] |
              (header[19] << 8) |
              (header[20] << 16) |
              (header[21] << 24);
          var h = header[22] |
              (header[23] << 8) |
              (header[24] << 16) |
              (header[25] << 24);
          if (h < 0) h = -h;
          if (w > 0 && h > 0) return w / h;
        }

        // WebP: 'RIFF' .... 'WEBP'
        if (header.length >= 30 &&
            header[0] == 0x52 &&
            header[1] == 0x49 &&
            header[2] == 0x46 &&
            header[3] == 0x46 &&
            header[8] == 0x57 &&
            header[9] == 0x45 &&
            header[10] == 0x42 &&
            header[11] == 0x50) {
          // VP8X
          if (header[12] == 0x56 &&
              header[13] == 0x50 &&
              header[14] == 0x38 &&
              header[15] == 0x58) {
            final w = 1 + (header[24] | (header[25] << 8) | (header[26] << 16));
            final h = 1 + (header[27] | (header[28] << 8) | (header[29] << 16));
            if (w > 0 && h > 0) return w / h;
          }
          // VP8
          if (header[12] == 0x56 &&
              header[13] == 0x50 &&
              header[14] == 0x38 &&
              header[15] == 0x20) {
            final w = (header[26] | (header[27] << 8)) & 0x3fff;
            final h = (header[28] | (header[29] << 8)) & 0x3fff;
            if (w > 0 && h > 0) return w / h;
          }
        }

        // JPEG: 0xFF 0xD8
        if (header[0] == 0xFF && header[1] == 0xD8) {
          raf.setPositionSync(2);
          final buffer = Uint8List(4);
          while (raf.positionSync() < length) {
            if (raf.readIntoSync(buffer, 0, 2) < 2) break;
            if (buffer[0] != 0xFF) break;
            final marker = buffer[1];
            if (marker == 0xFF) {
              raf.setPositionSync(raf.positionSync() - 1);
              continue;
            }
            // SOF0..SOF3, SOF5..SOF7, SOF9..SOF11, SOF13..SOF15
            if ((marker >= 0xC0 && marker <= 0xC3) ||
                (marker >= 0xC5 && marker <= 0xC7) ||
                (marker >= 0xC9 && marker <= 0xCB) ||
                (marker >= 0xCD && marker <= 0xCF)) {
              final segData = Uint8List(7);
              if (raf.readIntoSync(segData, 0, 7) >= 7) {
                final h = (segData[3] << 8) | segData[4];
                final w = (segData[5] << 8) | segData[6];
                if (w > 0 && h > 0) return w / h;
              }
              break;
            } else if (marker == 0xDA || marker == 0xD9) {
              // SOS (Start of Scan) or EOI (End of Image) -> stop searching
              break;
            } else {
              // Read segment length and skip forward
              if (raf.readIntoSync(buffer, 2, 4) < 2) break;
              final segLen = (buffer[2] << 8) | buffer[3];
              if (segLen < 2) break;
              raf.setPositionSync(raf.positionSync() + segLen - 2);
            }
          }
        }
      } finally {
        raf.closeSync();
      }
    } catch (_) {}
    return null;
  }

  Future<double?> extractAspectRatio(String path) async {
    // Check cache first
    final cached = _cache.aspectRatios[path];
    if (cached != null) return cached;

    final parsed = _parseImageDimensions(path);
    if (parsed != null) {
      await _cache.saveRatio(path, parsed);
      return parsed;
    }

    try {
      final result = await Process.run('ffprobe', [
        '-v',
        'error',
        '-select_streams',
        'v:0',
        '-show_entries',
        'stream=width,height',
        '-of',
        'csv=p=0',
        path,
      ]);

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          final parts = output.split(',');
          if (parts.length >= 2) {
            final w = double.tryParse(parts[0]) ?? 1.0;
            final h = double.tryParse(parts[1]) ?? 1.0;
            final ratio = w / h;
            await _cache.saveRatio(path, ratio);
            return ratio;
          }
        }
      }
    } catch (_) {
      // Fall through to default
    }
    return 1.0;
  }
}
