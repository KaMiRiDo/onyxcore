import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/browser_capability.dart';

void main() {
  group('BrowserCapability classification tests', () {
    test('enum contains expected values', () {
      expect(BrowserCapability.values, contains(BrowserCapability.chromium));
      expect(BrowserCapability.values, contains(BrowserCapability.firefox));
      expect(BrowserCapability.values, contains(BrowserCapability.other));
      expect(BrowserCapability.values, contains(BrowserCapability.none));
    });
  });
}
