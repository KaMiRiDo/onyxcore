import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/duplicate_detection/data/repositories/local_candidate_discovery_repository.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';
import 'package:path/path.dart' as p;

void main() {
  group('LocalCandidateDiscoveryRepository', () {
    late Directory tempDir;
    late LocalCandidateDiscoveryRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('discovery_test_');
      repository = LocalCandidateDiscoveryRepository();
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test(
      'discovers files only, not directories, respecting category filter',
      () async {
        // Create some files
        File(p.join(tempDir.path, 'image.jpg')).createSync();
        File(p.join(tempDir.path, 'video.mp4')).createSync();
        File(p.join(tempDir.path, 'doc.txt')).createSync();
        Directory(p.join(tempDir.path, 'subdir')).createSync();

        final stream = repository.discover(
          folderPath: tempDir.path,
          category: ComparisonCategory.images,
          recursive: false,
          isSource: true,
        );

        final candidates = await stream.toList();

        expect(candidates.length, 1);
        expect(candidates.first.file.name, 'image.jpg');
        expect(candidates.first.file.type, FileItemType.image);
        expect(candidates.first.isSource, isTrue);
      },
    );

    test('recurses into subdirectories when requested', () async {
      final subDir = Directory(p.join(tempDir.path, 'subdir'))..createSync();
      File(p.join(tempDir.path, 'image1.jpg')).createSync();
      File(p.join(subDir.path, 'image2.jpg')).createSync();

      final stream = repository.discover(
        folderPath: tempDir.path,
        category: ComparisonCategory.all,
        recursive: true,
        isSource: false,
      );

      final candidates = await stream.toList();
      expect(candidates.length, 2);
      expect(
        candidates.map((c) => c.file.name),
        containsAll(['image1.jpg', 'image2.jpg']),
      );
    });

    test('ignores symlinks', () async {
      if (!Platform.isLinux && !Platform.isMacOS) {
        return; // symlinks tricky on some systems without admin
      }
      final subDir = Directory(p.join(tempDir.path, 'subdir'))..createSync();
      File(p.join(subDir.path, 'image.jpg')).createSync();
      Link(p.join(tempDir.path, 'link_dir')).createSync(subDir.path);

      final stream = repository.discover(
        folderPath: tempDir.path,
        category: ComparisonCategory.all,
        recursive: true,
        isSource: true,
      );

      final candidates = await stream.toList();
      // Should find the image inside subdir once. The symlink should not be followed to yield it twice.
      expect(candidates.length, 1);
    });
  });
}
