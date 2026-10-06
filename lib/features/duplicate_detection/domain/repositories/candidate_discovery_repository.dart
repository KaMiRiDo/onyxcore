import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';

/// Contract for discovering candidate files inside a folder.
///
/// The repository is responsible only for file discovery and category
/// filtering.  It does not perform any metadata extraction or fingerprinting.
abstract interface class CandidateDiscoveryRepository {
  /// Returns all [ComparisonCandidate]s found under [folderPath] that match
  /// [category].
  ///
  /// When [recursive] is [true] the repository traverses all sub-folders.
  /// Symlinks that point outside [folderPath] are ignored to prevent cycles.
  ///
  /// Yields candidates progressively via the returned [Stream] so the
  /// orchestrator can begin Stage 1 processing before discovery completes.
  Stream<ComparisonCandidate> discover({
    required String folderPath,
    required ComparisonCategory category,
    required bool recursive,
    required bool isSource,
  });
}
