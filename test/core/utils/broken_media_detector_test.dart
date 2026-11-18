import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/utils/broken_media_detector.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

class MockThumbnailCacheService extends Mock implements ThumbnailCacheService {}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('broken_media_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('BrokenMediaDetector - Non-existent & Empty files', () {
    test('does not flag non-existent mock path as broken media to prevent false positives', () {
      final missingPath = '${tempDir.path}/non_existent.jpg';
      expect(
        BrokenMediaDetector.isBrokenSync(missingPath, type: FileItemType.image),
        isFalse,
      );
    });

    test('returns true for 0-byte image file (.jpg)', () {
      final file = File('${tempDir.path}/empty.jpg')..createSync();
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.image),
        isTrue,
      );
    });

    test('returns true for 0-byte image file (.png)', () {
      final file = File('${tempDir.path}/empty.png')..createSync();
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.image),
        isTrue,
      );
    });

    test('returns true for 0-byte video file (.mp4)', () {
      final file = File('${tempDir.path}/empty.mp4')..createSync();
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.video),
        isTrue,
      );
    });

    test('returns true for 0-byte video file (.mkv)', () {
      final file = File('${tempDir.path}/empty.mkv')..createSync();
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.video),
        isTrue,
      );
    });
  });

  group('BrokenMediaDetector - Corrupted Image Detection', () {
    test('returns true for corrupted JPG with invalid header bytes', () {
      final file = File('${tempDir.path}/corrupt.jpg')
        ..writeAsBytesSync([0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77]);
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.image),
        isTrue,
      );
    });

    test('returns true for corrupted PNG with invalid signature', () {
      final file = File('${tempDir.path}/corrupt.png')
        ..writeAsBytesSync([0x89, 0x50, 0x00, 0x00, 0x0D, 0x0A, 0x1A, 0x0A]);
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.image),
        isTrue,
      );
    });

    test('returns true for corrupted GIF with invalid signature', () {
      final file = File('${tempDir.path}/corrupt.gif')
        ..writeAsStringSync('NOT_A_GIF_HEADER_DATA');
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.image),
        isTrue,
      );
    });

    test('returns true for corrupted SVG with no svg tags', () {
      final file = File('${tempDir.path}/corrupt.svg')
        ..writeAsStringSync('Plain text without xml or svg tags');
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.image),
        isTrue,
      );
    });
  });

  group('BrokenMediaDetector - Valid Image Detection (Never flag valid as broken)', () {
    test('returns false for valid 1x1 PNG', () {
      // Minimal valid 1x1 PNG
      final validPng = <int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ];
      final file = File('${tempDir.path}/valid.png')..writeAsBytesSync(validPng);
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.image),
        isFalse,
      );
    });

    test('returns false for valid minimal GIF', () {
      // Minimal valid 1x1 GIF
      final validGif = <int>[
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00,
        0x01, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00,
        0xFF, 0xFF, 0xFF, 0x21, 0xF9, 0x04, 0x01, 0x00,
        0x00, 0x00, 0x00, 0x2C, 0x00, 0x00, 0x00, 0x00,
        0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x01, 0x44,
        0x00, 0x3B,
      ];
      final file = File('${tempDir.path}/valid.gif')..writeAsBytesSync(validGif);
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.image),
        isFalse,
      );
    });

    test('returns false for valid SVG', () {
      const validSvg = '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10"/></svg>';
      final file = File('${tempDir.path}/valid.svg')..writeAsStringSync(validSvg);
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.image),
        isFalse,
      );
    });
  });

  group('BrokenMediaDetector - Corrupted Video Detection', () {
    test('returns true for corrupted MP4 with non-container bytes', () {
      final file = File('${tempDir.path}/corrupt.mp4')
        ..writeAsStringSync('Random text that is not a video file container');
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.video),
        isTrue,
      );
    });

    test('returns true for corrupted MKV without EBML header', () {
      final file = File('${tempDir.path}/corrupt.mkv')
        ..writeAsBytesSync([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]);
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.video),
        isTrue,
      );
    });

    test('returns true for MP4 file missing moov atom (ftyp + mdat only)', () {
      final mp4NoMoov = <int>[
        // ftyp box (24 bytes)
        0x00, 0x00, 0x00, 0x18,
        0x66, 0x74, 0x79, 0x70, // 'ftyp'
        0x69, 0x73, 0x6F, 0x6D, // 'isom'
        0x00, 0x00, 0x02, 0x00,
        0x69, 0x73, 0x6F, 0x6D,
        0x6D, 0x70, 0x34, 0x31,
        // mdat box (16 bytes)
        0x00, 0x00, 0x00, 0x10,
        0x6D, 0x64, 0x61, 0x74, // 'mdat'
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
      ];
      final file = File('${tempDir.path}/no_moov.mp4')..writeAsBytesSync(mp4NoMoov);
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.video),
        isTrue,
      );
    });
  });

  group('BrokenMediaDetector - Valid Video Container Detection (Never flag valid as broken)', () {
    test('returns false for valid MP4 with ftyp and moov container boxes', () {
      // Standard MP4 header with ftyp box + moov box
      final mp4Header = <int>[
        0x00, 0x00, 0x00, 0x18, // size: 24
        0x66, 0x74, 0x79, 0x70, // 'ftyp'
        0x69, 0x73, 0x6F, 0x6D, // major brand 'isom'
        0x00, 0x00, 0x02, 0x00, // minor version
        0x69, 0x73, 0x6F, 0x6D, // compatible brand 'isom'
        0x6D, 0x70, 0x34, 0x31, // compatible brand 'mp41'
        // moov box (16 bytes)
        0x00, 0x00, 0x00, 0x10,
        0x6D, 0x6F, 0x6F, 0x76, // 'moov'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ];
      final file = File('${tempDir.path}/valid.mp4')..writeAsBytesSync(mp4Header);
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.video),
        isFalse,
      );
    });

    test('returns false for valid MP4 with moov atom at tail following mdat', () {
      final mp4Tail = <int>[
        // ftyp box (24 bytes)
        0x00, 0x00, 0x00, 0x18,
        0x66, 0x74, 0x79, 0x70, // 'ftyp'
        0x69, 0x73, 0x6F, 0x6D,
        0x00, 0x00, 0x02, 0x00,
        0x69, 0x73, 0x6F, 0x6D,
        0x6D, 0x70, 0x34, 0x31,
        // mdat box (16 bytes)
        0x00, 0x00, 0x00, 0x10,
        0x6D, 0x64, 0x61, 0x74, // 'mdat'
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        // moov box at tail (16 bytes)
        0x00, 0x00, 0x00, 0x10,
        0x6D, 0x6F, 0x6F, 0x76, // 'moov'
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ];
      final file = File('${tempDir.path}/valid_tail.mp4')..writeAsBytesSync(mp4Tail);
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.video),
        isFalse,
      );
    });

    test('returns false for valid MKV EBML container header', () {
      // Standard Matroska EBML ID: 0x1A 0x45 0xDF 0xA3
      final mkvHeader = <int>[
        0x1A, 0x45, 0xDF, 0xA3, 0x9F, 0x42, 0x86, 0x81,
        0x01, 0x42, 0xF7, 0x81, 0x01, 0x42, 0xF2, 0x81,
        0x04, 0x42, 0xF3, 0x81, 0x08, 0x42, 0x82, 0x88,
        0x6D, 0x61, 0x74, 0x72, 0x6F, 0x73, 0x6B, 0x61,
      ];
      final file = File('${tempDir.path}/valid.mkv')..writeAsBytesSync(mkvHeader);
      expect(
        BrokenMediaDetector.isBrokenSync(file.path, type: FileItemType.video),
        isFalse,
      );
    });
  });

  group('BrokenMediaDetector - Cache Integration', () {
    test('returns true when ThumbnailCacheService lookup reports failed', () {
      final mockCache = MockThumbnailCacheService();
      final file = File('${tempDir.path}/cached_fail.jpg')..writeAsStringSync('valid_looking_bytes_here');
      when(
        () => mockCache.lookup(
          filePath: any(named: 'filePath'),
          mtime: any(named: 'mtime'),
          sizeBytes: any(named: 'sizeBytes'),
        ),
      ).thenReturn(ThumbnailLookupResult.failed);

      expect(
        BrokenMediaDetector.isBrokenSync(
          file.path,
          type: FileItemType.image,
          cacheService: mockCache,
        ),
        isTrue,
      );
    });
  });

  group('BrokenMediaDetector - Non-media files', () {
    test('does not flag normal documents or other files as broken media', () {
      final docFile = File('${tempDir.path}/notes.txt')..writeAsStringSync('hello world');
      expect(
        BrokenMediaDetector.isBrokenSync(docFile.path, type: FileItemType.document),
        isFalse,
      );
    });
  });
}
