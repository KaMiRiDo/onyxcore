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

  /// Returns a list of supported browsers installed on the Linux system.
  static List<String> getInstalledBrowsers() {
    final installed = <String>{};

    for (final browser in _knownBrowsers) {
      try {
        final result = Process.runSync('which', [browser]);
        if (result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty) {
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
        final result = Process.runSync('flatpak', ['info', entry.key]);
        if (result.exitCode == 0) {
          installed.add(entry.value);
        }
      } catch (_) {}
    }

    return installed.toList()..sort();
  }

  /// Attempts to find the system default browser.
  static String? getDefaultBrowser() {
    try {
      final result = Process.runSync('xdg-settings', ['get', 'default-web-browser']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim().toLowerCase();
        
        for (final browser in _knownBrowsers) {
          if (output.contains(browser)) {
            return browser;
          }
        }
      }
    } catch (_) {}
    
    return null;
  }
}
