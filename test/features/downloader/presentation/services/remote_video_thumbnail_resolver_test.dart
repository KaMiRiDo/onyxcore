import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/presentation/services/remote_video_thumbnail_resolver.dart';

void main() {
  group('RemoteVideoThumbnailResolver Tests', () {
    setUp(() {
      RemoteVideoThumbnailResolver.reset();
    });

    test('getThumbnailPath returns null initially', () {
      expect(RemoteVideoThumbnailResolver.getThumbnailPath('http://test.com/video.mp4'), isNull);
    });

    test('cleanup clears cache entry and deletes temp file', () async {
      final url = 'http://test.com/video2.mp4';
      
      // We manually set a resolved path for testing
      final tempFile = File('${Directory.systemTemp.path}/test_thumb.jpg');
      await tempFile.writeAsString('fake_image_data');
      
      RemoteVideoThumbnailResolver.setPathForTesting(url, tempFile.path);
      
      expect(RemoteVideoThumbnailResolver.getThumbnailPath(url), tempFile.path);
      expect(tempFile.existsSync(), isTrue);
      
      await RemoteVideoThumbnailResolver.cleanup(url);
      
      expect(RemoteVideoThumbnailResolver.getThumbnailPath(url), isNull);
      expect(tempFile.existsSync(), isFalse);
    });
  });
}
