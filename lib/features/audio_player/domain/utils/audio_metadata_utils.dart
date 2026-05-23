import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audiotags/audiotags.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class AudioProperties {
  final String duration;
  final String bitrate;
  final String sampleRate;
  
  AudioProperties({
    required this.duration,
    required this.bitrate,
    required this.sampleRate,
  });
}

class AudioMetadataUtils {
  /// Reads audio tags in-place using audiotags.
  static Future<Tag?> readTags(String path) async {
    try {
      final tag = await AudioTags.read(path);
      return tag;
    } catch (e) {
      return null;
    }
  }

  /// Writes audio tags in-place using audiotags.
  static Future<bool> writeTags(String path, Tag tag) async {
    try {
      await AudioTags.write(path, tag);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Resizes cover art to prevent OOM errors and forces 1:1 aspect ratio.
  /// Used before writing a new image to ID3 tags.
  static Uint8List? prepareCoverArt(Uint8List originalBytes, {int targetSize = 600}) {
    try {
      final image = img.decodeImage(originalBytes);
      if (image == null) return null;
      
      // Crop to square
      final int size = image.width < image.height ? image.width : image.height;
      final int x = (image.width - size) ~/ 2;
      final int y = (image.height - size) ~/ 2;
      final cropped = img.copyCrop(image, x: x, y: y, width: size, height: size);
      
      // Resize
      final resized = img.copyResize(cropped, width: targetSize, height: targetSize, interpolation: img.Interpolation.linear);
      
      return Uint8List.fromList(img.encodeJpg(resized, quality: 90));
    } catch (e) {
      return null;
    }
  }

  /// Extracts read-only properties using FFprobe.
  static Future<AudioProperties> getProperties(String path) async {
    try {
      final result = await Process.run('bash', [
        '-c',
        'ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,bit_rate:format=duration,bit_rate -of json "$path"'
      ]);

      if (result.exitCode == 0) {
        final jsonStr = result.stdout.toString().trim();
        if (jsonStr.isNotEmpty) {
          final data = jsonDecode(jsonStr);
          
          final stream = data['streams']?[0] ?? {};
          final format = data['format'] ?? {};
          
          final double durationSec = double.tryParse(format['duration']?.toString() ?? '0') ?? 0;
          final int bitrateInt = int.tryParse(format['bit_rate']?.toString() ?? stream['bit_rate']?.toString() ?? '0') ?? 0;
          final int sampleRateInt = int.tryParse(stream['sample_rate']?.toString() ?? '0') ?? 0;

          return AudioProperties(
            duration: _formatDuration(durationSec),
            bitrate: bitrateInt > 0 ? '${(bitrateInt / 1000).round()} kbps' : 'Unknown',
            sampleRate: sampleRateInt > 0 ? '${sampleRateInt} Hz' : 'Unknown',
          );
        }
      }
    } catch (_) {}
    
    return AudioProperties(duration: 'Unknown', bitrate: 'Unknown', sampleRate: 'Unknown');
  }

  static String _formatDuration(double seconds) {
    if (seconds <= 0) return 'Unknown';
    final d = Duration(milliseconds: (seconds * 1000).round());
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$secs';
    return '$minutes:$secs';
  }
}
