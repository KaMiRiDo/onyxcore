import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';

void main() {
  group('AppSettings – filterSortEnabled fields', () {
    test('defaults to false', () {
      const settings = AppSettings();
      expect(settings.imageFilterSortEnabled, isFalse);
      expect(settings.videoFilterSortEnabled, isFalse);
      expect(settings.audioFilterSortEnabled, isFalse);
      expect(settings.documentFilterSortEnabled, isFalse);
    });

    test('copyWith preserves fields when not overridden', () {
      const settings = AppSettings(imageFilterSortEnabled: true, videoFilterSortEnabled: true);
      final updated = settings.copyWith(autoPlayNext: false);
      expect(updated.imageFilterSortEnabled, isTrue);
      expect(updated.videoFilterSortEnabled, isTrue);
      expect(updated.documentFilterSortEnabled, isFalse);
      expect(updated.audioFilterSortEnabled, isFalse);
    });

    test('copyWith updates fields', () {
      const settings = AppSettings();
      final updated = settings.copyWith(imageFilterSortEnabled: true);
      expect(updated.imageFilterSortEnabled, isTrue);
    });

    test('props includes fields for equality', () {
      const a = AppSettings(imageFilterSortEnabled: true);
      const b = AppSettings();
      expect(a, isNot(equals(b)));
    });

    test('identical instances are equal', () {
      const a = AppSettings(imageFilterSortEnabled: true);
      const b = AppSettings(imageFilterSortEnabled: true);
      expect(a, equals(b));
    });
  });
}
