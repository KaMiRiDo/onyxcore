import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:onyxcore/services/file_system_service.dart';

import '../../helpers/file_system_helper.dart';

void main() {
  late MemoryFileSystem mockFs;
  // ignore: unused_local_variable, Skeleton — service will be used by future test cases.
  late FileSystemService service;

  setUp(() {
    // Initialize the sandboxed MemoryFileSystem with a full dummy tree.
    mockFs = setupMockFileSystem();

    // Inject the MemoryFileSystem into the service under test.
    // In production, FileSystemService() defaults to LocalFileSystem.
    service = FileSystemService(mockFs);
  });

  group('FileSystemService', () {
    // TODO: Test cases will be provided by user.
  });
}
