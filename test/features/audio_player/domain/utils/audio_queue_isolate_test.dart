// ignore_for_file: inference_failure_on_collection_literal

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/audio_player/domain/utils/audio_queue_isolate.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:path/path.dart' as p;

void main() {
late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('audio_queue_isolate_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  FileItem createMockFileItem(String name, FileItemType type, [String? parentPath]) {
    final path = parentPath != null ? p.join(parentPath, name) : p.join(tempDir.path, name);
    return FileItem(
      path: path,
      name: name,
      type: type,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );
  }

  group('processAudioQueueIsolate', () {
    test('filter out non-audio file items from input list (U-AUD-ISOLATE-01)', () {
      final items = [
        createMockFileItem('song.mp3', FileItemType.audio).toJson(),
        createMockFileItem('video.mp4', FileItemType.video).toJson(),
        createMockFileItem('doc.txt', FileItemType.document).toJson(),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': true,
      });

      expect(result.length, 1);
      expect(result.first.name, 'song.mp3');
    });

    test('include folders that contain audio files (U-AUD-ISOLATE-02)', () {
      final folder = Directory(p.join(tempDir.path, 'Music'))..createSync();
      File(p.join(folder.path, 'song1.mp3')).createSync();
      File(p.join(folder.path, 'song2.flac')).createSync();
      File(p.join(folder.path, 'song3.wav')).createSync();

      final folderItem = createMockFileItem('Music', FileItemType.folder).toJson();

      final result = processAudioQueueIsolate({
        'items': [folderItem],
        'showHidden': true,
      });

      expect(result.length, 1);
      expect(result.first.name, 'Music');
      expect(result.first.itemCount, 3);
    });

    test('exclude folders that contain zero audio files (U-AUD-ISOLATE-03)', () {
      final folder = Directory(p.join(tempDir.path, 'Pictures'))..createSync();
      File(p.join(folder.path, 'img.jpg')).createSync();

      final folderItem = createMockFileItem('Pictures', FileItemType.folder).toJson();

      final result = processAudioQueueIsolate({
        'items': [folderItem],
        'showHidden': true,
      });

      expect(result.isEmpty, isTrue);
    });

    test('hide hidden files when showHidden is false (U-AUD-ISOLATE-04)', () {
      final items = [
        createMockFileItem('.hidden_song.mp3', FileItemType.audio).toJson(),
        createMockFileItem('visible_song.mp3', FileItemType.audio).toJson(),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': false,
      });

      expect(result.length, 1);
      expect(result.first.name, 'visible_song.mp3');
    });

    test('show hidden files when showHidden is true (U-AUD-ISOLATE-05)', () {
      final items = [
        createMockFileItem('.hidden_song.mp3', FileItemType.audio).toJson(),
        createMockFileItem('visible_song.mp3', FileItemType.audio).toJson(),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': true,
      });

      expect(result.length, 2);
    });

    test('skip hidden sub-files in folder count when showHidden is false (U-AUD-ISOLATE-06)', () {
      final folder = Directory(p.join(tempDir.path, 'Music'))..createSync();
      File(p.join(folder.path, '.hidden.mp3')).createSync();
      File(p.join(folder.path, 'visible.mp3')).createSync();

      final folderItem = createMockFileItem('Music', FileItemType.folder).toJson();

      final result = processAudioQueueIsolate({
        'items': [folderItem],
        'showHidden': false,
      });

      expect(result.length, 1);
      expect(result.first.itemCount, 1);
    });

    test('count hidden sub-files in folder count when showHidden is true (U-AUD-ISOLATE-07)', () {
      final folder = Directory(p.join(tempDir.path, 'Music'))..createSync();
      File(p.join(folder.path, '.hidden.mp3')).createSync();
      File(p.join(folder.path, 'visible.mp3')).createSync();

      final folderItem = createMockFileItem('Music', FileItemType.folder).toJson();

      final result = processAudioQueueIsolate({
        'items': [folderItem],
        'showHidden': true,
      });

      expect(result.length, 1);
      expect(result.first.itemCount, 2);
    });

    test('return empty list when all items are non-audio and non-folder (U-AUD-ISOLATE-08)', () {
      final items = [
        createMockFileItem('vid.mp4', FileItemType.video).toJson(),
        createMockFileItem('img.jpg', FileItemType.image).toJson(),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': true,
      });

      expect(result.isEmpty, isTrue);
    });

    test('return empty list when input items list is empty (U-AUD-ISOLATE-09)', () {
      final result = processAudioQueueIsolate({
        'items': [],
        'showHidden': true,
      });

      expect(result.isEmpty, isTrue);
    });

    test('handle non-existent folder paths gracefully (U-AUD-ISOLATE-10)', () {
      final folderItem = createMockFileItem('Missing', FileItemType.folder, '/does/not/exist').toJson();

      final result = processAudioQueueIsolate({
        'items': [folderItem],
        'showHidden': true,
      });

      expect(result.isEmpty, isTrue);
    });

    test('only scan one level deep (not recursive) (U-AUD-ISOLATE-11)', () {
      final folder = Directory(p.join(tempDir.path, 'Music'))..createSync();
      File(p.join(folder.path, 'root_song.mp3')).createSync();
      
      final subFolder = Directory(p.join(folder.path, 'SubFolder'))..createSync();
      File(p.join(subFolder.path, 'nested_song.mp3')).createSync();

      final folderItem = createMockFileItem('Music', FileItemType.folder).toJson();

      final result = processAudioQueueIsolate({
        'items': [folderItem],
        'showHidden': true,
      });

      expect(result.length, 1);
      expect(result.first.itemCount, 1); // Only root_song.mp3 is counted
    });

    test('preserve original order of audio items (U-AUD-ISOLATE-12)', () {
      final items = [
        createMockFileItem('audio_c.mp3', FileItemType.audio).toJson(),
        createMockFileItem('audio_a.mp3', FileItemType.audio).toJson(),
        createMockFileItem('audio_b.mp3', FileItemType.audio).toJson(),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': true,
      });

      expect(result.length, 3);
      expect(result[0].name, 'audio_c.mp3');
      expect(result[1].name, 'audio_a.mp3');
      expect(result[2].name, 'audio_b.mp3');
    });

    test('correctly deserialize FileItem from JSON map (U-AUD-ISOLATE-13)', () {
      final items = [
        createMockFileItem('song.mp3', FileItemType.audio).toJson(),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': true,
      });

      expect(result.length, 1);
      expect(result.first.name, 'song.mp3');
      expect(result.first.type, FileItemType.audio);
    });

    test('handle folder containing mixed audio and non-audio files (U-AUD-ISOLATE-14)', () {
      final folder = Directory(p.join(tempDir.path, 'Mixed'))..createSync();
      File(p.join(folder.path, 'song1.mp3')).createSync();
      File(p.join(folder.path, 'song2.wav')).createSync();
      File(p.join(folder.path, 'video.mp4')).createSync();
      File(p.join(folder.path, 'doc.txt')).createSync();

      final folderItem = createMockFileItem('Mixed', FileItemType.folder).toJson();

      final result = processAudioQueueIsolate({
        'items': [folderItem],
        'showHidden': true,
      });

      expect(result.length, 1);
      expect(result.first.itemCount, 2);
    });
  });
}
