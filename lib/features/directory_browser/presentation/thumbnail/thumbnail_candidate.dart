import 'package:flutter/cupertino.dart' show BuildContext;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show BuildContext;
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

/// Minimal immutable snapshot of a media file used for thumbnail scheduling.
///
/// Conversion from [FileItem] occurs only at the UI/session boundary via
/// [ThumbnailCandidate.fromFileItem]. After that point, queue, job, and
/// generation layers retain [ThumbnailCandidate] exclusively and never hold
/// a reference to [FileItem], [BuildContext], widgets, or folder lists.
@immutable
class ThumbnailCandidate {
  const ThumbnailCandidate({
    required this.path,
    required this.type,
    required this.modifiedEpochMs,
    required this.sizeBytes,
  });

  /// Conversion factory — permitted only at the UI/session boundary.
  factory ThumbnailCandidate.fromFileItem(FileItem item) => ThumbnailCandidate(
        path: item.path,
        type: item.type,
        modifiedEpochMs: item.modified.millisecondsSinceEpoch,
        sizeBytes: item.sizeBytes ?? 0,
      );

  final String path;
  final FileItemType type;

  /// Source file last-modified timestamp in milliseconds since epoch.
  final int modifiedEpochMs;

  /// Source file size in bytes; 0 when unknown.
  final int sizeBytes;

  bool get isVideo => type == FileItemType.video;
  bool get isImage => type == FileItemType.image;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThumbnailCandidate &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          modifiedEpochMs == other.modifiedEpochMs &&
          sizeBytes == other.sizeBytes;

  @override
  int get hashCode => Object.hash(path, modifiedEpochMs, sizeBytes);

  @override
  String toString() =>
      'ThumbnailCandidate(path: $path, type: $type, mtime: $modifiedEpochMs, size: $sizeBytes)';
}
