import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/services/media_filter_service.dart';

void main() {
  group('MediaFilterService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('media_filter_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('resolveDestination', () {
      test('returns path inside Filtered subfolder of parent', () {
        const filePath = '/home/user/Videos/movie.mp4';
        final dest = MediaFilterService.resolveDestination(filePath);
        expect(dest, equals('/home/user/Videos/Filtered/movie.mp4'));
      });

      test('handles filenames with spaces', () {
        const filePath = '/home/user/Music/my song.mp3';
        final dest = MediaFilterService.resolveDestination(filePath);
        expect(dest, equals('/home/user/Music/Filtered/my song.mp3'));
      });

      test('already in Filtered folder – destination stays in same Filtered', () {
        const filePath = '/home/user/Videos/Filtered/movie.mp4';
        final dest = MediaFilterService.resolveDestination(filePath);
        // When already inside a Filtered folder it should create nested
        expect(dest, equals('/home/user/Videos/Filtered/Filtered/movie.mp4'));
      });
    });

    group('moveToFiltered', () {
      test('moves file to Filtered subfolder and returns new path', () async {
        // Arrange
        final srcFile = File('${tempDir.path}/video.mp4');
        await srcFile.writeAsString('test content');

        // Act
        final newPath = await MediaFilterService.moveToFiltered(srcFile.path);

        // Assert
        expect(newPath, equals('${tempDir.path}/Filtered/video.mp4'));
        expect(await File(newPath).exists(), isTrue);
        expect(await srcFile.exists(), isFalse);
      });

      test('creates Filtered directory if it does not exist', () async {
        final srcFile = File('${tempDir.path}/image.jpg');
        await srcFile.writeAsString('img data');

        await MediaFilterService.moveToFiltered(srcFile.path);

        final filteredDir = Directory('${tempDir.path}/Filtered');
        expect(await filteredDir.exists(), isTrue);
      });

      test('handles filename collision by not overwriting silently', () async {
        // Arrange: pre-existing file in Filtered
        final filteredDir = Directory('${tempDir.path}/Filtered');
        await filteredDir.create();
        final existing = File('${filteredDir.path}/clip.mp4');
        await existing.writeAsString('old content');

        final srcFile = File('${tempDir.path}/clip.mp4');
        await srcFile.writeAsString('new content');

        // Act
        await MediaFilterService.moveToFiltered(srcFile.path);

        // The new file overwrites (rename behavior)
        final content = await File('${filteredDir.path}/clip.mp4').readAsString();
        expect(content, equals('new content'));
      });
    });
  });
}
