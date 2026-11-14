import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/media_metadata_datasource.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/candidate_fingerprint.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_generator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_type_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_extractor.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_normalizer.dart';

class ImageMediaStrategy implements MediaTypeStrategy, FingerprintGenerator {
  @override
  bool supports(ComparisonCandidate candidate) {
    return candidate.file.type == FileItemType.image;
  }

  @override
  Future<Stage1Metadata> extractMetadata(ComparisonCandidate candidate) async {
    try {
      final ratio = MediaMetadataDatasource.parseImageDimensions(
        candidate.file.path,
      );
      if (ratio != null) {
        return Stage1Metadata(
          candidatePath: candidate.file.path,
          orientation: Stage1Normalizer.normalizeOrientationRatio(ratio),
          aspectRatioGroup: Stage1Normalizer.normalizeAspectRatioFromRatio(
            ratio,
          ),
        );
      }
      return Stage1Metadata(
        candidatePath: candidate.file.path,
        orientation: MediaOrientation.unknown,
      );
    } catch (e) {
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
      final file = File(candidate.file.path);
      if (!file.existsSync()) {
        throw FingerprintGenerationException(
          candidate.file.path,
          'File does not exist',
        );
      }

      final bytes = await file.readAsBytes();

      // Offload heavy image decoding, resizing, and 256-bit dHash generation
      // to a background isolate so the UI event loop and loader never freeze.
      final fpBytes = await Isolate.run(() {
        final decoded = img.decodeImage(bytes);
        if (decoded == null) {
          throw FingerprintGenerationException(
            candidate.file.path,
            'Failed to decode image data',
          );
        }

        // Resize to 17x16 for 16x16 horizontal gradient dHash (256 bits)
        final resized = img.copyResize(
          decoded,
          width: 17,
          height: 16,
          interpolation: img.Interpolation.linear,
        );

        final result = Uint8List(32);
        var bitIndex = 0;

        for (var y = 0; y < 16; y++) {
          for (var x = 0; x < 16; x++) {
            final p1 = resized.getPixel(x, y);
            final p2 = resized.getPixel(x + 1, y);
            if (p1.luminanceNormalized > p2.luminanceNormalized) {
              final bytePos = bitIndex ~/ 8;
              final bitOffset = 7 - (bitIndex % 8);
              result[bytePos] |= 1 << bitOffset;
            }
            bitIndex++;
          }
        }

        return result;
      });

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
