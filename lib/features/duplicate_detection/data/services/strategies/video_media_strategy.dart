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
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_normalizer.dart';

class VideoMediaStrategy implements MediaTypeStrategy, FingerprintGenerator {
  const VideoMediaStrategy([this.probe = const MediaProbe()]);
  final MediaProbe probe;

  @override
  bool supports(ComparisonCandidate candidate) {
    return candidate.file.type == FileItemType.video;
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
        '-show_streams',
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

      num? width;
      num? height;

      final streams = json['streams'] as List<dynamic>?;
      if (streams != null) {
        for (final item in streams) {
          if (item is Map<String, dynamic>) {
            if (item['codec_type'] == 'video' || item['width'] != null) {
              width = item['width'] as num?;
              height = item['height'] as num?;
              break;
            }
          }
        }
      }

      double? durationSecs;
      final format = json['format'] as Map<String, dynamic>?;
      if (format != null && format['duration'] != null) {
        durationSecs = double.tryParse(format['duration'].toString());
      }

      var orientation = MediaOrientation.unknown;
      String? aspectRatioGroup;
      if (width != null && height != null) {
        orientation = Stage1Normalizer.normalizeOrientation(width, height);
        aspectRatioGroup = Stage1Normalizer.normalizeAspectRatio(width, height);
      }

      return Stage1Metadata(
        candidatePath: candidate.file.path,
        orientation: orientation,
        aspectRatioGroup: aspectRatioGroup,
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

      final fpBytes = Uint8List(32); // 4 frames * 8 bytes (64 bits) = 32 bytes

      for (var f = 0; f < timestamps.length; f++) {
        final t = timestamps[f];
        final result = await probe.runFfmpeg([
          '-v',
          'error',
          '-ss',
          t.toStringAsFixed(3),
          '-i',
          candidate.file.path,
          '-vframes',
          '1',
          '-vf',
          'scale=9:8,format=gray',
          '-f',
          'rawvideo',
          '-',
        ]);

        if (result.exitCode != 0) {
          throw FingerprintGenerationException(
            candidate.file.path,
            'ffmpeg frame extraction failed (exit code ${result.exitCode})',
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

        if (rawBytes.length < 72) {
          throw FingerprintGenerationException(
            candidate.file.path,
            'ffmpeg returned insufficient frame bytes (${rawBytes.length})',
          );
        }

        // 9x8 frame: 8 rows of 9 pixels. Each row has 8 adjacent horizontal comparisons = 8 bits = 1 byte
        final frameByteOffset = f * 8;
        for (var y = 0; y < 8; y++) {
          var rowByte = 0;
          final rowStart = y * 9;
          for (var x = 0; x < 8; x++) {
            final p1 = rawBytes[rowStart + x];
            final p2 = rawBytes[rowStart + x + 1];
            if (p1 > p2) {
              rowByte |= 1 << (7 - x);
            }
          }
          fpBytes[frameByteOffset + y] = rowByte;
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
