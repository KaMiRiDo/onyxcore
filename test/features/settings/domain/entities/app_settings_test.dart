import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';

void main() {
  group('AppSettings', () {
    test('supports value comparisons', () {
      const settings = AppSettings();
      expect(settings, const AppSettings());
    });

    test('copyWith updates openInStandaloneMode', () {
      const settings = AppSettings();
      final updated = settings.copyWith(openInStandaloneMode: false);
      expect(updated.openInStandaloneMode, isFalse);
    });

    test('openInStandaloneMode is true by default', () {
      const settings = AppSettings();
      expect(settings.openInStandaloneMode, isTrue);
    });
  });
}
