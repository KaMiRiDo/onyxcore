import 'package:file/memory.dart';
// ignore: unused_import, Skeleton — ProviderScope will be used by future testWidgets.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: unused_import, Skeleton — fileSystemServiceProvider will be overridden in future testWidgets.
import 'package:onyxcore/features/file_picker/presentation/providers/file_picker_notifier.dart';
import 'package:onyxcore/services/file_system_service.dart';

import '../../../helpers/file_system_helper.dart';

void main() {
  late MemoryFileSystem mockFs;
  // ignore: unused_local_variable, Skeleton — mockService will be used by future test cases.
  late FileSystemService mockService;

  setUp(() {
    // Initialize the sandboxed MemoryFileSystem with a full dummy tree.
    mockFs = setupMockFileSystem();

    // Create a FileSystemService backed by the MemoryFileSystem.
    mockService = FileSystemService(mockFs);
  });

  group('FileGrid', () {
    // TODO: Test cases will be provided by user.
    //
    // When writing testWidgets(), wrap the widget under test in a
    // ProviderScope with the MemoryFileSystem-backed service override:
    //
    //   testWidgets('example test', (tester) async {
    //     await tester.pumpWidget(
    //       ProviderScope(
    //         overrides: [
    //           fileSystemServiceProvider.overrideWithValue(mockService),
    //         ],
    //         child: const MaterialApp(
    //           home: Scaffold(body: FileGrid()),
    //         ),
    //       ),
    //     );
    //   });
  });
}
