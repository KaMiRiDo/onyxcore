import 'dart:io';
import 'dart:isolate';

import 'package:onyxcore/core/cache/metadata_cache.dart';

/// Data source for media metadata extraction using FFprobe.
///
/// Extracts image aspect ratios and caches them persistently.
class MediaMetadataDatasource {
  MediaMetadataDatasource(this._cache);

  final MetadataCache _cache;

  /// Get the cached aspect ratio for an image, or null if not cached.
  double? getCachedAspectRatio(String path) {
    return _cache.aspectRatios[path];
  }

  /// Extract the aspect ratio for an image using FFprobe.
  ///
  /// Returns the ratio (width/height) and caches it for future use.
  Future<Map<String, double>> extractAspectRatios(List<String> paths) async {
    final ratios = await Isolate.run(() {
      final result = <String, double>{};
      for (final path in paths) {
        var ratio = 1.0;
        try {
          final res = Process.runSync('bash', [
            '-c',
            'ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$path"',
          ]);
          if (res.exitCode == 0) {
            final output = res.stdout.toString().trim();
            if (output.isNotEmpty) {
              final parts = output.split(',');
              if (parts.length >= 2) {
                final w = double.tryParse(parts[0]) ?? 1.0;
                final h = double.tryParse(parts[1]) ?? 1.0;
                if (h > 0) ratio = w / h;
              }
            }
          }
        } catch (_) {}
        result[path] = ratio;
      }
      return result;
    });

    for (final entry in ratios.entries) {
      await _cache.saveRatio(entry.key, entry.value);
    }
    
    return ratios;
  }

  Future<double?> extractAspectRatio(String path) async {
    // Check cache first
    final cached = _cache.aspectRatios[path];
    if (cached != null) return cached;

    try {
      final result = await Process.run('bash', [
        '-c',
        'ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$path"',
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
