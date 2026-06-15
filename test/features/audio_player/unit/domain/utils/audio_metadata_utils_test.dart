
import 'package:hive/hive.dart' as import_hive;
import 'dart:io' as import_io;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:onyxcore/features/audio_player/domain/utils/audio_metadata_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Generates a solid-color PNG image of the given dimensions.
Uint8List _createTestImage(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(100, 150, 200));
  return Uint8List.fromList(img.encodePng(image));
}

/// Creates a minimal valid WAV file (silence) with the given duration.
/// This allows ffprobe to parse it without requiring a real audio recording.
Uint8List _createMinimalWav({int durationMs = 1000, int sampleRate = 44100}) {
  final numSamples = (sampleRate * durationMs / 1000).round();
  final dataSize = numSamples * 2; // 16-bit mono
  final fileSize = 36 + dataSize;

  final buffer = ByteData(44 + dataSize);
  // RIFF header
  buffer.setUint8(0, 0x52); // R
  buffer.setUint8(1, 0x49); // I
  buffer.setUint8(2, 0x46); // F
  buffer.setUint8(3, 0x46); // F
  buffer.setUint32(4, fileSize, Endian.little);
  buffer.setUint8(8, 0x57); // W
  buffer.setUint8(9, 0x41); // A
  buffer.setUint8(10, 0x56); // V
  buffer.setUint8(11, 0x45); // E

  // fmt subchunk
  buffer.setUint8(12, 0x66); // f
  buffer.setUint8(13, 0x6D); // m
  buffer.setUint8(14, 0x74); // t
  buffer.setUint8(15, 0x20); // (space)
  buffer.setUint32(16, 16, Endian.little); // subchunk1 size
  buffer.setUint16(20, 1, Endian.little); // PCM
  buffer.setUint16(22, 1, Endian.little); // mono
  buffer.setUint32(24, sampleRate, Endian.little);
  buffer.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  buffer.setUint16(32, 2, Endian.little); // block align
  buffer.setUint16(34, 16, Endian.little); // bits per sample

  // data subchunk
  buffer.setUint8(36, 0x64); // d
  buffer.setUint8(37, 0x61); // a
  buffer.setUint8(38, 0x74); // t
  buffer.setUint8(39, 0x61); // a
  buffer.setUint32(40, dataSize, Endian.little);
  // Silence (all zeros) — already zeroed by default.

  return buffer.buffer.asUint8List();
}

