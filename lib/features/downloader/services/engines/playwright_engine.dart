import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:onyxcore/core/utils/process_utils.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/aria2_accelerator.dart';
import 'package:onyxcore/features/downloader/services/downloader_process_wrapper.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:path/path.dart' as p;

/// Concrete [DownloadEngine] implementation for Playwright (URL Interceptor).
///
/// Playwright uses the official Python library (`pip install playwright`) which
/// bundles a self-contained Playwright Driver binary — no Node.js required.
/// The browser binary (~300 MB) is downloaded via `playwright install chromium`.
///
/// **Architecture**: Two-phase pipeline (URL Interceptor, not full engine):
/// 1. Phase A — Playwright opens a headless Chromium browser, navigates to the
///    URL, intercepts network requests, filters for `.m3u8`/`.mp4`/`.ts` URLs.
/// 2. Phase B — The intercepted URL is passed to FFmpeg (for HLS → MP4 muxing)
///    or aria2c (for direct MP4 downloads).
///
/// **This is an optional engine.** Users can install/delete it from Settings.
/// ~300 MB storage for the Chromium browser binary.
class PlaywrightEngine extends DownloadEngine {
  @override
  String get id => 'playwright';

  @override
  String get displayName => 'Playwright';

  @override
  IconData get icon => Icons.web_rounded;

  @override
  Color get color => Colors.green;

  @override
  EngineType get engineType => EngineType.python;

  @override
  int get priority => 0; // Never auto-selected — manual only

  @override
  bool get isOptional => true;

  @override
  List<String> get systemDependencies => ['python3'];

  /// Path to the bundled Python interception script.
  @override
  String? get binaryPath => p.join(
    Platform.environment['HOME'] ?? '',
    '.local',
    'share',
    'onyxcore',
    'scripts',
    'intercept_media.py',
  );

  @override
  List<RegExp> get urlPatterns => [
    // Playwright matches nothing by default — it's always manual-only.
    // Users must explicitly select it from the engine dropdown.
  ];

  @override
  bool get isInstalled {
    // Only check the Chromium browser directory for fast synchronous evaluation.
    // Running python3 -c import synchronously blocks the UI thread heavily.
    final home = Platform.environment['HOME'] ?? '';
    final chromiumDir = Directory(p.join(home, '.cache', 'ms-playwright'));
    return chromiumDir.existsSync();
  }

  @override
  EngineUpdateInfo? get updateInfo => null; // User-managed install/delete

  @override
  Future<Process>? install() {
    // Install playwright Python package + Chromium browser binary
    return Process.start('bash', [
      '-c',
      'pip3 install playwright --break-system-packages && playwright install chromium',
    ]);
  }

  @override
  Future<Process>? uninstall() {
    // Remove Chromium browser + uninstall Python package to reclaim ~300 MB
    return Process.start('bash', [
      '-c',
      'python3 -m playwright uninstall --all && pip3 uninstall playwright -y --break-system-packages',
    ]);
  }

