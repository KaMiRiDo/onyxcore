import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/data/repositories/marker_repository.dart';
import 'package:onyxcore/features/video_player/domain/entities/video_marker.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MarkerRepository', () {
    late Directory tempDir;
    late Directory appSupportDir;
    late String videoPath;
    late String sidecarPath;
    late String fallbackPath;

    const tMarkers = [
      VideoMarker(id: '1', timestamp: Duration(seconds: 1), content: 'M1'),
      VideoMarker(id: '2', timestamp: Duration(seconds: 2), content: 'M2'),
    ];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('marker_test_');
      appSupportDir = Directory(p.join(tempDir.path, 'app_support'));
      await appSupportDir.create();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationSupportDirectory') {
            return appSupportDir.path;
          }
          return null;
        },
      );

      videoPath = p.join(tempDir.path, 'video.mp4');
      sidecarPath = p.join(tempDir.path, '.onyxcore', '.video.mp4.markers.json');
      
      final safeName = videoPath.replaceAll(RegExp('[^a-zA-Z0-9]'), '_');
      fallbackPath = p.join(appSupportDir.path, 'markers', '$safeName.markers.json');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should save and load markers from sidecar successfully', () async {
      await MarkerRepository.saveMarkers(videoPath, tMarkers);

      // Verify sidecar file exists
      final sidecarFile = File(sidecarPath);
      expect(await sidecarFile.exists(), isTrue);

      // Verify content
      final loadedMarkers = await MarkerRepository.loadMarkers(videoPath);
      expect(loadedMarkers, equals(tMarkers));
    });

    test('should fallback to app support directory if sidecar is unwritable', () async {
      // Simulate unwritable sidecar by creating a file where the directory should be
      final sidecarDir = File(p.join(tempDir.path, '.onyxcore'));
      await sidecarDir.writeAsString('not a dir');

      await MarkerRepository.saveMarkers(videoPath, tMarkers);

      // Verify sidecar file does not exist (because it failed)
      final sidecarFile = File(sidecarPath);
      expect(await sidecarFile.exists(), isFalse);

      // Verify fallback file exists
      final fallbackFile = File(fallbackPath);
      expect(await fallbackFile.exists(), isTrue);

      // Verify content loaded from fallback
      final loadedMarkers = await MarkerRepository.loadMarkers(videoPath);
      expect(loadedMarkers, equals(tMarkers));
    });

    test('should return empty list if no markers found', () async {
      final loadedMarkers = await MarkerRepository.loadMarkers(videoPath);
      expect(loadedMarkers, isEmpty);
    });

    test('should return empty list if json is invalid', () async {
      // Write invalid json to sidecar
      final sidecarFile = File(sidecarPath);
      await sidecarFile.create(recursive: true);
      await sidecarFile.writeAsString('invalid json');

      final loadedMarkers = await MarkerRepository.loadMarkers(videoPath);
      expect(loadedMarkers, isEmpty);
    });
  });
}
