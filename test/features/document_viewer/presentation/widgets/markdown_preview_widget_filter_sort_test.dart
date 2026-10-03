import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/widgets/filter_sort_button.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/document_viewer/presentation/widgets/markdown_preview_widget.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class MockAppDatabase extends Mock implements AppDatabase {
  MockAppDatabase() {
    when(() => pruneMetadataCache(any())).thenAnswer((_) async => <String>[]);
    when(() => getAllMetadataCache()).thenAnswer((_) async => <MetadataCacheEntry>[]);
    when(() => getAllThumbnailEntries()).thenAnswer((_) async => <ThumbnailCacheEntry>[]);
    when(() => getPlaybackPosition(any())).thenAnswer((_) async => null);
    when(() => savePlaybackPosition(any(), any())).thenAnswer((_) async {});
  }
}

class MockSettingsNotifierEnabled extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings(documentFilterSortEnabled: true);
}

class MockSettingsNotifierDisabled extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

void main() {
  group('MarkdownPreviewWidget Filter/Sort UI', () {
    late Directory tempDir;
    late File testFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('markdown_test');
      testFile = File('${tempDir.path}/test.md');
      testFile.writeAsStringSync('# Hello World');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    Widget buildWidget(bool isFilterSortEnabled) {
      final now = DateTime.now();
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(MockAppDatabase()),
          settingsProvider.overrideWith(isFilterSortEnabled ? MockSettingsNotifierEnabled.new : MockSettingsNotifierDisabled.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MarkdownPreviewWidget(
              item: FileItem(
                path: testFile.path,
                name: 'test.md',
                sizeBytes: 1000,
                modified: now,
                type: FileItemType.document,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows FilterSortButton when documentFilterSortEnabled is true', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildWidget(true));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(FilterSortButton), findsOneWidget);
    });

    testWidgets('hides FilterSortButton when documentFilterSortEnabled is false', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildWidget(false));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.byType(FilterSortButton), findsNothing);
    });
  });
}
