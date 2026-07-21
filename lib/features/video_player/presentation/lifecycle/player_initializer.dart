import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

/// Configures an MPV [Player] instance before opening any media.
///
/// This is extracted from `_initPlayerAsync` in `_VideoPreviewWidgetState`
/// (originally lines 436–564 of `video_preview_widget.dart`).
///
/// **Invariants:**
/// - Called once per player lifetime, before `player.open(...)`.
/// - Does not call `setState`. All observable side-effects go through
///   the passed [player] object.
/// - Does not create the `Player` — the coordinator always does that.
class PlayerInitializer {
  const PlayerInitializer._();

  /// Applies all MPV property configuration (buffer, hwdec, cache, etc.).
  ///
  /// [player] — the freshly constructed `Player` to configure.
  /// [isNetworkStream] — `true` for IPTV / yt-dlp streams.
  /// [initParams] — the widget's `initParams` map (may be null).
  /// [ref] — Riverpod ref used only to read `settingsProvider` once.
  static Future<void> configure({
    required Player player,
    required bool isNetworkStream,
    required Map<String, dynamic>? initParams,
    required WidgetRef ref,
  }) async {
    if (player.platform == null) return;

    final dynamic platform = player.platform;

    if (isNetworkStream) {
      // ── yt-dlp / network stream configuration ────────────────────────
      final selectedFormatId = initParams?['selectedFormatId'] as String?;
      if (selectedFormatId != null) {
        platform.setProperty(
          'ytdl-format',
          '$selectedFormatId+bestaudio/best',
        );
      } else {
        platform.setProperty('ytdl-format', 'bestvideo+bestaudio/best');
      }

      final audioUrl = initParams?['audioUrl'] as String?;
      if (audioUrl != null && audioUrl.isNotEmpty) {
        platform.setProperty('audio-file', audioUrl);
      }

      final ytDlpPath = p.join(
        Platform.environment['HOME'] ?? '',
        '.local',
        'share',
        'onyxcore',
        'yt-dlp-venv',
        'bin',
        'yt-dlp',
      );
      if (File(ytDlpPath).existsSync()) {
        platform.setProperty('script-opts', 'ytdl_hook-ytdl_path=$ytDlpPath');
      }

      // Setup cache directory
      try {
        final tempDir = await getTemporaryDirectory();
        final cacheDir = Directory(p.join(tempDir.path, 'onyx_stream_cache'));
        if (!cacheDir.existsSync()) {
          cacheDir.createSync(recursive: true);
        }
        platform.setProperty('cache-dir', cacheDir.path);
        platform.setProperty('cache-on-disk', 'yes');
      } catch (e) {
        debugPrint('Failed to set up stream cache directory: $e');
      }

      // Network Streaming Buffer Configuration
      platform.setProperty(
        'demuxer-readahead-secs',
        '120',
      ); // 2 minutes read-ahead
      platform.setProperty(
        'demuxer-max-bytes',
        '524288000',
      ); // 500 MB forward buffer
      platform.setProperty(
        'demuxer-max-back-bytes',
        '134217728',
      ); // 128 MB backward
      platform.setProperty('buffer-size', '134217728'); // 128 MB internal
      platform.setProperty('cache', 'yes');
      platform.setProperty('cache-secs', '120');
      platform.setProperty('cache-pause', 'yes'); // Pause to build cache
      platform.setProperty(
        'cache-pause-wait',
        '2',
      ); // Wait 2 secs before unpausing
    } else {
      // ── Local File Sliding Window Buffer Configuration ────────────────
      // 400 MiB forward + 200 MiB backward for zero-latency arrow-key seeks
      platform.setProperty('demuxer-readahead-secs', '60');
      platform.setProperty(
        'demuxer-max-bytes',
        '419430400',
      ); // 400 MiB forward
      platform.setProperty(
        'demuxer-max-back-bytes',
        '209715200',
      ); // 200 MiB backward
      platform.setProperty('buffer-size', '134217728'); // 128 MB internal
      platform.setProperty('cache', 'yes');
      platform.setProperty('cache-secs', '60');
      platform.setProperty('cache-pause', 'no');
    }

    // ── Seek and decode settings ──────────────────────────────────────
    platform.setProperty('hr-seek', 'yes'); // Exact seeking
    platform.setProperty('hr-seek-framedrop', 'yes');
    platform.setProperty('vd-lavc-fast', 'yes');

    // FIX: Prevent mp_image_crop assertion crash on systems where EGL is
    // invalid and media_kit falls back to S/W rendering. In that code path,
    // mpv's direct-rendering mode tries to crop a decoded frame onto a
    // not-yet-resized texture surface (1×1 or small default), causing:
    //   Assertion `x1 <= img->w && y1 <= img->h' failed.
    // Disabling direct rendering (`vd-lavc-dr=no`) forces mpv to copy
    // decoded frames into a properly sized buffer instead of rendering
    // directly onto the texture. Also disable early GL flushes to avoid
    // premature buffer commits during resize transitions.
    platform.setProperty('vd-lavc-dr', 'no');
    platform.setProperty('opengl-early-flush', 'no');

    // ── EPX-008: Hardware Decoder Auto-Cache Logic ────────────────────
    final settings = ref.read(settingsProvider).value;
    if (settings != null) {
      if (settings.selectedHwDec == 'auto') {
        if (settings.cachedResolvedHwDec != null) {
          debugPrint(
            '[VideoPlayer] Using cached hardware decoder: ${settings.cachedResolvedHwDec}',
          );
          platform.setProperty('hwdec', settings.cachedResolvedHwDec!);
        } else {
          debugPrint('[VideoPlayer] No cached decoder, using fallback chain');
          platform.setProperty('hwdec', 'vaapi,nvdec,vdpau,auto-safe');
        }
      } else {
        debugPrint(
          '[VideoPlayer] Using manually selected hardware decoder: ${settings.selectedHwDec}',
        );
        platform.setProperty('hwdec', settings.selectedHwDec);
      }
    } else {
      platform.setProperty('hwdec', 'auto-safe');
    }

    // ── Volume persistence ────────────────────────────────────────────
    if (settings != null) {
      player.setVolume(settings.videoPlayerVolume);
    }
  }
}
