import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';

void main() {
  group('DownloadConfig Entity Tests', () {
    // ═══════════════════════════════════════════════════════════════
    // 1. DownloadMode Enum
    // ═══════════════════════════════════════════════════════════════
    group('DownloadMode Enum', () {
      test('U-DL-CFG-01: contains exactly 3 values', () {
        expect(DownloadMode.values.length, 3);
        expect(DownloadMode.values, containsAllInOrder([
          DownloadMode.normal,
          DownloadMode.mute,
          DownloadMode.audioOnly,
        ]));
      });

      test('U-DL-CFG-02: resolves by index', () {
        expect(DownloadMode.values[2], DownloadMode.audioOnly);
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 2. GroupDownloadType Enum
    // ═══════════════════════════════════════════════════════════════
    group('GroupDownloadType Enum', () {
      test('U-DL-CFG-03: contains exactly 3 values', () {
        expect(GroupDownloadType.values.length, 3);
        expect(GroupDownloadType.values, containsAllInOrder([
          GroupDownloadType.all,
          GroupDownloadType.images,
          GroupDownloadType.videos,
        ]));
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 3. Constructor & Default Values
    // ═══════════════════════════════════════════════════════════════
    group('Constructor & Default Values', () {
      test('U-DL-CFG-04: creates with all defaults', () {
        final config = DownloadConfig();
        expect(config.format, isNull);
        expect(config.mode, DownloadMode.normal);
        expect(config.groupFilter, GroupDownloadType.all);
        expect(config.engine, 'auto');
        expect(config.itemFormats, isEmpty);
      });

      test('U-DL-CFG-05: creates with explicit values', () {
        const format = MediaFormat(
          formatId: '123',
          extension: 'mp4',
          resolution: '1080p',
          formatString: 'best',
        );

        final config = DownloadConfig(
          format: format,
          mode: DownloadMode.mute,
          groupFilter: GroupDownloadType.videos,
          engine: 'yt-dlp',
          itemFormats: {'id1': format},
        );

        expect(config.format, format);
        expect(config.mode, DownloadMode.mute);
        expect(config.groupFilter, GroupDownloadType.videos);
        expect(config.engine, 'yt-dlp');
        expect(config.itemFormats, {'id1': format});
      });

      test('U-DL-CFG-06: initializes itemFormats to empty map when null', () {
        final config = DownloadConfig(itemFormats: null);
        expect(config.itemFormats, isNotNull);
        expect(config.itemFormats, isEmpty);
      });

      test('U-DL-CFG-07: preserves explicit itemFormats map', () {
        final config = DownloadConfig(itemFormats: {
          '1': null,
          '2': null,
          '3': null,
        });
        expect(config.itemFormats.length, 3);
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 4. Field Mutability
    // ═══════════════════════════════════════════════════════════════
    group('Field Mutability', () {
      late DownloadConfig config;

      setUp(() {
        config = DownloadConfig();
      });

      test('U-DL-CFG-08: allows mutation of format field', () {
        expect(config.format, isNull);
        const newFormat = MediaFormat(
          formatId: '123',
          extension: 'mp4',
          resolution: '1080p',
          formatString: '123',
        );
        config.format = newFormat;
        expect(config.format, newFormat);
      });

      test('U-DL-CFG-09: allows mutation of mode field', () {
        expect(config.mode, DownloadMode.normal);
        config.mode = DownloadMode.audioOnly;
        expect(config.mode, DownloadMode.audioOnly);
      });

      test('U-DL-CFG-10: allows mutation of groupFilter field', () {
        expect(config.groupFilter, GroupDownloadType.all);
        config.groupFilter = GroupDownloadType.videos;
        expect(config.groupFilter, GroupDownloadType.videos);
      });

      test('U-DL-CFG-11: allows mutation of engine field', () {
        expect(config.engine, 'auto');
        config.engine = 'gallery-dl';
        expect(config.engine, 'gallery-dl');
      });

      test('U-DL-CFG-12: allows adding entries to itemFormats map', () {
        expect(config.itemFormats, isEmpty);
        config.itemFormats['id1'] = null;
        expect(config.itemFormats.length, 1);
        expect(config.itemFormats.containsKey('id1'), isTrue);
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 5. Engine Snapshot Comment Behavior
    // ═══════════════════════════════════════════════════════════════
    group('Engine Snapshot', () {
      test('U-DL-CFG-13: defaults to auto for engine-agnostic fetch', () {
        final config = DownloadConfig();
        expect(config.engine, 'auto');
      });

      test('U-DL-CFG-14: captures specific engine at fetch time', () {
        final config = DownloadConfig(engine: 'yt-dlp');
        expect(config.engine, 'yt-dlp');
      });
    });
  });
}
