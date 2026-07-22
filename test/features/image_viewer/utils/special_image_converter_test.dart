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
      final result = await SpecialImageConverter.convertIfNecessary('/test/image.jpg');
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
      // test_image.dng is generated such that package:image can decode it.
      final result = await SpecialImageConverter.convertIfNecessary(dngPath);
      expect(result, isNotNull);
      
      final file = File(result!);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
    });
    
    test('returns existing cached file immediately if it exists', () async {
      // Run once to cache
      final firstResult = await SpecialImageConverter.convertIfNecessary(heicPath);
      expect(firstResult, isNotNull);
      
      // Run again, should return immediately the same path
      final secondResult = await SpecialImageConverter.convertIfNecessary(heicPath);
      expect(secondResult, firstResult);
    });
  });
}
