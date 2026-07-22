import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/image_viewer/utils/special_image_converter.dart';

void main() {
  group('SpecialImageConverter', () {
    test('returns null for non-special images', () async {
      final result = await SpecialImageConverter.convertIfNecessary('/test/image.jpg');
      expect(result, isNull);
    });

    // We skip actual conversion tests because they require native tools like heif-thumbnailer.
    // However, we verify that the method is available and structured properly.
  });
}
