import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_analysis_provider.dart';

void main() {
  group('DirectoryAnalysisProvider Tests', () {
    late ProviderContainer container;
    late Directory tempDir;

    setUp(() async {
      container = ProviderContainer();
      tempDir = await Directory.systemTemp.createTemp('analysis_test');

      // Create some files
      File('${tempDir.path}/a.txt').writeAsStringSync('hello world'); // 11 bytes
      File('${tempDir.path}/img.png').writeAsBytesSync([1, 2, 3, 4]); // 4 bytes
    });

    tearDown(() async {
      container.dispose();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('analyzes directory correctly via isolate', () async {
      final provider = directoryAnalysisProvider(tempDir.path);
      final sub = container.listen(provider, (_, __) {});
      final result = await container.read(provider.future);

      expect(result.path, tempDir.path);
      expect(result.totalItems, 2);
      expect(result.totalBytes, 15); // 11 + 4

      expect(result.allFiles.length, 2);
      expect(result.categoryStats[FileItemType.document]?.count, 1);
      expect(result.categoryStats[FileItemType.image]?.count, 1);
      sub.close();
    });

    test('returns empty result for non-existent directory', () async {
      final nonExistentPath = '${tempDir.path}/does_not_exist';
      final provider = directoryAnalysisProvider(nonExistentPath);
      final sub = container.listen(provider, (_, __) {});
      final result = await container.read(provider.future);

      expect(result.totalItems, 0);
      expect(result.totalBytes, 0);
      expect(result.allFiles, isEmpty);
      sub.close();
    });
    testWidgets('removeFilesFromAnalysis updates state correctly', (WidgetTester tester) async {
      final fakeResult = DirectoryAnalysisResult(
        path: tempDir.path,
        totalItems: 2,
        totalBytes: 15,
        diskUsage: null,
        categoryStats: {
          FileItemType.document: const CategoryStats(count: 1, totalBytes: 11),
          FileItemType.image: const CategoryStats(count: 1, totalBytes: 4),
          FileItemType.video: const CategoryStats(),
          FileItemType.audio: const CategoryStats(),
          FileItemType.archive: const CategoryStats(),
          FileItemType.other: const CategoryStats(),
        },
        allFiles: [
          FileStatWithInfo(
            path: '${tempDir.path}/a.txt',
            name: 'a.txt',
            stat: FileStatData(size: 11, modified: DateTime.now()),
            type: FileItemType.document,
          ),
          FileStatWithInfo(
            path: '${tempDir.path}/img.png',
            name: 'img.png',
            stat: FileStatData(size: 4, modified: DateTime.now()),
            type: FileItemType.image,
          ),
        ],
      );

      WidgetRef? capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            directoryAnalysisProvider(tempDir.path).overrideWith((ref) => fakeResult),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      // Pre-populate state
      capturedRef!.read(directoryAnalysisStateProvider(tempDir.path).notifier).state = AsyncData(fakeResult);

      final fileToRemove = '${tempDir.path}/a.txt';
      removeFilesFromAnalysis(capturedRef!, tempDir.path, [fileToRemove]);

      final updatedState = capturedRef!.read(directoryAnalysisStateProvider(tempDir.path));
      expect(updatedState?.value?.totalItems, 1);
      expect(updatedState?.value?.allFiles.length, 1);
      expect(updatedState?.value?.allFiles.first.name, 'img.png');
      expect(updatedState?.value?.categoryStats[FileItemType.document]?.count, 0);
      expect(updatedState?.value?.categoryStats[FileItemType.image]?.count, 1);
    });
  });
}
