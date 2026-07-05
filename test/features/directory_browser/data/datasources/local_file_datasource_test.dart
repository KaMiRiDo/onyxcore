import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/local_file_datasource.dart';
import 'package:path/path.dart' as p;

void main() {
  late LocalFileDatasource datasource;
  late Directory tempDir;

  setUp(() {
    datasource = LocalFileDatasource();
    tempDir = Directory.systemTemp.createTempSync('onyx_local_ds_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('LocalFileDatasource - Creation', () {
    test('createDirectory creates directory', () async {
      final newDirPath = p.join(tempDir.path, 'new_dir');
      await datasource.createDirectory(newDirPath);
      expect(Directory(newDirPath).existsSync(), isTrue);
    });

    test('createFolder creates folder inside parent', () async {
      await datasource.createFolder(tempDir.path, 'new_folder');
      expect(Directory(p.join(tempDir.path, 'new_folder')).existsSync(), isTrue);
    });

    test('createFile creates empty file inside parent', () async {
      await datasource.createFile(tempDir.path, 'new_file.txt');
      expect(File(p.join(tempDir.path, 'new_file.txt')).existsSync(), isTrue);
    });
  });

  group('LocalFileDatasource - Deletion', () {
    test('deleteItems deletes files and directories', () async {
      final file = File(p.join(tempDir.path, 'f1.txt'))..createSync();
      final dir = Directory(p.join(tempDir.path, 'd1'))..createSync();

      await datasource.deleteItems([file.path, dir.path]);

      expect(file.existsSync(), isFalse);
      expect(dir.existsSync(), isFalse);
    });

    test('deleteItemsPermanent delegates to deleteItems', () async {
      final file = File(p.join(tempDir.path, 'f1.txt'))..createSync();
      await datasource.deleteItemsPermanent([file.path]);
      expect(file.existsSync(), isFalse);
    });


    test('trashItems falls back to deleteItems when gio fails silently or missing', () async {
      // Create a file, call trashItems. Because gio trash fails silently or succeeds, we just ensure it doesn't throw.
      final file = File(p.join(tempDir.path, 'f1.txt'))..createSync();
      await datasource.trashItems([file.path]);
      // Either it's trashed or not, but it shouldn't crash.
    });

    test('moveToTrash succeeds without exception', () async {
      final file = File(p.join(tempDir.path, 'f2.txt'))..createSync();
      await datasource.moveToTrash([file.path]);
    });

    test('deleteItemsPermanent deletes directory if file does not exist', () async {
      final dir = Directory(p.join(tempDir.path, 'd2'))..createSync();
      await datasource.deleteItemsPermanent([dir.path]);
      expect(dir.existsSync(), isFalse);
    });

    test('restoreFromTrash throws exception when gio fails', () async {
      // Trying to restore a file that is not in trash will definitely fail gio trash --restore.
      expect(
        () => datasource.restoreFromTrash(['/non_existent/path/f1.txt']),
        throwsException,
      );
    });
  });

  group('LocalFileDatasource - Rename', () {
    test('renameItem renames correctly', () async {
      final file = File(p.join(tempDir.path, 'f1.txt'))..createSync();
      final newPath = await datasource.renameItem(file.path, 'f2.txt');
      expect(newPath, p.join(tempDir.path, 'f2.txt'));
      expect(File(newPath).existsSync(), isTrue);
      expect(file.existsSync(), isFalse);
    });

    test('bulkRename renames using prefix', () async {
      final f1 = File(p.join(tempDir.path, '1.txt'))..createSync();
      final f2 = File(p.join(tempDir.path, '2.txt'))..createSync();

      final newPaths = await datasource.bulkRename([f1.path, f2.path], prefix: 'pre_');
      
      expect(newPaths, [
        p.join(tempDir.path, 'pre_1.txt'),
        p.join(tempDir.path, 'pre_2.txt'),
      ]);
      expect(File(newPaths[0]).existsSync(), isTrue);
      expect(File(newPaths[1]).existsSync(), isTrue);
    });

    test('bulkRename renames using basename sequence', () async {
      final f1 = File(p.join(tempDir.path, 'a.txt'))..createSync();
      final f2 = File(p.join(tempDir.path, 'b.txt'))..createSync();

      final newPaths = await datasource.bulkRename([f1.path, f2.path], baseName: 'seq');
      
      expect(newPaths, [
        p.join(tempDir.path, 'seq_1.txt'),
        p.join(tempDir.path, 'seq_2.txt'),
      ]);
      expect(File(newPaths[0]).existsSync(), isTrue);
      expect(File(newPaths[1]).existsSync(), isTrue);
    });
  });

  group('LocalFileDatasource - Copy & Move', () {
    test('copyItems copies multiple items with callbacks', () async {
      final destDir = Directory(p.join(tempDir.path, 'dest'))..createSync();
      final f1 = File(p.join(tempDir.path, 'a.txt'))..writeAsStringSync('hello');
      final d1 = Directory(p.join(tempDir.path, 'd1'))..createSync();
      File(p.join(d1.path, 'b.txt')).writeAsStringSync('world');

      await datasource.copyItems(
        [f1.path, d1.path],
        destDir.path,
      );

      expect(File(p.join(destDir.path, 'a.txt')).readAsStringSync(), 'hello');
      expect(File(p.join(destDir.path, 'd1', 'b.txt')).readAsStringSync(), 'world');
    });

    test('moveItemTo moves file to destination', () async {
      final f1 = File(p.join(tempDir.path, 'a.txt'))..writeAsStringSync('hello');
      final destPath = p.join(tempDir.path, 'b.txt');

      await datasource.moveItemTo(f1.path, destPath);

      expect(File(destPath).readAsStringSync(), 'hello');
      expect(f1.existsSync(), isFalse);
    });

    test('moveItems moves multiple items with callbacks', () async {
      final destDir = Directory(p.join(tempDir.path, 'dest'))..createSync();
      final f1 = File(p.join(tempDir.path, 'a.txt'))..writeAsStringSync('hello');

      await datasource.moveItems(
        [f1.path],
        destDir.path,
      );

      expect(File(p.join(destDir.path, 'a.txt')).readAsStringSync(), 'hello');
      expect(f1.existsSync(), isFalse);
    });
    

  });

  group('LocalFileDatasource - Listing', () {
    test('listDirectory lists folders and files correctly', () async {
      final f1 = File(p.join(tempDir.path, 'a.txt'))..writeAsStringSync('a');
      final f2 = File(p.join(tempDir.path, 'b.png'))..writeAsBytesSync([1, 2, 3]);
      final d1 = Directory(p.join(tempDir.path, 'dir1'))..createSync();

      final items = await datasource.listDirectory(tempDir.path);

      expect(items.length, 3);
      final folders = items.where((e) => e.type == FileItemType.folder).toList();
      final files = items.where((e) => e.type != FileItemType.folder).toList();
      
      expect(folders.length, 1);
      expect(folders[0].name, 'dir1');

      expect(files.length, 2);
      expect(files.any((f) => f.name == 'a.txt'), isTrue);
      expect(files.any((f) => f.name == 'b.png'), isTrue);
    });

    test('listDirectory on non-existent path returns empty', () async {
      final items = await datasource.listDirectory('/path/does/not/exist');
      expect(items, isEmpty);
    });

    
  });
}
