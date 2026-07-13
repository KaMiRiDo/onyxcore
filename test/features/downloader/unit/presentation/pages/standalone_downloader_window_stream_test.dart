// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/pages/standalone_downloader_window.dart';

void main() {
  group('resolveStreamUrl — URL priority logic', () {
    // ═══════════════════════════════════════════════════════════════
    // Priority 1: directUrl
    // ═══════════════════════════════════════════════════════════════

    test('U-DL-STR-01: returns directUrl when it is set', () {
      const item = MediaInfo(
        id: '1',
        title: 'Video',
        originalUrl: 'https://youtube.com/watch?v=abc',
        directUrl: 'https://cdn.example.com/direct.mp4',
        webpageUrl: 'https://youtube.com/watch?v=abc',
      );
      expect(resolveStreamUrl(item), 'https://cdn.example.com/direct.mp4');
    });

    test('U-DL-STR-09: directUrl is returned first even for live streams', () {
      const item = MediaInfo(
        id: '1',
        title: 'Live',
        originalUrl: 'https://youtube.com/watch?v=live',
        directUrl: 'https://cdn.example.com/live.m3u8',
        isLive: true,
        formats: [
          MediaFormat(
            formatId: '91',
            extension: 'mp4',
            resolution: '360p',
            formatString: '91 - 360p',
            url: 'https://cdn.example.com/360p.mp4',
          ),
        ],
      );
      expect(resolveStreamUrl(item), 'https://cdn.example.com/live.m3u8');
    });

    // ═══════════════════════════════════════════════════════════════
    // Priority 2: best format URL
    // ═══════════════════════════════════════════════════════════════

    test('U-DL-STR-02: returns format url when directUrl is null', () {
      const item = MediaInfo(
        id: '1',
        title: 'Video',
        originalUrl: 'https://example.com/video',
        formats: [
          MediaFormat(
            formatId: '137',
            extension: 'mp4',
            resolution: '1920x1080',
            formatString: '137 - 1080p',
            url: 'https://cdn.example.com/1080p.mp4',
          ),
        ],
      );
      expect(resolveStreamUrl(item), 'https://cdn.example.com/1080p.mp4');
    });

    test('U-DL-STR-03: picks highest resolution format url when multiple formats exist', () {
      const item = MediaInfo(
        id: '1',
        title: 'Video',
        originalUrl: 'https://example.com/video',
        formats: [
          MediaFormat(
            formatId: '136',
            extension: 'mp4',
            resolution: '1280x720',
            formatString: '136 - 720p',
            url: 'https://cdn.example.com/720p.mp4',
          ),
          MediaFormat(
            formatId: '137',
            extension: 'mp4',
            resolution: '1920x1080',
            formatString: '137 - 1080p',
            url: 'https://cdn.example.com/1080p.mp4',
          ),
          MediaFormat(
            formatId: '140',
            extension: 'm4a',
            resolution: 'audio only',
            formatString: '140 - audio',
            url: 'https://cdn.example.com/audio.m4a',
          ),
        ],
      );
      // 1080p should win over 720p and audio-only
      expect(resolveStreamUrl(item), 'https://cdn.example.com/1080p.mp4');
    });

    test('U-DL-STR-07: empty-string directUrl falls through to format url', () {
      const item = MediaInfo(
        id: '1',
        title: 'Video',
        originalUrl: 'https://example.com/video',
        directUrl: '', // empty — should NOT be returned
        formats: [
          MediaFormat(
            formatId: '137',
            extension: 'mp4',
            resolution: '1920x1080',
            formatString: '137 - 1080p',
            url: 'https://cdn.example.com/fallback.mp4',
          ),
        ],
      );
      expect(resolveStreamUrl(item), 'https://cdn.example.com/fallback.mp4');
    });

    test('U-DL-STR-08: skips formats with null urls and picks the highest-res non-null url', () {
      const item = MediaInfo(
        id: '1',
        title: 'Video',
        originalUrl: 'https://example.com/video',
        formats: [
          MediaFormat(
            formatId: '248',
            extension: 'webm',
            resolution: '1920x1080',
            formatString: '248',
            // url is null — should be skipped
          ),
          MediaFormat(
            formatId: '244',
            extension: 'webm',
            resolution: '854x480',
            formatString: '244',
            url: 'https://cdn.example.com/480p.webm',
          ),
          MediaFormat(
            formatId: '247',
            extension: 'webm',
            resolution: '1280x720',
            formatString: '247',
            url: 'https://cdn.example.com/720p.webm',
          ),
        ],
      );
      // 1080p format has no url, 720p should win over 480p
      expect(resolveStreamUrl(item), 'https://cdn.example.com/720p.webm');
    });

    // ═══════════════════════════════════════════════════════════════
    // Priority 3: webpageUrl fallback
    // ═══════════════════════════════════════════════════════════════

    test('U-DL-STR-04: returns webpageUrl when directUrl is null and formats have no urls', () {
      const item = MediaInfo(
        id: '1',
        title: 'Video',
        originalUrl: 'https://example.com/video',
        webpageUrl: 'https://example.com/video-page',
        formats: [
          MediaFormat(
            formatId: '137',
            extension: 'mp4',
            resolution: '1920x1080',
            formatString: '137',
            // url is null
          ),
        ],
      );
      expect(resolveStreamUrl(item), 'https://example.com/video-page');
    });

    test('U-DL-STR-10: formats with all null urls + no directUrl → returns webpageUrl', () {
      const item = MediaInfo(
        id: '1',
        title: 'Video',
        originalUrl: 'https://example.com/original',
        webpageUrl: 'https://example.com/page',
        formats: [
          MediaFormat(formatId: 'a', extension: 'mp4', resolution: '1080p', formatString: 'a'),
          MediaFormat(formatId: 'b', extension: 'mp4', resolution: '720p', formatString: 'b'),
        ],
      );
      expect(resolveStreamUrl(item), 'https://example.com/page');
    });

    // ═══════════════════════════════════════════════════════════════
    // Priority 4: originalUrl last resort
    // ═══════════════════════════════════════════════════════════════

    test('U-DL-STR-05: returns originalUrl when all other fields are absent', () {
      const item = MediaInfo(
        id: '1',
        title: 'Video',
        originalUrl: 'https://example.com/original',
      );
      expect(resolveStreamUrl(item), 'https://example.com/original');
    });

    // ═══════════════════════════════════════════════════════════════
    // Edge: null / empty — returns null
    // ═══════════════════════════════════════════════════════════════

    test('U-DL-STR-06: returns null when all URL fields are empty or null', () {
      const item = MediaInfo(
        id: '1',
        title: 'Video',
        originalUrl: '', // empty
        directUrl: null,
        webpageUrl: null,
        formats: [],
      );
      expect(resolveStreamUrl(item), isNull);
    });

    // ═══════════════════════════════════════════════════════════════
    // gallery-dl pattern: CDN URL stored in formatString (not url)
    // ═══════════════════════════════════════════════════════════════

    test('U-DL-STR-11: picks formatString as URL for gallery-dl \"original\" format '
        'when format.url is null', () {
      // gallery-dl stores the CDN URL in formatString, not in url
      const item = MediaInfo(
        id: '1',
        title: 'Instagram Video',
        originalUrl: 'https://www.instagram.com/p/abc123/',
        formats: [
          MediaFormat(
            formatId: 'original',
            extension: 'mp4',
            resolution: 'original',
            formatString: 'https://cdninstagram.com/video/abc.mp4',
            // url is null — gallery-dl pattern
          ),
        ],
      );
      expect(
        resolveStreamUrl(item),
        'https://cdninstagram.com/video/abc.mp4',
      );
    });

    test('U-DL-STR-12: prefers format.url over formatString when both are present', () {
      const item = MediaInfo(
        id: '1',
        title: 'Video',
        originalUrl: 'https://example.com/video',
        formats: [
          MediaFormat(
            formatId: 'original',
            extension: 'mp4',
            resolution: 'original',
            formatString: 'https://cdn.example.com/via-formatstring.mp4',
            url: 'https://cdn.example.com/via-url-field.mp4',
          ),
        ],
      );
      // url field takes precedence over formatString
      expect(resolveStreamUrl(item), 'https://cdn.example.com/via-url-field.mp4');
    });
  });
}
