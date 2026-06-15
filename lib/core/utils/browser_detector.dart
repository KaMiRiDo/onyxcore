import 'dart:io';

class BrowserDetector {
  static const List<String> _knownBrowsers = [
    'firefox',
    'google-chrome',
    'chrome',
    'chromium',
    'brave',
    'brave-browser',
    'vivaldi',
    'opera',
    'edge',
    'microsoft-edge',
  ];

  static List<String>? _cachedBrowsers;
  static String? _cachedDefault;

  /// Returns a list of supported browsers installed on the Linux system.
  static Future<List<String>> getInstalledBrowsers() async {
    if (_cachedBrowsers != null) return _cachedBrowsers!;

    final installed = <String>{};

    for (final browser in _knownBrowsers) {
      try {
        final result = await Process.run('which', [browser]);
        if (result.exitCode == 0 &&
            result.stdout.toString().trim().isNotEmpty) {
          installed.add(browser);
        }
      } catch (_) {}
    }

    // Also check common Flatpak installations
    final flatpakBrowsers = {
      'org.mozilla.firefox': 'firefox',
      'com.google.Chrome': 'google-chrome',
      'org.chromium.Chromium': 'chromium',
      'com.brave.Browser': 'brave',
    };

    for (final entry in flatpakBrowsers.entries) {
      try {
        final result = await Process.run('flatpak', ['info', entry.key]);
        if (result.exitCode == 0) {
          installed.add(entry.value);
        }
      } catch (_) {}
    }

    _cachedBrowsers = installed.toList()..sort();
    return _cachedBrowsers!;
  }

  /// Attempts to find the system default browser.
  static Future<String?> getDefaultBrowser() async {
    if (_cachedDefault != null) return _cachedDefault;
    try {
      final result = await Process.run('xdg-settings', [
        'get',
        'default-web-browser',
      ]);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim().toLowerCase();

        for (final browser in _knownBrowsers) {
          if (output.contains(browser)) {
            _cachedDefault = browser;
            return browser;
          }
        }
      }
    } catch (_) {}

    return null;
  }
}