  @override
  Future<String?> getInstalledVersion() async {
    if (!isInstalled) return null;
    try {
      final res = await Process.run('playwright', ['--version']);
      if (res.exitCode == 0) {
        final out = (res.stdout as String).trim();
        // Version 1.43.0 -> 1.43.0
        final parts = out.split('Version ');
        if (parts.length > 1) return parts[1].trim();
        return out;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<String?> getLatestVersion() async {
    try {
      final res = await Process.run('curl', [
        '-s',
        'https://pypi.org/pypi/playwright/json',
      ]);
      if (res.exitCode == 0) {
        final json = jsonDecode(res.stdout as String);
        return json['info']?['version']?.toString();
      }
    } catch (_) {}
    return null;
  }

  /// Ensure the interception script exists on disk.
  Future<void> _ensureScript() async {
    final scriptFile = File(binaryPath!);
    if (!await scriptFile.exists()) {
      await scriptFile.parent.create(recursive: true);
    }
    await scriptFile.writeAsString(_interceptScript);
    debugPrint('[PlaywrightEngine] Wrote intercept script at: ${binaryPath!}');
  }

  @visibleForTesting
  Future<Process> startPythonProcess(String url) async {
    return Process.start('python3', [
      binaryPath!,
      url,
      '15000', // timeout ms
    ]);
  }

  @override
  Future<List<MediaInfo>> fetchMetadata({
    required String url,
    String? browser,
    bool fetchDeep = false,
    bool isPlaylist = false,
    void Function(MediaInfo info)? onProgress,
    void Function(int pid)? onProcessStarted,
  }) async {
    await _ensureScript();

    final process = await startPythonProcess(url);
    if (onProcessStarted != null) {
      onProcessStarted(process.pid);
    }

    final parsedInfos = <MediaInfo>[];

    Future<void> processOutput() async {
      final stderrBuffer = StringBuffer();
      final hydrationLogsBuffer = StringBuffer();
      process.stderr.transform(utf8.decoder).listen((data) {
        stderrBuffer.write(data);
        MediaDownloaderBackend.activeLogs[url] = stderrBuffer.toString();
      });

      if (onProgress != null) {
        onProgress(
          MediaInfo(
            id: 'hydration_loading',
            title: 'Fetching...',
            originalUrl: url,
            fetchLogs: 'Waiting for output...',
            isVideo: false,
          ),
        );
      }

      final rawOutput = await process.stdout.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;

      if (exitCode != 0 && rawOutput.trim().isEmpty) {
        final stderrStr = stderrBuffer.toString();
        throw Exception('Playwright interception failed: $stderrStr');
      }

      if (rawOutput.trim().isEmpty) {
        throw Exception('Playwright found no media URLs on this page');
      }

      var startIndex = rawOutput.indexOf('{');
      if (startIndex == -1) startIndex = rawOutput.indexOf('[');

      var endIndex = rawOutput.lastIndexOf('}');
      final bracketEnd = rawOutput.lastIndexOf(']');
      if (bracketEnd > endIndex) endIndex = bracketEnd;

      if (startIndex == -1 || endIndex == -1 || endIndex < startIndex) {
        throw Exception(
          'Could not parse Playwright output: valid JSON block not found',
        );
      }

      final jsonString = rawOutput.substring(startIndex, endIndex + 1);
      final decoded = jsonDecode(jsonString);

      var intercepted = <dynamic>[];
      String? thumbnailB64;

      if (decoded is List) {
        intercepted = decoded;
      } else if (decoded is Map<String, dynamic>) {
        intercepted = decoded['media'] as List<dynamic>? ?? [];
        thumbnailB64 = decoded['thumbnail'] as String?;
      }

      if (intercepted.isEmpty) {
        throw Exception('No media URLs were intercepted on this page');
      }

      final formats = <MediaFormat>[];
      for (var i = 0; i < intercepted.length; i++) {
        final item = intercepted[i] as Map<String, dynamic>;
        final mediaUrl = item['url']?.toString() ?? '';
        final contentType = item['type']?.toString() ?? '';
        final sizeStr = item['size']?.toString() ?? '0';

        if (mediaUrl.isEmpty) continue;

        // Determine media type and extension
        final isHls =
            mediaUrl.contains('.m3u8') || contentType.contains('mpegurl');
        final isTs = mediaUrl.contains('.ts');
        final isMp4 = mediaUrl.contains('.mp4') || contentType.contains('mp4');

        var ext = 'mp4';
        if (isHls) ext = 'ts';
        if (isTs) ext = 'ts';

        final sizeBytes = int.tryParse(sizeStr) ?? 0;
        final sizeText = sizeBytes > 0
            ? '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB'
            : '';
        var resName = isHls ? 'HLS Stream' : 'Resolution ${i + 1}';
        if (sizeText.isNotEmpty) {
          resName += ' ($sizeText)';
        }

        formats.add(
          MediaFormat(
            formatId: 'stream_$i',
            extension: ext,
            resolution: resName,
            formatString: mediaUrl,
          ),
        );
      }

      if (formats.isEmpty) {
        throw Exception('No valid media streams found');
      }

      final info = MediaInfo(
        id: url.hashCode.toString(),
        title: 'Intercepted Media',
        originalUrl: url,
        extractor: 'playwright',
        thumbnail: (thumbnailB64 != null && thumbnailB64.isNotEmpty)
            ? thumbnailB64
            : null,
        formats: formats,
      );

      hydrationLogsBuffer.writeln(
        'Successfully fetched metadata for: "${info.title}"\n',
      );
      var currentLogs = hydrationLogsBuffer.toString();
      if (stderrBuffer.isNotEmpty) {
        final formattedErrors = stderrBuffer
            .toString()
            .trim()
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .join('\n\n');
        currentLogs += '\n\n--- Playwright Raw Logs ---\n$formattedErrors';
      }
      final finalInfo = info.copyWith(fetchLogs: currentLogs.trim());

      parsedInfos.add(finalInfo);
      onProgress?.call(finalInfo);
    }

    try {
      await processOutput().timeout(const Duration(minutes: 10));
      return parsedInfos;
    } on TimeoutException {
      ProcessUtils.killProcessTreeSync(process.pid);
      if (parsedInfos.isEmpty) {
        throw Exception('Playwright page interception timed out');
      }
      throw PartialMetadataException(
        partialInfos: parsedInfos,
        message:
            'Hydration timed out after 10 minutes. Showing partial results.',
      );
    }
  }

  @override
  Future<Process> startDownload({
    required String url,
    required String destination,
    String? title,
    MediaFormat? format,
    bool audioOnly = false,
    bool mute = false,
    int? galleryIndex,
    bool isPlaylist = false,
    bool isProfile = false,
    String? browser,
    bool isZip = false,
    String? filterType,
    int? totalItems,
    String? singleItemId,
    String? directUrl,
  }) async {
    final safeTitle =
        title?.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_') ??
        'intercepted_${DateTime.now().millisecondsSinceEpoch}';

    // Determine the actual media URL (from format string)
    final mediaUrl = format?.formatString ?? url;

    if (mediaUrl.contains('.m3u8')) {
      // HLS → FFmpeg muxing
      return Process.start('ffmpeg', [
        '-i',
        mediaUrl,
        '-c',
        'copy',
        '-bsf:a',
        'aac_adtstoasc',
        '-y', // Overwrite
        p.join(destination, '$safeTitle.mp4'),
      ]);
    } else {
      // Direct URL → aria2c (always available as build dep)
      if (Aria2Accelerator.isAvailable) {
        return Aria2Accelerator.download(
          url: mediaUrl,
          destination: destination,
          filename: '$safeTitle.mp4',
        );
      }
      // Ultimate fallback: basic curl
      return Process.start('curl', [
        '-L',
        '-o',
        p.join(destination, '$safeTitle.mp4'),
        mediaUrl,
      ]);
    }
  }

  /// The bundled Python interception script.
  static const String _interceptScript = r'''
import sys
import json

def intercept(url, timeout=15000):
    """Intercept media URLs from a webpage using Playwright."""
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print(json.dumps([{"error": "playwright not installed"}]))
        sys.exit(1)

    media_urls = []

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent="Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0"
        )
        page = context.new_page()

        def handle_response(response):
            try:
                ct = response.headers.get("content-type", "")
                r_url = response.url
                if any(x in ct for x in ["mpegurl", "mp4", "video", "octet-stream"]) or \
                   any(x in r_url for x in [".m3u8", ".mp4", ".ts", ".webm"]):
                    # Skip tiny tracking pixels and analytics
                    cl = response.headers.get("content-length", "0")
                    if int(cl) > 10000 or cl == "0":
                        media_urls.append({
                            "url": r_url,
                            "type": ct,
                            "size": cl
                        })
            except Exception:
                pass

        page.on("response", handle_response)

        try:
            page.goto(url, wait_until="networkidle", timeout=timeout)
        except Exception:
            # Page may not fully load but we might have captured URLs
            pass

        # capture thumbnail
        thumb_b64 = ""
        try:
            img_bytes = page.screenshot(type="jpeg", quality=40)
            import base64
            thumb_b64 = "data:image/jpeg;base64," + base64.b64encode(img_bytes).decode("utf-8")
        except Exception:
            pass

        # Output as JSON to stdout for Dart to parse
        print(json.dumps({
            "thumbnail": thumb_b64,
            "media": media_urls
        }))
        browser.close()


if __name__ == "__main__":
    target_url = sys.argv[1] if len(sys.argv) > 1 else ""
    target_timeout = int(sys.argv[2]) if len(sys.argv) > 2 else 15000
    if not target_url:
        print(json.dumps({"thumbnail": "", "media": []}))
        sys.exit(1)
    intercept(target_url, target_timeout)
''';
}
