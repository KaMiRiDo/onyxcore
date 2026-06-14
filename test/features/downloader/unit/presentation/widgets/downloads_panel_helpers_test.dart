import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/downloads_panel.dart';

class DummyWidget extends StatefulWidget {
  const DummyWidget({super.key});
  @override
  State<DummyWidget> createState() => DummyWidgetState();
}

class DummyWidgetState extends State<DummyWidget> with DownloadsPanelHelpersMixin {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  late DummyWidgetState helper;

  setUp(() {
    helper = DummyWidgetState();
  });

  group('DownloadsPanelHelpers Mixin Unit Tests', () {
    group('String Trimming & Formatting', () {
      test('U-DL-HLP-01: Keep string as-is if shorter than maxLength', () {
        expect(helper.trimMiddleForTesting('Short', 10), 'Short');
      });

      test('U-DL-HLP-02: Add ellipsis in middle if longer than maxLength', () {
        expect(helper.trimMiddleForTesting('This is a very long string', 11), 'This...ring');
      });

      test('U-DL-HLP-03: Format seconds < 60', () {
        expect(helper.formatDurationForTesting(45), '0:45');
      });

      test('U-DL-HLP-04: Format minutes + seconds', () {
        expect(helper.formatDurationForTesting(135), '2:15');
      });

      test('U-DL-HLP-05: Format hours + minutes + seconds', () {
        expect(helper.formatDurationForTesting(3725), '1:02:05');
      });
    });

    group('Resolution & Height Parsing', () {
      test('U-DL-HLP-06: Return Unknown for empty string', () {
        expect(helper.formatResolutionForTesting(''), 'Unknown');
      });

      test('U-DL-HLP-07: Return Audio Only for audio', () {
        expect(helper.formatResolutionForTesting('audio'), 'Audio Only');
      });

      test('U-DL-HLP-08: Map dimensions to labels', () {
        expect(helper.formatResolutionForTesting('1920x1080'), '1080p');
      });

      test('U-DL-HLP-09: Map 1440+ to 1440p', () {
        expect(helper.formatResolutionForTesting('2560x1440'), '1440p');
      });

      test('U-DL-HLP-10: Map 2160+ to 4K', () {
        expect(helper.formatResolutionForTesting('3840x2160'), '4K');
      });

      test('U-DL-HLP-11: Extract height from WxH format', () {
        expect(helper.getHeightForTesting('1920x1080'), 1080);
      });

      test('U-DL-HLP-12: Extract height from plain numbers', () {
        expect(helper.getHeightForTesting('1080p'), 1080);
      });

      test('U-DL-HLP-13: Extract height from named formats', () {
        expect(helper.getHeightForTesting('4K'), 2160);
      });
    });

    group('Format Matching (matchTargetFormat)', () {
      late MediaInfo item;

      setUp(() {
        item = MediaInfo(
          id: 'test_item',
          title: 'Test Video',
          originalUrl: 'http://test',
          isVideo: true,
          formats: [
            MediaFormat(formatString: 'test', formatId: '1', resolution: '1920x1080', videoCodec: 'avc', audioCodec: 'aac', filesize: 50 * 1024 * 1024, extension: 'mp4'),
            MediaFormat(formatString: 'test', formatId: '2', resolution: '1920x1080', videoCodec: 'avc', audioCodec: 'none', filesize: 45 * 1024 * 1024, extension: 'mp4'),
            MediaFormat(formatString: 'test', formatId: '3', resolution: '1280x720', videoCodec: 'avc', audioCodec: 'aac', filesize: 25 * 1024 * 1024, extension: 'mp4'),
            MediaFormat(formatString: 'test', formatId: '4', resolution: 'audio only', videoCodec: 'none', audioCodec: 'aac', filesize: 5 * 1024 * 1024, extension: 'm4a'),
            MediaFormat(formatString: 'test', formatId: '5', resolution: '1920x1080', videoCodec: 'avc', audioCodec: 'aac', filesize: 60 * 1024 * 1024, extension: 'mp4'), // Larger 1080p
          ],
        );
      });

      test('U-DL-HLP-14: Return null if target is null', () {
        expect(helper.matchTargetFormat(item, null), isNull);
      });

      test('U-DL-HLP-15: Return null if item has no formats', () {
        item.formats.clear();
        expect(helper.matchTargetFormat(item, MediaFormat(formatString: 'test', formatId: '1', resolution: '1080p', extension: 'mp4')), isNull);
      });

      test('U-DL-HLP-16: Return exact match if available', () {
        final target = item.formats[2]; // 720p
        final matched = helper.matchTargetFormat(item, target);
        expect(matched, equals(target));
      });

      test('U-DL-HLP-17: Fallback to audio if target is audio only', () {
        final target = MediaFormat(formatString: 'test', formatId: 'unknown', resolution: 'audio only', extension: 'mp3');
        final matched = helper.matchTargetFormat(item, target);
        expect(matched?.formatId, '4');
      });

      test('U-DL-HLP-18: Fallback to video <= target height', () {
        final target = MediaFormat(formatString: 'test', formatId: 'unknown', resolution: '1080p', extension: 'mp4');
        final matched = helper.matchTargetFormat(item, target);
        // Should pick the best 1080p format without audio because it sorts by noAudio first
        expect(matched?.formatId, '2');
      });

      test('U-DL-HLP-19: Prefer video without embedded audio', () {
        final target = MediaFormat(formatString: 'test', formatId: 'unknown', resolution: '1080p', extension: 'mp4');
        final matched = helper.matchTargetFormat(item, target);
        expect(matched?.audioCodec, 'none');
      });

      test('U-DL-HLP-20: Tie-break equal heights by filesize', () {
        // Remove the audio=none option to force tie-break on filesize between format 1 (50MB) and 5 (60MB)
        item.formats.removeWhere((f) => f.audioCodec == 'none');
        final target = MediaFormat(formatString: 'test', formatId: 'unknown', resolution: '1080p', extension: 'mp4');
        final matched = helper.matchTargetFormat(item, target);
        expect(matched?.formatId, '5'); // The 60MB one
      });
    });

    group('File Size Calculation', () {
      late MediaInfo item;
      late DownloadConfig config;

      setUp(() {
        item = MediaInfo(
          id: 'test_item',
          title: 'Test Video',
          originalUrl: 'http://test',
          isVideo: true,
          directUrl: 'http://direct',
          formats: [
            MediaFormat(formatString: 'test', formatId: '1', resolution: '1920x1080', videoCodec: 'avc', audioCodec: 'none', filesize: 45 * 1024 * 1024, extension: 'mp4'),
            MediaFormat(formatString: 'test', formatId: '2', resolution: 'audio only', videoCodec: 'none', audioCodec: 'aac', filesize: 5 * 1024 * 1024, extension: 'm4a'),
          ],
        );
        config = DownloadConfig();
      });

      test('U-DL-HLP-21: Use format.filesize if available', () {
        final format = item.formats[0];
        expect(helper.getFormatBytesForTesting(item, format, config), 50 * 1024 * 1024);
      });

      test('U-DL-HLP-22: Use _resolvedFileSizes cache if available', () {
        final format = MediaFormat(formatString: 'test', formatId: 'unknown', resolution: '720p', extension: 'mp4', audioCodec: 'aac'); // no filesize
        helper.resolvedFileSizesForTesting['test_item'] = 200;
        expect(helper.getFormatBytesForTesting(item, format, config), 200);
      });

      test('U-DL-HLP-23: Trigger _fetchLazySize if URL present and cache miss', () {
        final format = MediaFormat(formatString: 'test', formatId: 'unknown', resolution: '720p', extension: 'mp4', audioCodec: 'aac'); // no filesize
        expect(helper.getFormatBytesForTesting(item, format, config), isNull);
        expect(helper.fetchingFileSizesForTesting.contains('test_item'), isTrue);
      });

      test('U-DL-HLP-24: Estimate combined size for video without audio', () {
        final format = item.formats[0]; // Video without audio
        // The helper should add the size of the best audio format
        final expected = 45 * 1024 * 1024 + 5 * 1024 * 1024;
        expect(helper.getFormatBytesForTesting(item, format, config), expected);
      });

      test('U-DL-HLP-25: Estimate size for audio-only mode', () {
        config.mode = DownloadMode.audioOnly;
        // The helper should find the best audio format and use its size
        final dummyFormat = MediaFormat(formatString: 'test', formatId: 'any', resolution: 'audio only', extension: 'm4a');
        expect(helper.getFormatBytesForTesting(item, dummyFormat, config), 5 * 1024 * 1024);
      });

      test('U-DL-HLP-26: _getFileSize formats valid bytes as string', () {
        config.format = MediaFormat(formatString: 'test', formatId: 'any', resolution: '1080p', extension: 'mp4');
        expect(helper.getFileSizeForTesting(item, config), '50.0 MB');
      });
    });

    group('Group Size Calculation', () {
      late DownloadConfig config;

      setUp(() {
        config = DownloadConfig();
      });

      test('U-DL-HLP-27: Ignore profiles and playlists in calculation', () {
        final group = MediaGroup(
          originalUrl: 'g', items: [
            MediaInfo(id: '1', title: '1', originalUrl: 'u1', isVideo: true, filesize: 10 * 1024 * 1024, formats: []),
            MediaInfo(id: '2', title: '2', originalUrl: 'u2', isProfile: true, formats: []),
            MediaInfo(id: '3', title: '3', originalUrl: 'u3', isPlaylist: true, formats: []),
          ]
        );
        expect(helper.getGroupBytesForTesting(group, config), 10 * 1024 * 1024);
      });

      test('U-DL-HLP-28: Respect config.groupFilter', () {
        config.groupFilter = GroupDownloadType.images;
        final group = MediaGroup(
          originalUrl: 'g', items: [
            MediaInfo(id: '1', title: '1', originalUrl: 'u1', isVideo: true, filesize: 10 * 1024 * 1024, formats: []),
            MediaInfo(id: '2', title: '2', originalUrl: 'u2', isVideo: false, filesize: 2 * 1024 * 1024, formats: []), // Image
          ]
        );
        expect(helper.getGroupBytesForTesting(group, config), 2 * 1024 * 1024);
      });

      test('U-DL-HLP-29: Estimate missing video sizes using average of known videos', () {
        final group = MediaGroup(
          originalUrl: 'g', items: [
            MediaInfo(id: '1', title: '1', originalUrl: 'u1', isVideo: true, filesize: 10 * 1024 * 1024, formats: []),
            MediaInfo(id: '2', title: '2', originalUrl: 'u2', isVideo: true, formats: []), // Missing size
          ]
        );
        // Average is 10MB, total is 20MB
        expect(helper.getGroupBytesForTesting(group, config), 20 * 1024 * 1024);
      });

      test('U-DL-HLP-30: Estimate missing image sizes using average of known images', () {
        final group = MediaGroup(
          originalUrl: 'g', items: [
            MediaInfo(id: '1', title: '1', originalUrl: 'u1', isVideo: false, filesize: 2 * 1024 * 1024, formats: []),
            MediaInfo(id: '2', title: '2', originalUrl: 'u2', isVideo: false, formats: []), // Missing size
          ]
        );
        // Average is 2MB, total is 4MB
        expect(helper.getGroupBytesForTesting(group, config), 4 * 1024 * 1024);
      });

      test('U-DL-HLP-31: Fallback to constants if no known sizes', () {
        final group = MediaGroup(
          originalUrl: 'g', items: [
            MediaInfo(id: '1', title: '1', originalUrl: 'u1', isVideo: true, formats: []),
            MediaInfo(id: '2', title: '2', originalUrl: 'u2', isVideo: false, formats: []),
          ]
        );
        // 1 video fallback = 15MB, 1 image fallback = 1MB. Total = 16MB
        expect(helper.getGroupBytesForTesting(group, config), 16 * 1024 * 1024);
      });
    });
  });
}
