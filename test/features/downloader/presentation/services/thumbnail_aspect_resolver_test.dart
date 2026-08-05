import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/presentation/services/thumbnail_aspect_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThumbnailAspectResolver', () {
    setUp(ThumbnailAspectResolver.reset);

    test('returns null for null, empty or unknown url', () {
      expect(ThumbnailAspectResolver.getSize(null), isNull);
      expect(ThumbnailAspectResolver.getSize(''), isNull);
      expect(ThumbnailAspectResolver.getSize('https://example.com/unknown.jpg'), isNull);
      expect(ThumbnailAspectResolver.getAspectRatio(null), isNull);
      expect(ThumbnailAspectResolver.getAspectRatio(''), isNull);
      expect(ThumbnailAspectResolver.getAspectRatio('https://example.com/unknown.jpg'), isNull);
    });

    test('caches and returns aspect ratio when size is known', () {
      const url = 'https://example.com/photo.jpg';
      ThumbnailAspectResolver.setSizeForTesting(url, const Size(800, 600));

      expect(ThumbnailAspectResolver.getSize(url), const Size(800, 600));
      expect(ThumbnailAspectResolver.getAspectRatio(url), closeTo(800 / 600, 0.001));
    });

    test('resets cached sizes', () {
      const url = 'https://example.com/photo.jpg';
      ThumbnailAspectResolver.setSizeForTesting(url, const Size(800, 600));
      expect(ThumbnailAspectResolver.getSize(url), isNotNull);

      ThumbnailAspectResolver.reset();
      expect(ThumbnailAspectResolver.getSize(url), isNull);
    });
  });
}
