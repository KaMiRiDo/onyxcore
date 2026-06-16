import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

List<FileItem> processVideoQueueIsolate(Map<String, dynamic> args) {
  final itemsJson = args['items'] as List;
  final showHidden = args['showHidden'] as bool;
  final items = itemsJson
      .map((e) => FileItem.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  final List<FileItem> result = [];
  for (final item in items) {
    if (!showHidden && item.name.startsWith('.')) continue;

    if (item.type == FileItemType.video) {
      result.add(item);
    } else if (item.type == FileItemType.folder) {
      try {
        final dir = Directory(item.path);
        if (dir.existsSync()) {
          int videoCount = 0;
          for (final sub in dir.listSync(recursive: false)) {
            final subName = p.basename(sub.path);

            // Skip hidden sub-files if we are not showing hidden items
            if (!showHidden && subName.startsWith('.')) continue;

            if (sub is File &&
                classifyFileType(sub.path) == FileItemType.video) {
              videoCount++;
              // If we only care about presence (not an exact count), we could break.
              // But the UI needs the exact count for the folder tile subtitle.
            }
          }

          if (videoCount > 0) {
            result.add(item.copyWith(itemCount: videoCount));
          }
        }
      } catch (_) {}
    }
  }
  return result;
}
