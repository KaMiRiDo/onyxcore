import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/filter_settings.dart';

void main() {
  group('FilterSettings - Broken Items Filter', () {
    final validImage = FileItem(
      path: '/valid.jpg',
      name: 'valid.jpg',
      type: FileItemType.image,
      modified: DateTime(2023),
      sizeBytes: 1024,
    );

    final brokenImage = FileItem(
      path: '/broken.jpg',
      name: 'broken.jpg',
      type: FileItemType.image,
      modified: DateTime(2023),
      sizeBytes: 0,
      isBroken: true,
    );

    final validVideo = FileItem(
      path: '/valid.mp4',
      name: 'valid.mp4',
      type: FileItemType.video,
      modified: DateTime(2023),
      sizeBytes: 2048,
    );

    final brokenVideo = FileItem(
      path: '/broken.mp4',
      name: 'broken.mp4',
      type: FileItemType.video,
      modified: DateTime(2023),
      sizeBytes: 0,
      isBroken: true,
    );

    final folder = FileItem(
      path: '/folder',
      name: 'folder',
      type: FileItemType.folder,
      modified: DateTime(2023),
    );

    final allItems = [validImage, brokenImage, validVideo, brokenVideo, folder];

    test('isEmpty returns false when brokenOnly is true', () {
      const settings = FilterSettings(brokenOnly: true);
      expect(settings.isEmpty, isFalse);
    });

    test('supports value equality with brokenOnly', () {
      const s1 = FilterSettings(brokenOnly: true);
      const s2 = FilterSettings(brokenOnly: true);
      const s3 = FilterSettings();

      expect(s1, equals(s2));
      expect(s1, isNot(equals(s3)));
    });

    test('copyWith updates and clears brokenOnly', () {
      const s = FilterSettings();
      final updated = s.copyWith(brokenOnly: true);
      expect(updated.brokenOnly, isTrue);

      final cleared = updated.copyWith(clearBrokenOnly: true);
      expect(cleared.brokenOnly, isFalse);
      expect(cleared.isEmpty, isTrue);
    });

    test('apply() with brokenOnly = true filters out non-broken items and keeps broken items only', () {
      const filter = FilterSettings(brokenOnly: true);
      final filtered = filter.apply(allItems);

      expect(filtered, containsAll([brokenImage, brokenVideo]));
      expect(filtered, isNot(contains(validImage)));
      expect(filtered, isNot(contains(validVideo)));
      expect(filtered, isNot(contains(folder)));
      expect(filtered.length, equals(2));
    });

    test('apply() with brokenOnly = true and category = image returns only broken images', () {
      const filter = FilterSettings(
        brokenOnly: true,
        category: FileItemType.image,
      );
      final filtered = filter.apply(allItems);

      expect(filtered, equals([brokenImage]));
    });

    test('apply() with brokenOnly = true and category = video returns only broken videos', () {
      const filter = FilterSettings(
        brokenOnly: true,
        category: FileItemType.video,
      );
      final filtered = filter.apply(allItems);

      expect(filtered, equals([brokenVideo]));
    });
    test('apply() with brokenOnly = true detects corrupt MP4 on disk without moov atom even if item.isBroken is initially false', () async {
      final tempDir = await Directory.systemTemp.createTemp('broken_filter_test_');
      try {
        final corruptMp4File = File('${tempDir.path}/broken_stream.mp4')
          ..writeAsBytesSync([
            0x00, 0x00, 0x00, 0x18,
            0x66, 0x74, 0x79, 0x70, // 'ftyp'
            0x69, 0x73, 0x6F, 0x6D,
            0x00, 0x00, 0x02, 0x00,
            0x69, 0x73, 0x6F, 0x6D,
            0x6D, 0x70, 0x34, 0x31,
            // mdat box without moov
            0x00, 0x00, 0x00, 0x10,
            0x6D, 0x64, 0x61, 0x74,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
          ]);

        final corruptItem = FileItem(
          path: corruptMp4File.path,
          name: 'broken_stream.mp4',
          type: FileItemType.video,
          modified: DateTime.now(),
          sizeBytes: corruptMp4File.lengthSync(),
        );

        const filter = FilterSettings(brokenOnly: true);
        final filtered = filter.apply([corruptItem, validVideo]);

        expect(filtered.map((e) => e.path), contains(corruptItem.path));
        expect(filtered.map((e) => e.path), isNot(contains(validVideo.path)));
      } finally {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}
