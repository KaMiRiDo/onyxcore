import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/video_player/presentation/services/screenshot_service.dart';
import 'package:path/path.dart' as p;

class MockPlayer extends Mock implements Player {}

void main() {
  group('ScreenshotService', () {
    late MockPlayer mockPlayer;
    late Directory tempDir;
    late File videoFile;

    setUp(() {
      mockPlayer = MockPlayer();
      tempDir = Directory.systemTemp.createTempSync('screenshot_test_');
      videoFile = File(p.join(tempDir.path, 'test_video.mp4'));
      videoFile.createSync();
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('captureAndSave creates Snapshots directory and saves png', () async {
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);
      when(() => mockPlayer.screenshot()).thenAnswer((_) async => fakeBytes);

      await ScreenshotService.captureAndSave(
        player: mockPlayer,
        videoPath: videoFile.path,
      );

      final snapshotsDir = Directory(p.join(tempDir.path, 'Snapshots'));
      expect(snapshotsDir.existsSync(), isTrue);
      
      final files = snapshotsDir.listSync();
      expect(files.length, 1);
      
      final savedFile = files.first as File;
      expect(savedFile.path.endsWith('.png'), isTrue);
      expect(savedFile.path.contains('test_video_'), isTrue);
      
      final savedBytes = savedFile.readAsBytesSync();
      expect(savedBytes, equals(fakeBytes));
    });

    test('captureAndSave does nothing if screenshot returns null', () async {
      when(() => mockPlayer.screenshot()).thenAnswer((_) async => null);

      await ScreenshotService.captureAndSave(
        player: mockPlayer,
        videoPath: videoFile.path,
      );

      final snapshotsDir = Directory(p.join(tempDir.path, 'Snapshots'));
      expect(snapshotsDir.existsSync(), isFalse);
    });

    test('captureAndSave handles exceptions gracefully', () async {
      when(() => mockPlayer.screenshot()).thenThrow(Exception('test exception'));

      // Should not throw, but catch and print
      await ScreenshotService.captureAndSave(
        player: mockPlayer,
        videoPath: videoFile.path,
      );

      final snapshotsDir = Directory(p.join(tempDir.path, 'Snapshots'));
      expect(snapshotsDir.existsSync(), isFalse);
    });
  });
}
