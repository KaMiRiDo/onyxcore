// TDD tests for DML file opening within OnyxCore file browser
// Behavior under test:
// - FileItemType.downloaderList is recognized for .dml files
// - classifyFileType for a .dml file returns FileItemType.downloaderList
// - file_grid.dart routes .dml double-taps to the downloader window
// - PersistentViewerManager has no broken D-Bus open_file handler
// - main.dart has no broken CLI-args pendingOpenFilePath logic

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

void main() {
  group('DML File Type Classification', () {
    test('classifyFileType returns downloaderList for .dml files', () {
      expect(classifyFileType('mylist.dml'), FileItemType.downloaderList);
      expect(classifyFileType('MYLIST.DML'), FileItemType.downloaderList);
      expect(classifyFileType('list.export.dml'), FileItemType.downloaderList);
    });

    test('classifyFileType does not affect other file types', () {
      expect(classifyFileType('image.jpg'), FileItemType.image);
      expect(classifyFileType('video.mp4'), FileItemType.video);
      expect(classifyFileType('audio.mp3'), FileItemType.audio);
      expect(classifyFileType('doc.pdf'), FileItemType.document);
      expect(classifyFileType('archive.zip'), FileItemType.archive);
      expect(classifyFileType('unknown.xyz'), FileItemType.other);
    });

    test('kDmlExtension constant is defined as .dml', () {
      expect(kDmlExtension, '.dml');
    });
  });

  group('FileGrid DML double-tap routing', () {
    test('.dml files are routed to downloader window with importListPath', () {
      final content = File(
        'lib/features/directory_browser/presentation/widgets/file_grid.dart',
      ).readAsStringSync();

      expect(
        content.contains('FileItemType.downloaderList'),
        isTrue,
        reason: 'file_grid must handle the downloaderList type',
      );
      expect(
        content.contains('ViewerType.downloader'),
        isTrue,
        reason: 'file_grid must route .dml files to the downloader window',
      );
      expect(
        content.contains("'importListPath'"),
        isTrue,
        reason: 'file_grid must pass importListPath init param',
      );
    });
  });

  group('StandaloneDownloaderWindow DML import', () {
    test('handles importListPath in both initState and didUpdateWidget', () {
      final content = File(
        'lib/features/downloader/presentation/pages/standalone_downloader_window.dart',
      ).readAsStringSync();

      // Must appear in initState (for cold-start: downloader window not yet open)
      expect(
        content.contains("widget.initParams['importListPath']"),
        isTrue,
        reason: 'importListPath must be read from initParams',
      );

      // Must appear in didUpdateWidget (for hot-path: downloader already open)
      expect(content.contains('didUpdateWidget'), isTrue);
      // Both initState and didUpdateWidget handle it — count occurrences
      final occurrences = 'importListPath'.allMatches(content).length;
      expect(
        occurrences,
        greaterThanOrEqualTo(4),
        reason: 'importListPath must be handled in both initState and didUpdateWidget',
      );
    });
  });

  group('Single-instance IPC code', () {
    test('PersistentViewerManager has open_file method channel handler', () {
      final content = File(
        'lib/core/window_management/persistent_viewer_manager.dart',
      ).readAsStringSync();

      expect(
        content.contains("'open_file'"),
        isTrue,
        reason: 'IPC open_file handler must be implemented',
      );
    });

    test('main.dart has no pendingOpenFilePath', () {
      final content = File('lib/main.dart').readAsStringSync();
      expect(
        content.contains('pendingOpenFilePath'),
        isFalse,
        reason: 'main.dart must not handle CLI args for DML files directly, it is handled via IPC',
      );
    });

    test('my_application.cc uses G_APPLICATION_HANDLES_COMMAND_LINE (single-instance)', () {
      final content = File(
        'linux/runner/my_application.cc',
      ).readAsStringSync();

      expect(
        content.contains('G_APPLICATION_HANDLES_COMMAND_LINE'),
        isTrue,
        reason: 'Native app must be HANDLES_COMMAND_LINE (single-instance D-Bus)',
      );
    });
  });
}
