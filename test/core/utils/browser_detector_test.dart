import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/browser_detector.dart';

void main() {
  setUp(BrowserDetector.reset);

  group('BrowserDetector', () {
    test('getInstalledBrowsers returns a list of installed browsers and caches the result', () async {
      final browsers1 = await BrowserDetector.getInstalledBrowsers();
      expect(browsers1, isA<List<String>>());

      final browsers2 = await BrowserDetector.getInstalledBrowsers();
      // Verify identical list instance, confirming it was cached.
      expect(identical(browsers1, browsers2), isTrue);
    });

    test('getDefaultBrowser returns default browser or null, and caches the result', () async {
      final defaultBrowser1 = await BrowserDetector.getDefaultBrowser();
      expect(defaultBrowser1, anyOf(isNull, isA<String>()));

      final defaultBrowser2 = await BrowserDetector.getDefaultBrowser();
      expect(defaultBrowser1, defaultBrowser2);
    });
  });
}
