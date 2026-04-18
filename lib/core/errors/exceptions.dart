/// Exception thrown when a file system operation fails at the data layer.
class FileSystemOperationException implements Exception {
  const FileSystemOperationException(this.message);

  final String message;

  @override
  String toString() => 'FileSystemOperationException: $message';
}

/// Exception thrown when a cache read/write fails at the data layer.
class CacheReadException implements Exception {
  const CacheReadException(this.message);

  final String message;

  @override
  String toString() => 'CacheReadException: $message';
}
