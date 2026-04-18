/// Abstract failure class for domain layer error handling.
///
/// All failures that cross the domain boundary must extend this class.
abstract class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Failure related to file system operations (read, write, delete, etc.)
class FileSystemFailure extends Failure {
  const FileSystemFailure(super.message);
}

/// Failure related to insufficient permissions.
class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

/// Failure related to cache read/write operations.
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}
