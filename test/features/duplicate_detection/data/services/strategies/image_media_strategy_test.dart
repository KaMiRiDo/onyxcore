import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/image_media_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_generator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/hamming_fingerprint_comparator.dart';
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

    group('Stage 2 Fingerprint Generation', () {
      test(
        'generate produces a valid 256-bit fingerprint for a valid image',
        () async {
          final imgObj = img.Image(width: 64, height: 64);
          for (var y = 0; y < 64; y++) {
            for (var x = 0; x < 64; x++) {
              imgObj.setPixelRgb(x, y, x * 4, y * 4, 128);
            }
          }
          final candidate = createCandidate('pattern.png', FileItemType.image);
          File(candidate.file.path).writeAsBytesSync(img.encodePng(imgObj));

          final fp = await strategy.generate(candidate);
          expect(fp.bytes.length, 32);
          expect(fp.candidatePath, candidate.file.path);
        },
      );

      test(
        'deterministic: repeated generation yields identical 256-bit bytes',
        () async {
          final imgObj = img.Image(width: 32, height: 32);
          for (var y = 0; y < 32; y++) {
            for (var x = 0; x < 32; x++) {
              imgObj.setPixelRgb(x, y, (x + y) * 4 % 255, 50, 100);
            }
          }
          final candidate = createCandidate('det.png', FileItemType.image);
          File(candidate.file.path).writeAsBytesSync(img.encodePng(imgObj));

          final fp1 = await strategy.generate(candidate);
          final fp2 = await strategy.generate(candidate);
          expect(fp1.bytes, equals(fp2.bytes));
        },
      );

      test(
        'resolution and format independence: high-res PNG and low-res JPG match',
        () async {
          // Create high-res 120x80 image with diagonal gradient
          final highRes = img.Image(width: 120, height: 80);
          for (var y = 0; y < 80; y++) {
            for (var x = 0; x < 120; x++) {
              highRes.setPixelRgb(x, y, (x * 2) % 255, (y * 3) % 255, 0);
            }
          }
          final highCandidate = createCandidate('high.png', FileItemType.image);
          File(
            highCandidate.file.path,
          ).writeAsBytesSync(img.encodePng(highRes));

          // Create low-res 60x40 image with same gradient, saved as JPG
          final lowRes = img.Image(width: 60, height: 40);
          for (var y = 0; y < 40; y++) {
            for (var x = 0; x < 60; x++) {
              lowRes.setPixelRgb(x, y, (x * 4) % 255, (y * 6) % 255, 0);
            }
          }
          final lowCandidate = createCandidate('low.jpg', FileItemType.image);
          File(lowCandidate.file.path).writeAsBytesSync(img.encodeJpg(lowRes));

          final fpHigher = await strategy.generate(highCandidate);
          final fpLower = await strategy.generate(lowCandidate);

          const comparator = HammingFingerprintComparator();
          final similarity = comparator.compare(fpHigher, fpLower);
          expect(similarity, greaterThanOrEqualTo(0.95));
        },
      );

      test(
        'distinct images yield low similarity (no false positive)',
        () async {
          final img1 = img.Image(width: 40, height: 40);
          final img2 = img.Image(width: 40, height: 40);
          for (var y = 0; y < 40; y++) {
            for (var x = 0; x < 40; x++) {
              img1.setPixelRgb(
                x,
                y,
                255 - (x * 6),
                0,
                0,
              ); // decreasing horizontal gradient
              img2.setPixelRgb(
                x,
                y,
                x * 6,
                0,
                0,
              ); // increasing horizontal gradient
            }
          }
          final cand1 = createCandidate('h1.png', FileItemType.image);
          final cand2 = createCandidate('h2.png', FileItemType.image);
          File(cand1.file.path).writeAsBytesSync(img.encodePng(img1));
          File(cand2.file.path).writeAsBytesSync(img.encodePng(img2));

          final fp1 = await strategy.generate(cand1);
          final fp2 = await strategy.generate(cand2);

          const comparator = HammingFingerprintComparator();
          final similarity = comparator.compare(fp1, fp2);
          expect(similarity, lessThan(0.80));
        },
      );

      test(
        'throws FingerprintGenerationException on corrupt or unreadable image',
        () async {
          final corruptCandidate = createCandidate(
            'bad.jpg',
            FileItemType.image,
          );
          File(
            corruptCandidate.file.path,
          ).writeAsStringSync('not an image data');

          expect(
            () => strategy.generate(corruptCandidate),
            throwsA(isA<FingerprintGenerationException>()),
          );
        },
      );
    });
  });
}
