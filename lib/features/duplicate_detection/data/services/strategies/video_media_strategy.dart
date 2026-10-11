import 'dart:convert';

import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/media_probe.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_type_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_extractor.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_normalizer.dart';

class VideoMediaStrategy implements MediaTypeStrategy {
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
        for (final stream in streams) {
          if (stream['codec_type'] == 'video' || (stream['width'] != null)) {
            width = stream['width'] as num?;
            height = stream['height'] as num?;
            break;
          }
        }
      }

      double? durationSecs;
      final format = json['format'] as Map<String, dynamic>?;
      if (format != null && format['duration'] != null) {
        durationSecs = double.tryParse(format['duration'].toString());
      }

      MediaOrientation orientation = MediaOrientation.unknown;
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
}
