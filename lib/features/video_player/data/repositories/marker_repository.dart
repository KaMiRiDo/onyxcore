import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/video_marker.dart';

class MarkerRepository {
  static const String _sidecarDir = '.onyxcore';

  static String _getSidecarPath(String videoPath) {
    final dir = p.dirname(videoPath);
    final fileName = p.basename(videoPath);
    return p.join(dir, _sidecarDir, '.$fileName.markers.json');
  }

  static Future<String> _getFallbackPath(String videoPath) async {
    final appSupportDir = await getApplicationSupportDirectory();
    final markersDir = Directory(p.join(appSupportDir.path, 'markers'));
    if (!await markersDir.exists()) {
      await markersDir.create(recursive: true);
    }

    // Create a safe unique filename based on the path
    // Using simple hash-like replacement for stability
    final safeName = videoPath.length > 200
        ? videoPath
              .substring(videoPath.length - 200)
              .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        : videoPath.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

    return p.join(markersDir.path, '$safeName.markers.json');
  }

  static Future<List<VideoMarker>> loadMarkers(String videoPath) async {
    try {
      // 1. Try sidecar first
      final sidecarPath = _getSidecarPath(videoPath);
      final sidecarFile = File(sidecarPath);

      if (await sidecarFile.exists()) {
        final jsonString = await sidecarFile.readAsString();
        return _parseMarkers(jsonString);
      }

      // 2. Try fallback
      final fallbackPath = await _getFallbackPath(videoPath);
      final fallbackFile = File(fallbackPath);
      if (await fallbackFile.exists()) {
        final jsonString = await fallbackFile.readAsString();
        return _parseMarkers(jsonString);
      }
    } catch (e) {
      debugPrint('[MarkerRepository] Error loading markers: $e');
    }
    return [];
  }

  static List<VideoMarker> _parseMarkers(String jsonString) {
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((e) => VideoMarker.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[MarkerRepository] JSON parse error: $e');
      return [];
    }
  }

  static Future<void> saveMarkers(
    String videoPath,
    List<VideoMarker> markers,
  ) async {
    final jsonString = jsonEncode(markers.map((e) => e.toJson()).toList());

    try {
      // 1. Attempt sidecar save
      final sidecarPath = _getSidecarPath(videoPath);
      final sidecarDir = Directory(p.dirname(sidecarPath));

      if (!await sidecarDir.exists()) {
        await sidecarDir.create(recursive: true);
      }

      await File(sidecarPath).writeAsString(jsonString);
      debugPrint('[MarkerRepository] Saved to sidecar: $sidecarPath');
    } catch (e) {
      // 2. Fallback if sidecar fails (e.g. read-only filesystem)
      try {
        debugPrint(
          '[MarkerRepository] Sidecar save failed, using fallback. Error: $e',
        );
        final fallbackPath = await _getFallbackPath(videoPath);
        await File(fallbackPath).writeAsString(jsonString);
        debugPrint('[MarkerRepository] Saved to fallback: $fallbackPath');
      } catch (fallbackError) {
        debugPrint(
          '[MarkerRepository] Critical: Fallback save failed: $fallbackError',
        );
      }
    }
  }
}
