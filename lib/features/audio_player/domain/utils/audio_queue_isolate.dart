import 'package:onyxcore/core/playlist/media_queue_isolate.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

/// Audio-specific wrapper around [processMediaQueueIsolate].
///
/// Maintains the original function signature for backward compatibility
/// with all existing call sites in `playlist_sidebar.dart` and `audio_player_view.dart`.
List<FileItem> processAudioQueueIsolate(Map<String, dynamic> args) {
  return processMediaQueueIsolate({
    ...args,
    'targetType': FileItemType.audio.index,
  });
}
