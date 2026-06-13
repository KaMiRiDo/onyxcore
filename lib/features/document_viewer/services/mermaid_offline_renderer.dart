import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:onyxcore/core/utils/browser_detector.dart';

class MermaidOfflineRenderer {
  static final Map<String, Uint8List> _memoryCache = {};
  static bool isTestMode = false;

  static Future<Uint8List?> renderToPng(String mermaidCode, {bool isDarkMode = true}) async {
    if (isTestMode) {
      return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 252, 255, 255, 63, 3, 0, 6, 9, 2, 213, 167, 122, 61, 36, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]);
    }

    // 1. Check Memory Cache
    final cacheKey = md5.convert(utf8.encode(mermaidCode + isDarkMode.toString())).toString();
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    // 2. Check Disk Cache
    final tempDir = await getTemporaryDirectory();
    final cacheDir = Directory(p.join(tempDir.path, 'mermaid_cache'));
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }

    final cachedFile = File(p.join(cacheDir.path, '$cacheKey.png'));
    if (cachedFile.existsSync()) {
      final bytes = await cachedFile.readAsBytes();
      _memoryCache[cacheKey] = bytes;
      return bytes;
    }

    // 3. Find Chrome/Chromium
    final browsers = await BrowserDetector.getInstalledBrowsers();
    String? chromePath;
    for (final b in browsers) {
      if (b.contains('chrome') || b.contains('chromium') || b.contains('brave') || b.contains('edge')) {
        final res = await Process.run('which', [b]);
        if (res.exitCode == 0) {
          chromePath = res.stdout.toString().trim();
          break;
        }
      }
    }

    if (chromePath == null || chromePath.isEmpty) {
      debugPrint('MermaidOfflineRenderer: No Chromium browser found.');
      return null;
    }

    // 4. Prepare files for deno
    final mmdFile = File(p.join(cacheDir.path, '$cacheKey.mmd'));
    await mmdFile.writeAsString(mermaidCode);

    final puppeteerConfig = File(p.join(cacheDir.path, 'puppeteer-config.json'));
    await puppeteerConfig.writeAsString(jsonEncode({
      "executablePath": chromePath,
      "args": ["--no-sandbox", "--disable-setuid-sandbox"]
    }));

    final outputFile = File(p.join(cacheDir.path, '$cacheKey.png'));

    // 5. Run mermaid-cli via Deno
    // -s 4 ensures high resolution so it's not blurry
    final bgColor = isDarkMode ? 'transparent' : 'transparent';
    final result = await Process.run('deno', [
      'run',
      '-A',
      'npm:@mermaid-js/mermaid-cli@10.6.1',
      '-i', mmdFile.path,
      '-o', outputFile.path,
      '-b', bgColor,
      '-s', '4',
      '-p', puppeteerConfig.path
    ]);

    // 6. Cleanup temp config
    if (mmdFile.existsSync()) mmdFile.deleteSync();
    if (puppeteerConfig.existsSync()) puppeteerConfig.deleteSync();

    if (result.exitCode != 0 || !outputFile.existsSync()) {
      debugPrint('MermaidOfflineRenderer error: ${result.stderr}');
      return null;
    }

    // 7. Read, cache and return
    final bytes = await outputFile.readAsBytes();
    _memoryCache[cacheKey] = bytes;
    return bytes;
  }
}
