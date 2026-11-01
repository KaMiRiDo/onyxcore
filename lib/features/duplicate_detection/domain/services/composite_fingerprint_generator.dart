import 'package:onyxcore/features/duplicate_detection/domain/entities/candidate_fingerprint.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_generator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_strategy_registry.dart';

/// Routes candidate fingerprinting to the matching strategy from [registry].
class CompositeFingerprintGenerator implements FingerprintGenerator {
  const CompositeFingerprintGenerator(this.registry);
  final MediaStrategyRegistry registry;

  @override
  bool supports(ComparisonCandidate candidate) {
    try {
      final strategy = registry.getStrategy(candidate);
      if (strategy is FingerprintGenerator) {
        return strategy.supports(candidate);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<CandidateFingerprint> generate(ComparisonCandidate candidate) {
    final strategy = registry.getStrategy(candidate);
    if (strategy is FingerprintGenerator) {
      return (strategy as FingerprintGenerator).generate(candidate);
    }
    throw FingerprintGenerationException(
      candidate.file.path,
      'No fingerprint generator found for ${candidate.file.type.name}',
    );
  }
}
