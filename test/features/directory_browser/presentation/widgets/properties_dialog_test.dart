import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
      ),
      FileItem(
        path: '/home/user/docs/file1.txt',
        name: 'file1.txt',
        sizeBytes: 2048,
        modified: DateTime(2023),
        type: FileItemType.other,
      ),
      FileItem(
        path: '/home/user/docs/file2.txt',
        name: 'file2.txt',
        sizeBytes: 4096,
        modified: DateTime(2023),
        type: FileItemType.other,
      )
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
