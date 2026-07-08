import 'dart:convert';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

/// Supported viewer types for standalone windows.
enum ViewerType {
  video,
  image,
  markdown,
  audio,
  downloader,
  unsupported,
}

/// Parameters passed to a secondary window to initialize a viewer.
class WindowParams {
  final ViewerType viewerType;
  final FileItem file;
  final String? parentWindowId;
  final Map<String, dynamic> initParams;

  const WindowParams({
    required this.viewerType,
    required this.file,
    this.parentWindowId,
    this.initParams = const {},
  });

  /// Serializes params to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'viewerType': viewerType.name,
    'file': {
      'name': file.name,
      'path': file.path,
      'sizeBytes': file.sizeBytes,
      'modified': file.modified.millisecondsSinceEpoch,
      'type': file.type.name,
    },
    'parentWindowId': parentWindowId,
    'initParams': initParams,
  };

  /// Creates params from a JSON-compatible map.
  factory WindowParams.fromJson(Map<String, dynamic> json) {
    final fileMap = json['file'] as Map<String, dynamic>;
    return WindowParams(
      viewerType: ViewerType.values.firstWhere(
        (e) => e.name == json['viewerType'],
        orElse: () => ViewerType.unsupported,
      ),
      file: FileItem(
        name: fileMap['name'] as String,
        path: fileMap['path'] as String,
        sizeBytes: fileMap['sizeBytes'] as int?,
        modified: DateTime.fromMillisecondsSinceEpoch(
          fileMap['modified'] as int,
        ),
        type: FileItemType.values.firstWhere(
          (e) => e.name == fileMap['type'],
          orElse: () => FileItemType.other,
        ),
      ),
      parentWindowId: json['parentWindowId'] as String?,
      initParams: json['initParams'] as Map<String, dynamic>,
    );
  }

  /// Encodes params to a JSON string for window handoff.
  String encode() => jsonEncode(toJson());
}
