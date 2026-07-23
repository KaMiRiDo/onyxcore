import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class SpecialImageConverter {
  static final _conversionQueue = <Future<void>>[];

  static Future<bool> _convertDngToJpgPreview(List<String> args) async {
    final sourcePath = args[0];
    final destPath = args[1];
    try {
      final bytes = File(sourcePath).readAsBytesSync();
      final image = img.decodeImage(bytes);
      if (image == null) return false;
      final jpegBytes = img.encodeJpg(image, quality: 90);
      File(destPath).writeAsBytesSync(jpegBytes);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> convertIfNecessary(String sourcePath) async {
    final ext = sourcePath.toLowerCase();
    final isHeic =
        ext.endsWith('.heic') || ext.endsWith('.heif') || ext.endsWith('.avif');
    final isDng = ext.endsWith('.dng') || ext.endsWith('.raw');

    if (!isHeic && !isDng) {
      return null;
    }

    final tempPath =
        '${Directory.systemTemp.path}/onyx_special_${sourcePath.hashCode}.jpg';
    final tempFile = File(tempPath);

    if (tempFile.existsSync() && tempFile.lengthSync() > 0) {
      return tempPath;
    }

    final completer = Completer<void>();
    final previousTasks = List<Future<void>>.from(_conversionQueue);
    _conversionQueue.add(completer.future);

    try {
      if (previousTasks.isNotEmpty) {
        await Future.wait(previousTasks);
      }
    } catch (_) {}

    final uniqueTempPath =
        '${Directory.systemTemp.path}/onyx_special_${sourcePath.hashCode}_${DateTime.now().microsecondsSinceEpoch}.jpg';

    try {
      if (isHeic) {
        final isUnix = Platform.isLinux || Platform.isMacOS;
        final process = await Process.start(
          isUnix ? 'nice' : 'heif-thumbnailer',
          isUnix 
              ? ['-n', '19', 'heif-thumbnailer', '-s', '1920', sourcePath, uniqueTempPath]
              : ['-s', '1920', sourcePath, uniqueTempPath],
        );
        await process.exitCode;

        final file = File(uniqueTempPath);
        if (!file.existsSync() || file.lengthSync() == 0) {
          final fallbackProcess = await Process.start(
            isUnix ? 'nice' : 'ffmpeg',
            isUnix 
                ? ['-n', '19', 'ffmpeg', '-y', '-i', sourcePath, '-vframes', '1', '-q:v', '2', '-update', '1', uniqueTempPath]
                : ['-y', '-i', sourcePath, '-vframes', '1', '-q:v', '2', '-update', '1', uniqueTempPath],
          );
          await fallbackProcess.exitCode;
        }
      } else if (isDng) {
        await compute(_convertDngToJpgPreview, [sourcePath, uniqueTempPath]);
      }

      final uniqueFile = File(uniqueTempPath);
      if (uniqueFile.existsSync() && uniqueFile.lengthSync() > 0) {
        uniqueFile.renameSync(tempPath);
        return tempPath;
      }
    } catch (e) {
      debugPrint('Failed to convert special image: $e');
    } finally {
      completer.complete();
      _conversionQueue.remove(completer.future);
    }

    final finalFile = File(tempPath);
    if (finalFile.existsSync() && finalFile.lengthSync() > 0) {
      return tempPath;
    }
    return null;
  }
}
