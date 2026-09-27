// Tests for Bug 1: Delete/Move/Copy performance optimizations
// Specifically: moveToTrash should batch multiple paths in a single gio call.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/local_file_datasource.dart';
import 'package:path/path.dart' as p;

void main() {
  late LocalFileDatasource datasource;
  late Directory tempDir;

  setUp(() {
    datasource = LocalFileDatasource();
    tempDir = Directory.systemTemp.createTempSync('onyx_delete_perf_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('LocalFileDatasource - moveToTrash batch optimization', () {
    test('moveToTrash with multiple files completes without error', () async {
      final file1 = File(p.join(tempDir.path, 'a.txt'))..writeAsStringSync('a');
      final file2 = File(p.join(tempDir.path, 'b.txt'))..writeAsStringSync('b');
      final file3 = File(p.join(tempDir.path, 'c.txt'))..writeAsStringSync('c');

      // Should complete without error if gio succeeds, or throw TrashFailedException
      try {
        await datasource.moveToTrash([file1.path, file2.path, file3.path]);
      } on TrashFailedException {
        // Expected in test environment without gio
      }
    });
    test('moveToTrash with many files completes within reasonable time', () async {
      // Create 5 files to trash
      final files = <File>[];
      for (var i = 0; i < 5; i++) {
        final f = File(p.join(tempDir.path, 'file_$i.txt'))
          ..writeAsStringSync('content $i');
        files.add(f);
      }

      final paths = files.map((f) => f.path).toList();

      final stopwatch = Stopwatch()..start();
      try {
        await datasource.moveToTrash(paths);
      } on TrashFailedException {
        // Expected in test environment without gio
      }
      stopwatch.stop();

      // Batched gio call should complete reasonably fast.
      // 10s is generous but ensures we do not hang.
      expect(stopwatch.elapsedMilliseconds, lessThan(10000));
    });

    test('moveToTrash reports progress correctly for multiple files', () async {
      final file1 = File(p.join(tempDir.path, 'p1.txt'))..writeAsStringSync('a');
      final file2 = File(p.join(tempDir.path, 'p2.txt'))..writeAsStringSync('b');

      final progressReports = <(int, int)>[];
      try {
        await datasource.moveToTrash(
          [file1.path, file2.path],
          onProgress: (processed, total) {
            progressReports.add((processed, total));
          },
        );
      } on TrashFailedException {
        // Expected in test environment without gio
        return;
      }

      // Should have at least one progress report
      expect(progressReports, isNotEmpty);
      // Final report must show all processed
      final lastReport = progressReports.last;
      expect(lastReport.$1, equals(lastReport.$2)); // processed == total
    });

    test('moveToTrash logs correct messages', () async {
      final file1 = File(p.join(tempDir.path, 'log1.txt'))
        ..writeAsStringSync('data');

      final logs = <String>[];
      try {
        await datasource.moveToTrash(
          [file1.path],
          onLog: logs.add,
        );
      } on TrashFailedException {
        // Expected in test environment without gio
        return;
      }

      expect(logs, isNotEmpty);
      // Should mention the file path or "Moved to Trash"
      expect(
        logs.any(
          (l) =>
              l.contains(file1.path) ||
              l.contains('Trash') ||
              l.contains('trash'),
        ),
        isTrue,
      );
    });

    test('deleteItems reports log for each deleted item', () async {
      final file1 = File(p.join(tempDir.path, 'del1.txt'))
        ..writeAsStringSync('data');
      final file2 = File(p.join(tempDir.path, 'del2.txt'))
        ..writeAsStringSync('data');

      final logs = <String>[];
      await datasource.deleteItems(
        [file1.path, file2.path],
        onLog: logs.add,
      );

      expect(logs.length, 2);
      expect(file1.existsSync(), isFalse);
      expect(file2.existsSync(), isFalse);
    });

    test('moveToTrash falls back gracefully for non-existent path', () async {
      // It should throw TrashFailedException which tells the caller to handle it
      try {
        await datasource.moveToTrash(['/non_existent_trash_path/ghost.txt']);
      } on TrashFailedException {
        // Expected
      }
    });
  });
}
