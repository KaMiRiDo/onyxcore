import 'package:onyxcore/features/duplicate_detection/domain/entities/candidate_fingerprint.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_generator.dart';

/// Run-scoped in-memory cache for candidate fingerprints.
///
/// Guarantees that each candidate is fingerprinted at most once per comparison run.
/// Released immediately when the comparison run completes or is cancelled.
class FingerprintCache {
  FingerprintCache();

  final Map<String, CandidateFingerprint> _cache = {};

  /// Total number of cached fingerprints in this session.
  int get size => _cache.length;

  /// Returns the cached fingerprint for [candidatePath], or `null` if not cached.
  CandidateFingerprint? get(String candidatePath) => _cache[candidatePath];

  /// Directly puts [fingerprint] into the cache.
  void put(CandidateFingerprint fingerprint) {
    _cache[fingerprint.candidatePath] = fingerprint;
  }

  /// Returns the cached fingerprint if present; otherwise invokes
  /// [FingerprintGenerator.generate], stores the result in memory, and returns it.
  Future<CandidateFingerprint> getOrGenerate(
    ComparisonCandidate candidate,
    FingerprintGenerator generator,
  ) async {
    final cached = _cache[candidate.file.path];
    if (cached != null) return cached;

    final fp = await generator.generate(candidate);
    _cache[candidate.file.path] = fp;
    return fp;
  }

  /// Clears all in-memory fingerprints, releasing references for GC.
  void clear() {
    _cache.clear();
  }
}
