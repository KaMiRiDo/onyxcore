import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/image_media_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ImageMediaStrategy', () {
    late Directory tempDir;
    late ImageMediaStrategy strategy;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('image_strategy_');
      strategy = ImageMediaStrategy();
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    ComparisonCandidate createCandidate(String name, FileItemType type) {
      final file = File(p.join(tempDir.path, name))..createSync();
      return ComparisonCandidate(
        file: FileItem(
          path: file.path,
          name: name,
          type: type,
          modified: DateTime.now(),
          sizeBytes: 100,
        ),
        isSource: true,
      );
    }

    test('supports only images', () {
      expect(
        strategy.supports(createCandidate('a.jpg', FileItemType.image)),
        isTrue,
      );
      expect(
        strategy.supports(createCandidate('v.mp4', FileItemType.video)),
        isFalse,
      );
    });

    test('extractMetadata reads image dimensions and normalizes', () async {
      final candidate = createCandidate('test.jpg', FileItemType.image);
      // Valid JPEG header for 1920x1080 (0x0438 height, 0x0780 width)
      final bytes = [
        0xFF,
        0xD8,
        0xFF,
        0xE0,
        0x00,
        0x10,
        0x4A,
        0x46,
        0x49,
        0x46,
        0x00,
        0x01,
        0x01,
        0x00,
        0x00,
        0x01,
        0x00,
        0x01,
        0x00,
        0x00,
        0xFF,
        0xC0,
        0x00,
        0x11,
        0x08,
        0x04,
        0x38,
        0x07,
        0x80,
        0x03,
        0x01,
        0x22,
        0x00,
        0x02,
        0x11,
        0x01,
        0x03,
        0x11,
        0x01,
        0xFF,
        0xD9,
      ];
      File(candidate.file.path).writeAsBytesSync(bytes);

      final meta = await strategy.extractMetadata(candidate);

      expect(meta.orientation, MediaOrientation.landscape);
      expect(meta.aspectRatioGroup, isNotNull);
    });
  });
}
