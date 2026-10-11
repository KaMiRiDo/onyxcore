import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_type_strategy.dart';

class MediaStrategyRegistry {
  const MediaStrategyRegistry(this.strategies);
  final List<MediaTypeStrategy> strategies;

  MediaTypeStrategy getStrategy(ComparisonCandidate candidate) {
    return strategies.firstWhere(
      (s) => s.supports(candidate),
      orElse: () =>
          throw StateError('No strategy found for ${candidate.file.type}'),
    );
  }
}