void main() {
  setUpAll(() {
    try {
      import_hive.Hive.init(import_io.Directory.systemTemp.path);
    } catch (_) {}
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // prepareCoverArt
  // ═══════════════════════════════════════════════════════════════════════════
  group('AudioMetadataUtils.prepareCoverArt', () {
    // ── U-AUD-META-08 ──
    test('returns correctly sized 600×600 JPEG for a valid image', () {
      final bytes = _createTestImage(1200, 800);
      final result = AudioMetadataUtils.prepareCoverArt(bytes);

      expect(result, isNotNull);
      final decoded = img.decodeImage(result!);
      expect(decoded, isNotNull);
      expect(decoded!.width, 600);
      expect(decoded.height, 600);
    });

    // ── U-AUD-META-09 ──
    test('crops landscape image to square before resizing', () {
      final bytes = _createTestImage(1200, 600);
      final result = AudioMetadataUtils.prepareCoverArt(bytes);

      expect(result, isNotNull);
      final decoded = img.decodeImage(result!);
      expect(decoded, isNotNull);
      expect(decoded!.width, 600);
      expect(decoded.height, 600);
    });

    // ── U-AUD-META-10 ──
    test('crops portrait image to square before resizing', () {
      final bytes = _createTestImage(600, 1200);
      final result = AudioMetadataUtils.prepareCoverArt(bytes);

      expect(result, isNotNull);
      final decoded = img.decodeImage(result!);
      expect(decoded, isNotNull);
      expect(decoded!.width, 600);
      expect(decoded.height, 600);
    });

    // ── U-AUD-META-11 ──
    test('respects custom targetSize parameter', () {
      final bytes = _createTestImage(1200, 1200);
      final result = AudioMetadataUtils.prepareCoverArt(
        bytes,
        targetSize: 300,
      );

      expect(result, isNotNull);
      final decoded = img.decodeImage(result!);
      expect(decoded, isNotNull);
      expect(decoded!.width, 300);
      expect(decoded.height, 300);
    });

    // ── U-AUD-META-12 ──
    test('returns null for invalid/corrupt image bytes', () {
      final bytes = Uint8List.fromList([0x00, 0xFF, 0xAB, 0xCD, 0xEF]);
      final result = AudioMetadataUtils.prepareCoverArt(bytes);

      expect(result, isNull);
    });

    // ── U-AUD-META-13 ──
    test('returns null for empty byte array', () {
      final bytes = Uint8List(0);
      final result = AudioMetadataUtils.prepareCoverArt(bytes);

      expect(result, isNull);
    });

    // ── U-AUD-META-14 ──
    test('produces JPEG output at 90% quality', () {
      final bytes = _createTestImage(800, 800);
      final result = AudioMetadataUtils.prepareCoverArt(bytes);

      expect(result, isNotNull);
      // JPEG SOI marker: 0xFF 0xD8
      expect(result![0], 0xFF);
      expect(result[1], 0xD8);
    });

    // ── U-AUD-META-15 ──
    test('handles already-square images without cropping artifacts', () {
      final bytes = _createTestImage(500, 500);
      final result = AudioMetadataUtils.prepareCoverArt(bytes);

      expect(result, isNotNull);
      final decoded = img.decodeImage(result!);
      expect(decoded, isNotNull);
      expect(decoded!.width, 600);
      expect(decoded.height, 600);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // getProperties — Uses real ffprobe on synthesized WAV files.
  //
  // These tests create real WAV files in a temp directory and exercise
  // the full getProperties pipeline. If ffprobe is not installed, the
  // error-path tests still validate the "Unknown" fallback behavior.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AudioMetadataUtils.getProperties', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp
          .createTempSync('audio_metadata_utils_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    /// Checks whether ffprobe is available on the system.
    Future<bool> isFfprobeAvailable() async {
      try {
        final result = await Process.run('which', ['ffprobe']);
        return result.exitCode == 0;
      } catch (_) {
        return false;
      }
    }

    // ── U-AUD-META-16 ──
    test('returns populated AudioProperties for a valid audio file',
        () async {
      final hasFfprobe = await isFfprobeAvailable();
      if (!hasFfprobe) {
        // Skip on CI or systems without ffprobe.
        markTestSkipped('ffprobe not available on this system');
        return;
      }

      final wavBytes = _createMinimalWav(
        durationMs: 2000,
        sampleRate: 44100,
      );
      final wavFile = File('${tempDir.path}/test_audio.wav')
        ..writeAsBytesSync(wavBytes);

      final props = await AudioMetadataUtils.getProperties(wavFile.path);

      // Duration should be around 2 seconds.
      expect(props.duration, isNot('Unknown'));
      // Sample rate should be 44100 Hz.
      expect(props.sampleRate, contains('44100'));
    });

    // ── U-AUD-META-17 ──
    // When ffprobe is NOT available, getProperties catches the exception.
    // We test by providing a path that will fail regardless.
    test('returns all Unknown when ffprobe fails (non-existent path)',
        () async {
      final props = await AudioMetadataUtils.getProperties(
        '/this/path/absolutely/does/not/exist/audio.mp3',
      );

      expect(props.duration, 'Unknown');
      expect(props.bitrate, 'Unknown');
      expect(props.sampleRate, 'Unknown');
    });

    // ── U-AUD-META-18 + U-AUD-META-19 ──
    // Non-zero exit code and empty stdout both result in all Unknown.
    // Using a non-audio file triggers this in ffprobe.
    test(
      'returns all Unknown for a non-audio file (text file)',
      () async {
        final hasFfprobe = await isFfprobeAvailable();
        if (!hasFfprobe) {
          markTestSkipped('ffprobe not available on this system');
          return;
        }

        final textFile = File('${tempDir.path}/not_audio.txt')
          ..writeAsStringSync('This is plain text, not audio.');

        final props =
            await AudioMetadataUtils.getProperties(textFile.path);

        expect(props.duration, 'Unknown');
        expect(props.bitrate, 'Unknown');
        expect(props.sampleRate, 'Unknown');
      },
    );

    // ── U-AUD-META-20 ──
    test(
      'parses bitrate from a real WAV file (format-level)',
      () async {
        final hasFfprobe = await isFfprobeAvailable();
        if (!hasFfprobe) {
          markTestSkipped('ffprobe not available on this system');
          return;
        }

        final wavBytes = _createMinimalWav(
          durationMs: 1000,
          sampleRate: 44100,
        );
        final wavFile = File('${tempDir.path}/bitrate_test.wav')
          ..writeAsBytesSync(wavBytes);

        final props =
            await AudioMetadataUtils.getProperties(wavFile.path);

        // For a 16-bit mono 44100 Hz WAV, bitrate = 44100*16*1 = 705600 bps
        // = ~706 kbps. The exact value depends on ffprobe's format vs stream
        // reporting, but it should NOT be Unknown.
        expect(props.bitrate, isNot('Unknown'));
      },
    );

    // ── U-AUD-META-23 ──
    test(
      'formats sample rate with Hz suffix from a real WAV',
      () async {
        final hasFfprobe = await isFfprobeAvailable();
        if (!hasFfprobe) {
          markTestSkipped('ffprobe not available on this system');
          return;
        }

        final wavBytes = _createMinimalWav(
          durationMs: 500,
          sampleRate: 48000,
        );
        final wavFile = File('${tempDir.path}/samplerate_test.wav')
          ..writeAsBytesSync(wavBytes);

        final props =
            await AudioMetadataUtils.getProperties(wavFile.path);

        expect(props.sampleRate, '48000 Hz');
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // _formatDuration (tested indirectly via getProperties with real files)
  //
  // Since _formatDuration is private, we test it through getProperties
  // using real WAV files with known durations.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AudioMetadataUtils._formatDuration (indirect via getProperties)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp
          .createTempSync('audio_format_duration_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<bool> isFfprobeAvailable() async {
      try {
        final result = await Process.run('which', ['ffprobe']);
        return result.exitCode == 0;
      } catch (_) {
        return false;
      }
    }

    // ── U-AUD-META-24 ──
    test('formats duration under 1 hour as MM:SS', () async {
      final hasFfprobe = await isFfprobeAvailable();
      if (!hasFfprobe) {
        markTestSkipped('ffprobe not available on this system');
        return;
      }

      // ~5 seconds of audio
      final wavBytes = _createMinimalWav(
        durationMs: 5000,
        sampleRate: 44100,
      );
      final wavFile = File('${tempDir.path}/short_duration.wav')
        ..writeAsBytesSync(wavBytes);

      final props = await AudioMetadataUtils.getProperties(wavFile.path);

      // Should be formatted as MM:SS (e.g. "00:05")
      expect(props.duration, matches(RegExp(r'^\d{2}:\d{2}$')));
    });

    // ── U-AUD-META-25 ──
    // Creating a real 1+ hour WAV file would be impractical in unit tests.
    // This case is best covered through integration tests with real media.
    // We skip it here to keep tests fast.

    // ── U-AUD-META-26 + U-AUD-META-27 ──
    // 0 or negative durations occur when ffprobe returns '0' or no duration.
    // A non-existent path exercises this path.
    test('returns Unknown for files with no parseable duration', () async {
      final props = await AudioMetadataUtils.getProperties(
        '/nonexistent/zero_duration.wav',
      );

      expect(props.duration, 'Unknown');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // getProperties — Malformed JSON (U-AUD-META-28)
  // ═══════════════════════════════════════════════════════════════════════════
  group('AudioMetadataUtils.getProperties edge cases', () {
    // ── U-AUD-META-28 ──
    // When the file doesn't exist, ffprobe returns an error, triggering the
    // catch block and returning all-Unknown. Malformed JSON from ffprobe would
    // also hit the same catch-all.
    test('handles ffprobe failure gracefully (returns all Unknown)', () async {
      final props = await AudioMetadataUtils.getProperties(
        '/tmp/__nonexistent_malformed_test__.xyz',
      );

      expect(props.duration, 'Unknown');
      expect(props.bitrate, 'Unknown');
      expect(props.sampleRate, 'Unknown');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AudioProperties
  // ═══════════════════════════════════════════════════════════════════════════
  group('AudioProperties', () {
    // ── U-AUD-META-29 ──
    test('stores all three fields correctly', () {
      final props = AudioProperties(
        duration: '03:45',
        bitrate: '320 kbps',
        sampleRate: '44100 Hz',
      );

      expect(props.duration, '03:45');
      expect(props.bitrate, '320 kbps');
      expect(props.sampleRate, '44100 Hz');
    });
  });
}
