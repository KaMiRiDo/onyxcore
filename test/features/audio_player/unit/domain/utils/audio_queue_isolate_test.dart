
import 'package:hive/hive.dart' as import_hive;
import 'dart:io' as import_io;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/audio_player/domain/utils/audio_queue_isolate.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

void main() {
  setUpAll(() {
    try {
      import_hive.Hive.init(import_io.Directory.systemTemp.path);
    } catch (_) {}
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Shared test infrastructure
  // ─────────────────────────────────────────────────────────────────────────
  late Directory tempDir;

  /// Helper to create a real temp directory before each test.
  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('audio_queue_isolate_test_');
  });

  /// Clean up after each test.
  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// Convenience: creates a [FileItem] JSON map.
  Map<String, dynamic> makeItem({
    required String name,
    required String path,
    required FileItemType type,
    int? itemCount,
  }) {
    return FileItem(
      path: path,
      name: name,
      type: type,
      modified: DateTime(2026),
      itemCount: itemCount,
    ).toJson();
  }

  group('processAudioQueueIsolate', () {
    // ── U-AUD-ISOLATE-01 ──
    test('filters out non-audio file items from input list', () {
      final items = [
        makeItem(
          name: 'song.mp3',
          path: '/music/song.mp3',
          type: FileItemType.audio,
        ),
        makeItem(
          name: 'clip.mp4',
          path: '/videos/clip.mp4',
          type: FileItemType.video,
        ),
        makeItem(
          name: 'photo.jpg',
          path: '/images/photo.jpg',
          type: FileItemType.image,
        ),
        makeItem(
          name: 'readme.txt',
          path: '/docs/readme.txt',
          type: FileItemType.document,
        ),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': true,
      });

      expect(result, hasLength(1));
      expect(result[0].name, 'song.mp3');
      expect(result[0].type, FileItemType.audio);
    });

    // ── U-AUD-ISOLATE-02 ──
    test('includes folders that contain audio files', () {
      // Create real folder with 3 audio files on disk.
      final subDir = Directory('${tempDir.path}/music_folder')
        ..createSync();
      File('${subDir.path}/track1.mp3').createSync();
      File('${subDir.path}/track2.wav').createSync();
      File('${subDir.path}/track3.flac').createSync();

      final items = [
        makeItem(
          name: 'music_folder',
          path: subDir.path,
          type: FileItemType.folder,
        ),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': true,
      });

      expect(result, hasLength(1));
      expect(result[0].name, 'music_folder');
      expect(result[0].itemCount, 3);
    });

    // ── U-AUD-ISOLATE-03 ──
    test('excludes folders that contain zero audio files', () {
      final subDir = Directory('${tempDir.path}/images_folder')
        ..createSync();
      File('${subDir.path}/photo1.jpg').createSync();
      File('${subDir.path}/photo2.png').createSync();

      final items = [
        makeItem(
          name: 'images_folder',
          path: subDir.path,
          type: FileItemType.folder,
        ),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': true,
      });

      expect(result, isEmpty);
    });

    // ── U-AUD-ISOLATE-04 ──
    test('hides hidden files when showHidden is false', () {
      final items = [
        makeItem(
          name: '.hidden_song.mp3',
          path: '/music/.hidden_song.mp3',
          type: FileItemType.audio,
        ),
        makeItem(
          name: 'visible_song.mp3',
          path: '/music/visible_song.mp3',
          type: FileItemType.audio,
        ),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': false,
      });

      expect(result, hasLength(1));
      expect(result[0].name, 'visible_song.mp3');
    });

    // ── U-AUD-ISOLATE-05 ──
    test('shows hidden files when showHidden is true', () {
      final items = [
        makeItem(
          name: '.hidden_song.mp3',
          path: '/music/.hidden_song.mp3',
          type: FileItemType.audio,
        ),
        makeItem(
          name: 'visible_song.mp3',
          path: '/music/visible_song.mp3',
          type: FileItemType.audio,
        ),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': true,
      });

      expect(result, hasLength(2));
    });

    // ── U-AUD-ISOLATE-06 ──
    test('skips hidden sub-files in folder count when showHidden is false',
        () {
      final subDir = Directory('${tempDir.path}/mixed_folder')
        ..createSync();
      File('${subDir.path}/.hidden.mp3').createSync();
      File('${subDir.path}/visible.mp3').createSync();

      final items = [
        makeItem(
          name: 'mixed_folder',
          path: subDir.path,
          type: FileItemType.folder,
        ),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': false,
      });

      expect(result, hasLength(1));
      expect(result[0].itemCount, 1);
    });

    // ── U-AUD-ISOLATE-07 ──
    test('counts hidden sub-files in folder count when showHidden is true',
        () {
      final subDir = Directory('${tempDir.path}/mixed_folder')
        ..createSync();
      File('${subDir.path}/.hidden.mp3').createSync();
      File('${subDir.path}/visible.mp3').createSync();

      final items = [
        makeItem(
          name: 'mixed_folder',
          path: subDir.path,
          type: FileItemType.folder,
        ),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': true,
      });

      expect(result, hasLength(1));
      expect(result[0].itemCount, 2);
    });

    // ── U-AUD-ISOLATE-08 ──
    test('returns empty list when all items are non-audio and non-folder', () {
      final items = [
        makeItem(
          name: 'clip.mp4',
          path: '/videos/clip.mp4',
          type: FileItemType.video,
        ),
        makeItem(
          name: 'photo.jpg',
          path: '/images/photo.jpg',
          type: FileItemType.image,
        ),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': true,
      });

      expect(result, isEmpty);
    });

    // ── U-AUD-ISOLATE-09 ──
    test('returns empty list when input items list is empty', () {
      final result = processAudioQueueIsolate({
        'items': <Map<String, dynamic>>[],
        'showHidden': true,
      });

      expect(result, isEmpty);
    });

    // ── U-AUD-ISOLATE-10 ──
    test('handles non-existent folder paths gracefully', () {
      final items = [
        makeItem(
          name: 'ghost_folder',
          path: '${tempDir.path}/this_does_not_exist',
          type: FileItemType.folder,
        ),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': true,
      });

      expect(result, isEmpty);
    });

    // ── U-AUD-ISOLATE-11 ──
    test('only scans one level deep (not recursive)', () {
      final parentDir = Directory('${tempDir.path}/parent_music')
        ..createSync();
      File('${parentDir.path}/top_level.mp3').createSync();

      final nestedDir = Directory('${parentDir.path}/nested')
        ..createSync();
      File('${nestedDir.path}/nested_track.mp3').createSync();

      final items = [
        makeItem(
          name: 'parent_music',
          path: parentDir.path,
          type: FileItemType.folder,
        ),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': true,
      });

      expect(result, hasLength(1));
      // Only top_level.mp3 should be counted — nested subfolder is not a File.
      expect(result[0].itemCount, 1);
    });

    // ── U-AUD-ISOLATE-12 ──
    test('preserves original order of audio items', () {
      final items = [
        makeItem(
          name: 'audio_c.mp3',
          path: '/music/audio_c.mp3',
          type: FileItemType.audio,
        ),
        makeItem(
          name: 'audio_a.mp3',
          path: '/music/audio_a.mp3',
          type: FileItemType.audio,
        ),
        makeItem(
          name: 'audio_b.mp3',
          path: '/music/audio_b.mp3',
          type: FileItemType.audio,
        ),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': true,
      });

      expect(result, hasLength(3));
      expect(result[0].name, 'audio_c.mp3');
      expect(result[1].name, 'audio_a.mp3');
      expect(result[2].name, 'audio_b.mp3');
    });

    // ── U-AUD-ISOLATE-13 ──
    test('correctly deserializes FileItem from JSON map', () {
      final now = DateTime(2026, 5, 24);
      final jsonItems = [
        {
          'path': '/music/from_json.mp3',
          'name': 'from_json.mp3',
          'type': FileItemType.audio.index,
          'modified': now.millisecondsSinceEpoch,
          'sizeBytes': 5000000,
          'thumbnailPath': null,
          'imageAspectRatio': null,
          'itemCount': null,
          'isExecutable': false,
          'hasWritePermission': true,
        },
      ];

      final result = processAudioQueueIsolate({
        'items': jsonItems,
        'showHidden': true,
      });

      expect(result, hasLength(1));
      expect(result[0].path, '/music/from_json.mp3');
      expect(result[0].name, 'from_json.mp3');
      expect(result[0].type, FileItemType.audio);
      expect(result[0].sizeBytes, 5000000);
    });

    // ── U-AUD-ISOLATE-14 ──
    test('handles folder containing mixed audio and non-audio files', () {
      final subDir = Directory('${tempDir.path}/mixed_media')
        ..createSync();
      File('${subDir.path}/track1.mp3').createSync();
      File('${subDir.path}/track2.flac').createSync();
      File('${subDir.path}/movie1.mp4').createSync();
      File('${subDir.path}/movie2.mkv').createSync();
      File('${subDir.path}/photo.jpg').createSync();

      final items = [
        makeItem(
          name: 'mixed_media',
          path: subDir.path,
          type: FileItemType.folder,
        ),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': true,
      });

      expect(result, hasLength(1));
      expect(result[0].itemCount, 2);
    });

    // ── U-AUD-ISOLATE-15 ──
    test('handles permission-denied folder gracefully', () {
      // Create a directory and remove read permissions.
      final restrictedDir = Directory('${tempDir.path}/restricted')
        ..createSync();
      File('${restrictedDir.path}/track.mp3').createSync();

      // Remove read permission (owner rx only → 0o000 = no access).
      Process.runSync('chmod', ['000', restrictedDir.path]);

      final items = [
        makeItem(
          name: 'restricted',
          path: restrictedDir.path,
          type: FileItemType.folder,
        ),
      ];

      final result = processAudioQueueIsolate({
        'items': items,
        'showHidden': true,
      });

      // The folder should be excluded (listSync throws), no crash.
      expect(result, isEmpty);

      // Restore permissions so tearDown can delete the directory.
      Process.runSync('chmod', ['755', restrictedDir.path]);
    });
  });
}
