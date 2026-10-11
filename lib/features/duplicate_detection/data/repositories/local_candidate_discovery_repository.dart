import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';
import 'package:onyxcore/features/duplicate_detection/domain/repositories/candidate_discovery_repository.dart';

class LocalCandidateDiscoveryRepository
    implements CandidateDiscoveryRepository {
  @override
  Stream<ComparisonCandidate> discover({
    required String folderPath,
    required ComparisonCategory category,
    required bool recursive,
    required bool isSource,
  }) async* {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return;

    final stream = dir.list(recursive: recursive, followLinks: false);

    await for (final entity in stream) {
      if (entity is! File) continue;

      final name = p.basename(entity.path);
      final fileType = classifyFileType(name);

      if (!_matchesCategory(fileType, category)) continue;

      try {
        final stat = await entity.stat();
        final fileItem = FileItem(
          path: entity.path,
          name: name,
          type: fileType,
          modified: stat.modified,
          sizeBytes: stat.size,
        );

        yield ComparisonCandidate(file: fileItem, isSource: isSource);
      } catch (_) {
        // Skip files that can't be stat-ed (e.g., permissions)
      }
    }
  }

  bool _matchesCategory(FileItemType type, ComparisonCategory category) {
    if (type == FileItemType.folder) return false;

    switch (category) {
      case ComparisonCategory.all:
        return true;
      case ComparisonCategory.images:
        return type == FileItemType.image;
      case ComparisonCategory.videos:
        return type == FileItemType.video;
      case ComparisonCategory.audio:
        return type == FileItemType.audio;
      case ComparisonCategory.other:
        return type != FileItemType.image &&
            type != FileItemType.video &&
            type != FileItemType.audio;
    }
  }
}
