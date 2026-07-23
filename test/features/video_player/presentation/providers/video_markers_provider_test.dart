import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_markers_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoMarkersProvider', () {
    late ProviderContainer container;
    late Directory tempDir;
    late Directory appSupportDir;
    late String videoPath;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('marker_provider_test_');
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
      container = ProviderContainer();
    });

    tearDown(() async {
      container.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('videoMarkersProvider loads empty initially', () async {
      final markers = await container.read(videoMarkersProvider(videoPath).future);
      expect(markers, isEmpty);
    });

    test('addMarker should add a new marker and invalidate provider', () async {
      final actions = container.read(markerActionsProvider);

      await actions.addMarker(
        videoPath,
        const Duration(seconds: 5),
        'First marker',
      );

      final markers = await container.read(videoMarkersProvider(videoPath).future);
      expect(markers.length, 1);
      expect(markers.first.content, 'First marker');
      expect(markers.first.timestamp, const Duration(seconds: 5));
    });

    test('updateMarker should modify existing marker', () async {
      final actions = container.read(markerActionsProvider);

      await actions.addMarker(
        videoPath,
        const Duration(seconds: 5),
        'First marker',
      );

      var markers = await container.read(videoMarkersProvider(videoPath).future);
      final originalMarker = markers.first;

      final updatedMarker = originalMarker.copyWith(content: 'Updated marker');
      await actions.updateMarker(videoPath, updatedMarker);

      markers = await container.read(videoMarkersProvider(videoPath).future);
      expect(markers.length, 1);
      expect(markers.first.content, 'Updated marker');
    });

    test('deleteMarker should remove a marker', () async {
      final actions = container.read(markerActionsProvider);

      await actions.addMarker(
        videoPath,
        const Duration(seconds: 5),
        'First marker',
      );

      var markers = await container.read(videoMarkersProvider(videoPath).future);
      expect(markers.length, 1);

      await actions.deleteMarker(videoPath, markers.first.id);

      markers = await container.read(videoMarkersProvider(videoPath).future);
      expect(markers, isEmpty);
    });

    test('deleteAllMarkers should remove all markers', () async {
      final actions = container.read(markerActionsProvider);

      await actions.addMarker(
        videoPath,
        const Duration(seconds: 1),
        'M1',
      );
      await actions.addMarker(
        videoPath,
        const Duration(seconds: 2),
        'M2',
      );

      var markers = await container.read(videoMarkersProvider(videoPath).future);
      expect(markers.length, 2);

      await actions.deleteAllMarkers(videoPath);

      markers = await container.read(videoMarkersProvider(videoPath).future);
      expect(markers, isEmpty);
    });
  });
}
