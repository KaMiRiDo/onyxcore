import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:onyxcore/features/downloader/presentation/services/thumbnail_aspect_resolver.dart';

/// Asynchronously generates temporary thumbnails for remote video URLs using FFmpeg.
class RemoteVideoThumbnailResolver {
  static final Map<String, String> _resolvedPaths = {};
  static final Set<String> _pendingUrls = {};
  static final Set<String> _failedUrls = {};

  /// Returns the local file path to the generated thumbnail, or null if it hasn't been generated yet.
  static String? getThumbnailPath(String? url) {
    if (url == null || url.isEmpty) return null;
    return _resolvedPaths[url];
  }

  static bool isFailed(String? url) {
    if (url == null || url.isEmpty) return false;
    return _failedUrls.contains(url);
  }

  /// Begins generating a temporary thumbnail for the given URL if one does not already exist.
  static Future<void> generate(String? url) async {
    if (url == null || url.isEmpty) return;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    if (_resolvedPaths.containsKey(url) || _pendingUrls.contains(url) || _failedUrls.contains(url)) return;

    _pendingUrls.add(url);
    
    // Hash the URL for the cache path
    final hash = md5.convert(utf8.encode(url)).toString();
    final cacheDir = '${Directory.systemTemp.path}/onyxcore_thumbnails';
    Directory(cacheDir).createSync(recursive: true);
    final tempPath = '$cacheDir/$hash.jpg';
    final file = File(tempPath);
    
    if (file.existsSync() && file.lengthSync() > 0) {
       _resolvedPaths[url] = tempPath;
       _pendingUrls.remove(url);
       ThumbnailAspectResolver.updates.value++;
       return;
    }

    try {
       final process = await Process.start('ffmpeg', [
          '-i', url,
          '-vframes', '1',
          '-an',
          '-s', '320x180',
          '-ss', '00:00:00',
          '-f', 'image2',
          '-y',
          tempPath
       ]);
       await process.exitCode;
       if (file.existsSync() && file.lengthSync() > 0) {
          _resolvedPaths[url] = tempPath;
          ThumbnailAspectResolver.updates.value++;
       } else {
          _failedUrls.add(url);
          ThumbnailAspectResolver.updates.value++;
       }
    } catch (_) {
       _failedUrls.add(url);
       ThumbnailAspectResolver.updates.value++;
    }
    _pendingUrls.remove(url);
  }

  /// Cleans up the temporary thumbnail file for the given URL.
  static Future<void> cleanup(String url) async {
    final path = _resolvedPaths.remove(url);
    _pendingUrls.remove(url);
    _failedUrls.remove(url);
    if (path != null) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    } else {
      // Try resolving hash manually to delete even if not in map
      final hash = md5.convert(utf8.encode(url)).toString();
      final cacheDir = '${Directory.systemTemp.path}/onyxcore_thumbnails';
      final tempPath = '$cacheDir/$hash.jpg';
      try {
        final file = File(tempPath);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
  }

  @visibleForTesting
  static void setPathForTesting(String url, String path) {
    _resolvedPaths[url] = path;
  }

  @visibleForTesting
  static void reset() {
    _resolvedPaths.clear();
    _pendingUrls.clear();
    _failedUrls.clear();
  }
}
