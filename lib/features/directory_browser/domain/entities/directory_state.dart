import 'package:equatable/equatable.dart';

import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

/// Immutable state of the current directory listing.
class DirectoryState extends Equatable {
  const DirectoryState({
    required this.currentPath,
    this.items = const [],
    this.totalSizeBytes = 0,
    this.isLoading = true,
    this.error,
  });

  final String currentPath;
  final List<FileItem> items;
  final int totalSizeBytes;
  final bool isLoading;
  final String? error;

  DirectoryState copyWith({
    String? currentPath,
    List<FileItem>? items,
    int? totalSizeBytes,
    bool? isLoading,
    String? error,
  }) {
    return DirectoryState(
      currentPath: currentPath ?? this.currentPath,
      items: items ?? this.items,
      totalSizeBytes: totalSizeBytes ?? this.totalSizeBytes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    currentPath,
    items,
    totalSizeBytes,
    isLoading,
    error,
  ];
}
