import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/image_viewer/utils/special_image_converter.dart';
import 'package:path/path.dart' as p;

void main() {
  group('SpecialImageConverter', () {
    late String heicPath;
    late String dngPath;

    setUpAll(() {
      final resourcesDir = Directory('test/features/image_viewer/resources');
      heicPath = p.join(resourcesDir.path, 'test_image.heic');
      dngPath = p.join(resourcesDir.path, 'test_image.dng');
    });

    test('returns null for non-special images', () async {
      final result = await SpecialImageConverter.convertIfNecessary(
        '/test/image.jpg',
      );
      expect(result, isNull);
    });

    test('converts heic using fallback ffmpeg', () async {
      // In the test environment without heif-thumbnailer, it falls back to ffmpeg.
      // test_image.heic is generated in a way that ffmpeg can process it.
      final result = await SpecialImageConverter.convertIfNecessary(heicPath);
      expect(result, isNotNull);

      final file = File(result!);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
    });

    test('converts dng using compute isolate', () async {
      final result = await SpecialImageConverter.convertIfNecessary(dngPath);
      expect(result, isNotNull);

      final file = File(result!);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
    });

    test('handles invalid dng gracefully', () async {
      final invalidDng = File(p.join(Directory.systemTemp.path, 'invalid.dng'))
        ..writeAsBytesSync([0x00, 0x01]); // Invalid image data
      
      final result = await SpecialImageConverter.convertIfNecessary(invalidDng.path);
      expect(result, isNull);
      
      invalidDng.deleteSync();
    });

    test('queues concurrent conversions', () async {
      // Create a copy of the heic file to ensure it's not cached from previous tests
      final concurrentHeic = File(p.join(Directory.systemTemp.path, 'concurrent.heic'));
      File(heicPath).copySync(concurrentHeic.path);
      
      final futures = [
        SpecialImageConverter.convertIfNecessary(concurrentHeic.path),
        SpecialImageConverter.convertIfNecessary(concurrentHeic.path),
      ];
      
      final results = await Future.wait(futures);
      
      expect(results[0], isNotNull);
      expect(results[1], results[0]);
      
      concurrentHeic.deleteSync();
    });

    test('returns existing cached file immediately if it exists', () async {
      final firstResult = await SpecialImageConverter.convertIfNecessary(heicPath);
      expect(firstResult, isNotNull);

      final secondResult = await SpecialImageConverter.convertIfNecessary(heicPath);
      expect(secondResult, firstResult);
    });

    test('handles non-existent heic gracefully', () async {
      final result = await SpecialImageConverter.convertIfNecessary('/nonexistent/file.heic');
      expect(result, isNull);
    });

    test('handles non-existent dng gracefully', () async {
      final result = await SpecialImageConverter.convertIfNecessary('/nonexistent/file.dng');
      expect(result, isNull);
    });

    test('continues conversion even if previous queued conversion failed', () async {
      final failedFuture = SpecialImageConverter.convertIfNecessary('/nonexistent/file.heic');
      final successFuture = SpecialImageConverter.convertIfNecessary(heicPath);

      final results = await Future.wait([failedFuture, successFuture]);
      expect(results[0], isNull);
      expect(results[1], isNotNull);
    });
  });
}
