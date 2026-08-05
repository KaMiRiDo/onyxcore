// ignore_for_file: inference_failure_on_instance_creation
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/media_metadata_datasource.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/pages/gallery_page.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/device_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/pinned_items_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/domain/repositories/settings_repository.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

import 'mock_utils.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => AppSettings();
}

class MockDirectoryRepository extends Mock implements DirectoryRepository {}

class MockPinnedItemsNotifier extends PinnedItemsNotifier {
  @override
  Future<Map<String, int>> build() async => {};
}

class MockMediaMetadataDatasource extends Mock implements MediaMetadataDatasource {}

class MockDownloadsPanelWidthNotifier extends DownloadsPanelWidthNotifier {
  @override
  Future<double> build() async => 320.0;
}

Widget createWidgetUnderTest(
  AppDatabase mockDb, {
  MockSettingsRepository? mockSettingsRepo,
  MockDirectoryRepository? mockDirRepo,
}) {
  final mockSettingsRepository = mockSettingsRepo ?? MockSettingsRepository();
  when(mockSettingsRepository.load).thenAnswer((_) async => AppSettings());
  when(() => mockSettingsRepository.setFolderSort(any(), any())).thenAnswer((_) async {});

  final mockDirectoryRepository = mockDirRepo ?? MockDirectoryRepository();
  when(() => mockDirectoryRepository.listDirectory(any())).thenAnswer((_) async => [
        FileItem(
          path: '/mock/path/file.txt',
          name: 'file.txt',
          type: FileItemType.other,
          modified: DateTime.now(),
        ),
      ]);
  when(() => mockDirectoryRepository.watchDirectory(any())).thenAnswer((_) => const Stream.empty());
  when(() => mockDirectoryRepository.invalidateCache(any(), recursive: any(named: 'recursive'))).thenReturn(null);

  final mockMediaMetadataDatasource = MockMediaMetadataDatasource();
  when(() => mockMediaMetadataDatasource.extractAspectRatio(any())).thenAnswer((_) async => null);

  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(mockDb),
      settingsRepositoryProvider.overrideWithValue(mockSettingsRepository),
      settingsProvider.overrideWith(MockSettingsNotifier.new),
      directoryRepositoryProvider.overrideWithValue(mockDirectoryRepository),
      pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
      deviceProvider.overrideWith((ref) => Stream.value([])),
      mediaMetadataDatasourceProvider.overrideWithValue(mockMediaMetadataDatasource),
      downloadsPanelWidthProvider.overrideWith(MockDownloadsPanelWidthNotifier.new),
    ],
    child: MaterialApp(
      home: const Scaffold(
        body: SizedBox(
          width: 800,
          height: 600,
          child: GalleryPage(),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    HttpOverrides.global = null;
    registerFallbackValue(SortOption.aToZ);
  });

  setUp(PersistentViewerManager.reset);

  group('GalleryPage Download Shortcuts', () {
    testWidgets('Ctrl+D toggles downloads panel open and immediately closed without manual refocusing', (WidgetTester tester) async {
      final db = getMockDb();
      await tester.pumpWidget(createWidgetUnderTest(db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final container = ProviderScope.containerOf(tester.element(find.byType(GalleryPage)));
      expect(container.read(downloadsPanelOpenProvider), isFalse);

      // Initial focus
      container.read(mainFocusNodeProvider).requestFocus();
      await tester.pump();

      // First Press: Ctrl+D to open
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Panel should now be open with tasks view
      expect(container.read(downloadsPanelOpenProvider), isTrue);
      expect(container.read(downloadsPanelViewProvider), equals(DownloadsPanelView.tasks));

      // Second Press: Ctrl+D immediately without calling requestFocus()
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Panel should now be closed
      expect(container.read(downloadsPanelOpenProvider), isFalse);
    });

    testWidgets('Ctrl+D toggles downloads panel even when downloader standalone window is open', (WidgetTester tester) async {
      final db = getMockDb();
      await tester.pumpWidget(createWidgetUnderTest(db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final container = ProviderScope.containerOf(tester.element(find.byType(GalleryPage)));

      container.read(mainFocusNodeProvider).requestFocus();
      await tester.pump();

      // Press Ctrl+D
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(downloadsPanelOpenProvider), isTrue);
    });

    testWidgets('Ctrl+Shift+D opens standalone window when not open, and focuses when open', (WidgetTester tester) async {
      final db = getMockDb();
      final binding = tester.binding;
      final channelCalls = <MethodCall>[];
      
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('onyxcore/window_manager'),
        (MethodCall call) async {
          channelCalls.add(call);
          if (call.method == 'create_window') {
            return tester.view.viewId;
          }
          return null;
        },
      );

      await tester.pumpWidget(createWidgetUnderTest(db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final container = ProviderScope.containerOf(tester.element(find.byType(GalleryPage)));
      container.read(mainFocusNodeProvider).requestFocus();
      await tester.pump();

      // Press Ctrl+Shift+D to open standalone downloader
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should have called create_window
      expect(channelCalls.any((c) => c.method == 'create_window'), isTrue);

      // Now with window already open, press Ctrl+Shift+D again
      channelCalls.clear();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should have called present_window instead of create_window
      expect(channelCalls.any((c) => c.method == 'create_window'), isFalse);
      expect(channelCalls.any((c) => c.method == 'present_window'), isTrue);
    });

    testWidgets('Recovers focus when mainWindowFocusTrigger notifies', (WidgetTester tester) async {
      final db = getMockDb();
      await tester.pumpWidget(createWidgetUnderTest(db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final container = ProviderScope.containerOf(tester.element(find.byType(GalleryPage)));
      
      // Unfocus
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Notify window focus
      PersistentViewerManager.mainWindowFocusTrigger.value++;
      await tester.pump();

      // Press Ctrl+D
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(downloadsPanelOpenProvider), isTrue);
    });
  });
}
