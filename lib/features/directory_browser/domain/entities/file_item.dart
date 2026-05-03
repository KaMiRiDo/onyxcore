import 'package:equatable/equatable.dart';

import '../../../../core/utils/file_type_classifier.dart';

/// Immutable entity representing a single file or folder in the filesystem.
class FileItem extends Equatable {
  const FileItem({
    required this.path,
    required this.name,
    required this.type,
    required this.modified,
    this.sizeBytes,
    this.thumbnailPath,
    this.imageAspectRatio,
    this.isExecutable = false,
    this.hasWritePermission = true,
  });

  final String path;
  final String name;
  final FileItemType type;
  final DateTime modified;
  final int? sizeBytes;
  final String? thumbnailPath;
  final double? imageAspectRatio;
  final bool isExecutable;
  final bool hasWritePermission;

  /// Creates a copy with optional field overrides.
  FileItem copyWith({
    String? path,
    String? name,
    FileItemType? type,
    DateTime? modified,
    int? sizeBytes,
    String? thumbnailPath,
    double? imageAspectRatio,
    bool? isExecutable,
    bool? hasWritePermission,
  }) {
    return FileItem(
      path: path ?? this.path,
      name: name ?? this.name,
      type: type ?? this.type,
      modified: modified ?? this.modified,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      imageAspectRatio: imageAspectRatio ?? this.imageAspectRatio,
      isExecutable: isExecutable ?? this.isExecutable,
      hasWritePermission: hasWritePermission ?? this.hasWritePermission,
    );
  }

  @override
  List<Object?> get props => [path, name, type, modified, sizeBytes, thumbnailPath, imageAspectRatio, isExecutable, hasWritePermission];
}
