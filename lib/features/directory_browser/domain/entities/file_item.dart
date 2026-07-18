import 'package:equatable/equatable.dart';

import 'package:onyxcore/core/utils/file_type_classifier.dart';

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
    this.itemCount,
    this.isExecutable = false,
    this.hasWritePermission = true,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      path: json['path'] as String,
      name: json['name'] as String,
      type: FileItemType.values[json['type'] as int],
      modified: DateTime.fromMillisecondsSinceEpoch(json['modified'] as int),
      sizeBytes: json['sizeBytes'] as int?,
      thumbnailPath: json['thumbnailPath'] as String?,
      imageAspectRatio: json['imageAspectRatio'] as double?,
      itemCount: json['itemCount'] as int?,
      isExecutable: json['isExecutable'] as bool? ?? false,
      hasWritePermission: json['hasWritePermission'] as bool? ?? true,
    );
  }

  final String path;
  final String name;
  final FileItemType type;
  final DateTime modified;
  final int? sizeBytes;
  final String? thumbnailPath;
  final double? imageAspectRatio;
  final int? itemCount;
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
    int? itemCount,
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
      itemCount: itemCount ?? this.itemCount,
      isExecutable: isExecutable ?? this.isExecutable,
      hasWritePermission: hasWritePermission ?? this.hasWritePermission,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'type': type.index,
      'modified': modified.millisecondsSinceEpoch,
      'sizeBytes': sizeBytes,
      'thumbnailPath': thumbnailPath,
      'imageAspectRatio': imageAspectRatio,
      'itemCount': itemCount,
      'isExecutable': isExecutable,
      'hasWritePermission': hasWritePermission,
    };
  }

  @override
  List<Object?> get props => [
    path,
    name,
    type,
    modified,
    sizeBytes,
    thumbnailPath,
    imageAspectRatio,
    itemCount,
    isExecutable,
    hasWritePermission,
  ];
}
