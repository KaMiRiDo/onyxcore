import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:onyxcore/features/downloader/domain/entities/browser_capability.dart';

class BrowserInfo {
  const BrowserInfo({
    required this.id,
    required this.name,
    required this.capability,
  });
  final String id;
  final String name;
  final BrowserCapability capability;
}

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

  @visibleForTesting
  static void reset() {
    _cachedBrowsers = null;
    _cachedDefault = null;
  }

  /// Returns a list of supported browsers installed on the Linux system.
  static Future<List<String>> getInstalledBrowsers() async {
    if (_cachedBrowsers != null) return _cachedBrowsers!;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _cachedBrowsers = const ['google-chrome'];
      return _cachedBrowsers!;
    }

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
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _cachedDefault = 'google-chrome';
      return _cachedDefault;
    }
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

  /// Returns browsers capable of running custom extractors (Chromium-based only).
  static Future<List<BrowserInfo>> getExtractorBrowsers() async {
    final installed = await getInstalledBrowsers();
    final results = <BrowserInfo>[];
    
    for (final browser in installed) {
      var cap = BrowserCapability.other;
      if (browser.contains('chrome') || browser.contains('chromium') || browser.contains('brave') || browser.contains('edge') || browser.contains('vivaldi') || browser.contains('opera')) {
        cap = BrowserCapability.chromium;
      } else if (browser.contains('firefox')) {
        cap = BrowserCapability.firefox;
      }
      
      results.add(BrowserInfo(
        id: browser,
        name: _formatBrowserName(browser),
        capability: cap,
      ));
    }
    
    return results;
  }

  static String _formatBrowserName(String id) {
    switch (id) {
      case 'google-chrome': return 'Google Chrome';
      case 'chrome': return 'Chrome';
      case 'chromium': return 'Chromium';
      case 'brave':
      case 'brave-browser': return 'Brave';
      case 'vivaldi': return 'Vivaldi';
      case 'opera': return 'Opera';
      case 'edge':
      case 'microsoft-edge': return 'Microsoft Edge';
      case 'firefox': return 'Firefox';
      default: return id;
    }
  }
}
