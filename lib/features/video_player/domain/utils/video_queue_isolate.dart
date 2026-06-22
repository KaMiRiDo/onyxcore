import 'package:onyxcore/core/playlist/media_queue_isolate.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

/// Video-specific wrapper around [processMediaQueueIsolate].
///
/// Maintains the original function signature for backward compatibility
/// with all existing call sites in `video_playlist_sidebar.dart`.
List<FileItem> processVideoQueueIsolate(Map<String, dynamic> args) {
  return processMediaQueueIsolate({
    ...args,
    'targetType': FileItemType.video.index,
  });
}
