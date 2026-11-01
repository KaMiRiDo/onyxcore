import 'dart:convert';
import 'dart:typed_data';

import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/media_probe.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/candidate_fingerprint.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_generator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_type_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_extractor.dart';

class AudioMediaStrategy implements MediaTypeStrategy, FingerprintGenerator {
  const AudioMediaStrategy([this.probe = const MediaProbe()]);
  final MediaProbe probe;

  @override
  bool supports(ComparisonCandidate candidate) {
    return candidate.file.type == FileItemType.audio;
  }

  @override
  Future<Stage1Metadata> extractMetadata(ComparisonCandidate candidate) async {
    try {
      final result = await probe.runFfprobe([
        '-v',
        'quiet',
        '-print_format',
        'json',
        '-show_format',
        candidate.file.path,
      ]);

      if (result.exitCode != 0) {
        throw Stage1ExtractionException(
          candidate.file.path,
          'ffprobe exit code ${result.exitCode}',
        );
      }

      final jsonStr = result.stdout as String;
      if (jsonStr.trim().isEmpty) {
        throw Stage1ExtractionException(
          candidate.file.path,
          'ffprobe returned empty output',
        );
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      double? durationSecs;
      final format = json['format'] as Map<String, dynamic>?;
      if (format != null && format['duration'] != null) {
        durationSecs = double.tryParse(format['duration'].toString());
      }

      return Stage1Metadata(
        candidatePath: candidate.file.path,
        orientation: MediaOrientation.notApplicable,
        durationSeconds: durationSecs,
      );
    } catch (e) {
      if (e is Stage1ExtractionException) rethrow;
      throw Stage1ExtractionException(candidate.file.path, e.toString());
    }
  }

  @override
  ClusterKey buildClusterKey(
    ComparisonCandidate candidate,
    Stage1Metadata metadata,
  ) {
    return ClusterKey.fromMetadata(candidate.file.type, metadata);
  }

  @override
  Future<CandidateFingerprint> generate(ComparisonCandidate candidate) async {
    try {
      // 1. Determine duration for bounded sampling
      var duration = 10.0;
      try {
        final meta = await extractMetadata(candidate);
        if (meta.durationSeconds != null && meta.durationSeconds! > 0) {
          duration = meta.durationSeconds!;
        }
      } catch (_) {
        // Fall back to default duration timestamps
      }

      final timestamps = [
        duration * 0.20,
        duration * 0.40,
        duration * 0.60,
        duration * 0.80,
      ];

      final fpBytes = Uint8List(
        32,
      ); // 4 segments * 8 bytes (64 bits) = 32 bytes

      for (var s = 0; s < timestamps.length; s++) {
        final t = timestamps[s];
        final result = await probe.runFfmpeg([
          '-v',
          'error',
          '-ss',
          t.toStringAsFixed(3),
          '-t',
          '0.5',
          '-i',
          candidate.file.path,
          '-vn',
          '-ac',
          '1',
          '-ar',
          '8000',
          '-f',
          'u8',
          '-',
        ]);

        if (result.exitCode != 0) {
          throw FingerprintGenerationException(
            candidate.file.path,
            'ffmpeg audio extraction failed (exit code ${result.exitCode})',
          );
        }

        List<int> rawBytes;
        if (result.stdout is List<int>) {
          rawBytes = result.stdout as List<int>;
        } else if (result.stdout is String) {
          rawBytes = (result.stdout as String).codeUnits;
        } else {
          rawBytes = const [];
        }

        if (rawBytes.isEmpty) {
          throw FingerprintGenerationException(
            candidate.file.path,
            'ffmpeg returned empty audio stream',
          );
        }

        // Divide segment into 8 temporal windows.
        // In each window, compute energy of 8 sub-bands (sub-slices).
        // 8 windows * 8 bits = 64 bits = 8 bytes per segment.
        final segmentByteOffset = s * 8;
        final windowSize = rawBytes.length ~/ 8;

        for (var w = 0; w < 8; w++) {
          final wStart = w * windowSize;
          final wEnd = (w + 1) * windowSize;
          final subBinSize = (wEnd - wStart) ~/ 8;

          var windowByte = 0;
          if (subBinSize > 0) {
            for (var b = 0; b < 8; b++) {
              final bStart = wStart + b * subBinSize;
              final bEnd = bStart + subBinSize;
              var energy = 0;
              for (var i = bStart; i < bEnd && i < rawBytes.length; i++) {
                final dev = (rawBytes[i] - 128).abs();
                energy += dev;
              }
              // Compare energy against nominal mean threshold
              final avgEnergy = energy / subBinSize;
              if (avgEnergy > 16) {
                windowByte |= 1 << (7 - b);
              }
            }
          }
          fpBytes[segmentByteOffset + w] = windowByte;
        }
      }

      return CandidateFingerprint(
        candidatePath: candidate.file.path,
        bytes: fpBytes,
      );
    } catch (e) {
      if (e is FingerprintGenerationException) rethrow;
      throw FingerprintGenerationException(candidate.file.path, e.toString());
    }
  }
}
