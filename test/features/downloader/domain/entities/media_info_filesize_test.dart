import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';

void main() {
  group('MediaInfo & MediaFormat filesize extraction and fallback', () {
    test('extracts filesize from requested_formats sum when top-level filesize is null', () {
      final json = {
        'id': 'vid1',
        'title': 'Test Video',
        'originalUrl': 'https://youtube.com/watch?v=123',
        'requested_formats': [
          {'format_id': '137', 'filesize': 15 * 1024 * 1024, 'vcodec': 'avc1'},
          {'format_id': '140', 'filesize': 3 * 1024 * 1024, 'acodec': 'mp4a'},
        ],
      };

      final info = MediaInfo.fromJson(json);
      expect(info.filesize, equals(18 * 1024 * 1024));
    });

    test('extracts filesize from requested_downloads when available', () {
      final json = {
        'id': 'vid2',
        'title': 'Test Video 2',
        'originalUrl': 'https://youtube.com/watch?v=456',
        'requested_downloads': [
          {'filesize': 25 * 1024 * 1024},
        ],
      };

      final info = MediaInfo.fromJson(json);
      expect(info.filesize, equals(25 * 1024 * 1024));
    });

    test('estimates filesize from tbr and duration when filesize is null', () {
      final json = {
        'id': 'vid3',
        'title': 'Test Video 3',
        'originalUrl': 'https://youtube.com/watch?v=789',
        'duration': 120, // 2 minutes
        'tbr': 2000, // 2000 kbit/s => (2000 * 1000 / 8) * 120 = 30,000,000 bytes (~28.6 MB)
      };

      final info = MediaInfo.fromJson(json);
      expect(info.filesize, equals(30000000));
    });

    test('MediaFormat calculates filesize from tbr and duration if null', () {
      final formatJson = {
        'format_id': '1080p',
        'ext': 'mp4',
        'resolution': '1920x1080',
        'tbr': 1600.0,
        'duration': 60,
      };

      final format = MediaFormat.fromJson(formatJson);
      // (1600 * 1000 / 8) * 60 = 12,000,000 bytes
      expect(format.filesize, equals(12000000));
    });

    test('MediaInfo extracts filesize from first format if top-level filesize is null', () {
      final json = {
        'id': 'img1',
        'title': 'Test Image',
        'originalUrl': 'https://example.com/img.jpg',
        'formats': [
          {
            'format_id': 'original',
            'filesize': 450 * 1024,
            'ext': 'jpg',
          },
        ],
      };

      final info = MediaInfo.fromJson(json);
      expect(info.filesize, equals(450 * 1024));
    });
  });
}
