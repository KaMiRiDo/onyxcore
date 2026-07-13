import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/media_uri_helper.dart';

void main() {
  group('MediaUriHelper.getSafeMediaUri', () {
    // ═══════════════════════════════════════════════════════════════
    // HTTP/HTTPS Network URL Passthrough
    // ═══════════════════════════════════════════════════════════════

    test('U-URI-01: returns https:// URL unchanged', () {
      const url = 'https://cdn.example.com/video.mp4';
      final result = MediaUriHelper.getSafeMediaUri(url);
      expect(result, url);
    });

    test('U-URI-02: returns http:// URL unchanged', () {
      const url = 'http://cdn.example.com/video.mp4';
      final result = MediaUriHelper.getSafeMediaUri(url);
      expect(result, url);
    });

    test('U-URI-03: returns rtmp:// URL unchanged', () {
      const url = 'rtmp://stream.example.com/live/stream';
      final result = MediaUriHelper.getSafeMediaUri(url);
      expect(result, url);
    });

    test('U-URI-04: returns rtsp:// URL unchanged', () {
      const url = 'rtsp://stream.example.com/video';
      final result = MediaUriHelper.getSafeMediaUri(url);
      expect(result, url);
    });

    test('U-URI-05: converts local unix path to file:// URI', () {
      const path = '/home/user/videos/file.mp4';
      final result = MediaUriHelper.getSafeMediaUri(path);
      expect(result, 'file:///home/user/videos/file.mp4');
    });

    test('U-URI-06: returns HLS m3u8 manifest URL unchanged', () {
      const url = 'https://cdn.example.com/hls/stream.m3u8';
      final result = MediaUriHelper.getSafeMediaUri(url);
      expect(result, url);
    });

    test('U-URI-07: returns https URL with query params unchanged', () {
      const url = 'https://cdn.example.com/v.mp4?token=abc123&expire=9999';
      final result = MediaUriHelper.getSafeMediaUri(url);
      expect(result, url);
    });
  });
}
