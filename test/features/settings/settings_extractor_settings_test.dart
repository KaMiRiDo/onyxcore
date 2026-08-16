import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';

void main() {
  group('AppSettings Extractor Fields', () {
    test('has customExtractorsEnabled and extractorBrowser', () {
      const settings = AppSettings(
        customExtractorsEnabled: true,
        extractorBrowser: 'chrome',
      );
      
      expect(settings.customExtractorsEnabled, true);
      expect(settings.extractorBrowser, 'chrome');
    });

    test('copyWith supports new fields', () {
      const settings = AppSettings();
      
      final modified = settings.copyWith(
        customExtractorsEnabled: true,
        extractorBrowser: 'chrome',
      );
      
      expect(modified.customExtractorsEnabled, true);
      expect(modified.extractorBrowser, 'chrome');
    });

    test('props includes new fields', () {
      const settings = AppSettings(
        customExtractorsEnabled: true,
        extractorBrowser: 'chrome',
      );
      
      expect(settings.props.contains(true), true);
      expect(settings.props.contains('chrome'), true);
    });
  });
}
