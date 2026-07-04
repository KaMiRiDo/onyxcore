import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';

void main() {
  group('SortOption', () {
    test('label returns correct string for all options', () {
      expect(SortOption.aToZ.label, 'A-Z');
      expect(SortOption.zToA.label, 'Z-A');
      expect(SortOption.firstModified.label, 'First Modified');
      expect(SortOption.lastModified.label, 'Last Modified');
      expect(SortOption.sizeSmallToLarge.label, 'Size (Small to Large)');
      expect(SortOption.sizeLargeToSmall.label, 'Size (Large to Small)');
      expect(SortOption.filesFirst.label, 'Files First');
    });
  });

  group('SortSettings', () {
    test('default constructor uses aToZ', () {
      const settings = SortSettings();
      expect(settings.option, SortOption.aToZ);
    });

    test('supports value equality (Equatable)', () {
      const s1 = SortSettings(option: SortOption.zToA);
      const s2 = SortSettings(option: SortOption.zToA);
      const s3 = SortSettings(option: SortOption.lastModified);

      expect(s1, equals(s2));
      expect(s1, isNot(equals(s3)));
    });

    test('copyWith updates option correctly', () {
      const settings = SortSettings();
      final updated = settings.copyWith(option: SortOption.lastModified);

      expect(updated.option, SortOption.lastModified);
    });

    test('copyWith retains old option if null is passed', () {
      const settings = SortSettings(option: SortOption.filesFirst);
      final updated = settings.copyWith();

      expect(updated.option, SortOption.filesFirst);
    });

    test('toJson returns correct map', () {
      const settings = SortSettings(option: SortOption.firstModified);
      final json = settings.toJson();
      
      expect(json, {'option': 'firstModified'});
    });

    test('fromJson parses correctly', () {
      final json = {'option': 'sizeLargeToSmall'};
      final settings = SortSettings.fromJson(json);
      
      expect(settings.option, SortOption.sizeLargeToSmall);
    });

    test('fromJson falls back to aToZ for invalid option string', () {
      final json = {'option': 'invalidOptionName'};
      final settings = SortSettings.fromJson(json);
      
      expect(settings.option, SortOption.aToZ);
    });
  });
}
