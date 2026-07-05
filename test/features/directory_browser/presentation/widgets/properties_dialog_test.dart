import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/platform/directory_watcher.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/properties_dialog.dart';

class MockDirectoryRepository implements DirectoryRepository {
  @override
  Future<List<FileItem>> listDirectory(String path) async {
    return [
      FileItem(
        path: '/home/user/docs/file.txt',
        name: 'file.txt',
        sizeBytes: 1024,
        modified: DateTime(2023),
        type: FileItemType.other,
      )
    ];
  }

  @override
  Future<void> createFolder(String parentPath, String name, {String? taskId}) async {}

  @override
  Future<void> createFile(String parentPath, String name, {String? taskId}) async {}

  @override
  Future<void> deleteItems(
    List<String> paths, {
    required bool permanent,
    String? taskId,
    void Function(int processed, int total)? onProgress,
    void Function(String message)? onLog,
  }) async {}

  @override
  Future<void> moveToTrash(
    List<String> paths, {
    String? taskId,
    void Function(int processed, int total)? onProgress,
    void Function(String message)? onLog,
  }) async {}

  @override
  Future<void> restoreFromTrash(
    List<String> paths, {
    String? taskId,
    void Function(int processed, int total)? onProgress,
    void Function(String message)? onLog,
  }) async {}

  @override
  Future<void> copyItems(List<String> sources, String destination) async {}

  @override
  Future<void> copyItemTo(
    String sourcePath,
    String destinationPath, {
    void Function(int bytesCopied)? onProgress,
    void Function()? onSyncing,
    String? taskId,
    void Function(SendPort port, Isolate? isolate)? onPort,
  }) async {}

  @override
  Future<void> moveItems(List<String> sources, String destination) async {}

  @override
  Future<void> moveItemTo(
    String sourcePath,
    String destinationPath, {
    void Function(int bytesCopied)? onProgress,
    void Function()? onSyncing,
    String? taskId,
    void Function(SendPort port, Isolate? isolate)? onPort,
  }) async {}

  @override
  Future<String> renameItem(
    String oldPath,
    String newName, {
    String? taskId,
    void Function(String message)? onLog,
  }) async { return ''; }

  @override
  Future<List<String>> bulkRename(
    List<String> paths, {
    String? prefix,
    String? baseName,
    String? taskId,
    void Function(String message)? onLog,
  }) async { return []; }

  @override
  Future<void> trashItems(
    List<String> paths, {
    String? taskId,
    void Function(int processed, int total)? onProgress,
    void Function(String message)? onLog,
  }) async {}

  @override
  Stream<FileChangeEvent> watchDirectory(String path) { return const Stream.empty(); }

  @override
  void invalidateCache(String path, {bool recursive = false}) {}

  Future<FileItem> getProperties(String path) async {
    return FileItem(
        path: '/home/user/docs/file.txt',
        name: 'file.txt',
        sizeBytes: 1024,
        modified: DateTime(2023),
        type: FileItemType.other,
      );
  }
}

/// Pump multiple frames without waiting to settle, handles widgets with
/// continuous animations or in-progress FutureBuilders.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  Widget buildTestWidget({List<String> paths = const ['/home/user/docs/file.txt']}) {
    return ProviderScope(
      overrides: [
        directoryRepositoryProvider.overrideWithValue(MockDirectoryRepository()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => PropertiesDialog(paths: paths),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('PropertiesDialog renders single file correctly', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Show Dialog'));
    await pumpFrames(tester);

    expect(find.text('file.txt'), findsWidgets);
    expect(find.text('Parent Folder'), findsOneWidget);
    expect(find.text('/home/user/docs'), findsOneWidget);
  });

  testWidgets('PropertiesDialog renders multiple files correctly', (tester) async {
    await tester.pumpWidget(buildTestWidget(paths: ['/home/user/docs/file1.txt', '/home/user/docs/file2.txt']));
    await tester.tap(find.text('Show Dialog'));
    await pumpFrames(tester);

    // The dialog should be visible
    expect(find.byType(PropertiesDialog), findsOneWidget);
    expect(find.text('Parent Folder'), findsOneWidget);
    expect(find.text('/home/user/docs'), findsOneWidget);
  });

  testWidgets('PropertiesDialog closes on close button tap', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Show Dialog'));
    await pumpFrames(tester);

    await tester.tap(find.byIcon(Icons.close));
    await pumpFrames(tester);

    expect(find.byType(PropertiesDialog), findsNothing);
  });
}
