import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

/// Generic isolate function that filters a directory listing to only media items
/// of a specific [FileItemType] and folders containing those media items.
///
/// Used by both audio and video queue builders. The `args` map must contain:
/// - `'items'`: List of serialized [FileItem] JSON maps
/// - `'showHidden'`: bool — whether to include dot-prefixed items
/// - `'targetType'`: int — the [FileItemType.index] to filter for
List<FileItem> processMediaQueueIsolate(Map<String, dynamic> args) {
  final itemsJson = args['items'] as List;
  final showHidden = args['showHidden'] as bool;
  final targetType = FileItemType.values[args['targetType'] as int];
  final items = itemsJson
      .map((e) => FileItem.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  final List<FileItem> result = [];
  for (final item in items) {
    if (!showHidden && item.name.startsWith('.')) continue;

    if (item.type == targetType) {
      result.add(item);
    } else if (item.type == FileItemType.folder) {
      try {
        final dir = Directory(item.path);
        if (dir.existsSync()) {
          int mediaCount = 0;
          for (final sub in dir.listSync(recursive: false)) {
            final subName = p.basename(sub.path);

            // Skip hidden sub-files if we are not showing hidden items
            if (!showHidden && subName.startsWith('.')) continue;

            if (sub is File &&
                classifyFileType(sub.path) == targetType) {
              mediaCount++;
              // If we only care about presence (not an exact count), we could break.
              // But the UI needs the exact count for the folder tile subtitle.
            }
          }

          if (mediaCount > 0) {
            result.add(item.copyWith(itemCount: mediaCount));
          }
        }
      } catch (_) {}
    }
  }
  return result;
}
