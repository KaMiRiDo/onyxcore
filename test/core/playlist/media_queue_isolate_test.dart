import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/playlist/media_queue_isolate.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('media_queue_test_');
    
    // Create some test files
    File(p.join(tempDir.path, 'song.mp3')).createSync();
    File(p.join(tempDir.path, 'video.mp4')).createSync();
    File(p.join(tempDir.path, '.hidden_song.mp3')).createSync();
    File(p.join(tempDir.path, 'document.pdf')).createSync();
    
    // Create empty folder
    Directory(p.join(tempDir.path, 'EmptyFolder')).createSync();
    
    // Create folder with audio
    final audioFolder = Directory(p.join(tempDir.path, 'AudioFolder'))..createSync();
    File(p.join(audioFolder.path, 'track1.mp3')).createSync();
    File(p.join(audioFolder.path, 'track2.flac')).createSync();
    File(p.join(audioFolder.path, '.hidden_track.mp3')).createSync();
    File(p.join(audioFolder.path, 'image.jpg')).createSync();

    // Create folder with video
    final videoFolder = Directory(p.join(tempDir.path, 'VideoFolder'))..createSync();
    File(p.join(videoFolder.path, 'movie.mkv')).createSync();

    // Create hidden folder
    final hiddenFolder = Directory(p.join(tempDir.path, '.HiddenFolder'))..createSync();
    File(p.join(hiddenFolder.path, 'track3.mp3')).createSync();
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  List<Map<String, dynamic>> buildItemsJson() {
    return [
      FileItem(name: 'song.mp3', path: p.join(tempDir.path, 'song.mp3'), type: FileItemType.audio, modified: DateTime.now()).toJson(),
      FileItem(name: 'video.mp4', path: p.join(tempDir.path, 'video.mp4'), type: FileItemType.video, modified: DateTime.now()).toJson(),
      FileItem(name: '.hidden_song.mp3', path: p.join(tempDir.path, '.hidden_song.mp3'), type: FileItemType.audio, modified: DateTime.now()).toJson(),
      FileItem(name: 'document.pdf', path: p.join(tempDir.path, 'document.pdf'), type: FileItemType.other, modified: DateTime.now()).toJson(),
      FileItem(name: 'EmptyFolder', path: p.join(tempDir.path, 'EmptyFolder'), type: FileItemType.folder, modified: DateTime.now()).toJson(),
      FileItem(name: 'AudioFolder', path: p.join(tempDir.path, 'AudioFolder'), type: FileItemType.folder, modified: DateTime.now()).toJson(),
      FileItem(name: 'VideoFolder', path: p.join(tempDir.path, 'VideoFolder'), type: FileItemType.folder, modified: DateTime.now()).toJson(),
      FileItem(name: '.HiddenFolder', path: p.join(tempDir.path, '.HiddenFolder'), type: FileItemType.folder, modified: DateTime.now()).toJson(),
    ];
  }

  group('processMediaQueueIsolate', () {
    test('filters audio files and folders containing audio files (showHidden = false)', () {
      final args = {
        'items': buildItemsJson(),
        'showHidden': false,
        'targetType': FileItemType.audio.index,
      };

      final result = processMediaQueueIsolate(args);

      expect(result.length, 2);
      
      final songItem = result.firstWhere((e) => e.name == 'song.mp3');
      expect(songItem.type, FileItemType.audio);

      final audioFolderItem = result.firstWhere((e) => e.name == 'AudioFolder');
      expect(audioFolderItem.type, FileItemType.folder);
      // 'AudioFolder' has track1.mp3, track2.flac, .hidden_track.mp3, image.jpg
      // Since showHidden=false, it should count track1 and track2, so itemCount = 2.
      expect(audioFolderItem.itemCount, 2);
    });

    test('filters audio files and folders containing audio files (showHidden = true)', () {
      final args = {
        'items': buildItemsJson(),
        'showHidden': true,
        'targetType': FileItemType.audio.index,
      };

      final result = processMediaQueueIsolate(args);

      expect(result.length, 4);
      
      expect(result.any((e) => e.name == 'song.mp3'), isTrue);
      expect(result.any((e) => e.name == '.hidden_song.mp3'), isTrue);
      
      final audioFolderItem = result.firstWhere((e) => e.name == 'AudioFolder');
      // Should now count .hidden_track.mp3, so itemCount = 3.
      expect(audioFolderItem.itemCount, 3);

      final hiddenFolderItem = result.firstWhere((e) => e.name == '.HiddenFolder');
      expect(hiddenFolderItem.itemCount, 1);
    });

    test('filters video files and folders containing video files (showHidden = false)', () {
      final args = {
        'items': buildItemsJson(),
        'showHidden': false,
        'targetType': FileItemType.video.index,
      };

      final result = processMediaQueueIsolate(args);

      expect(result.length, 2);
      
      expect(result.any((e) => e.name == 'video.mp4'), isTrue);
      
      final videoFolderItem = result.firstWhere((e) => e.name == 'VideoFolder');
      expect(videoFolderItem.itemCount, 1);
    });
  });
}
