// ignore_for_file: avoid_print, unused_local_variable
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/directory_size_datasource.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/media_metadata_datasource.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/filter_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/tab_state.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/pinned_items_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/domain/repositories/settings_repository.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

import '../pages/mock_utils.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => AppSettings(showHiddenFiles: true);
}

class MockTabManager extends TabManager {
  @override
  TabManagerState build() {
    return TabManagerState(
      tabs: [
        TabState(
          id: 'tab_1',
          currentPath: Platform.environment['HOME'] ?? '/',
          history: [Platform.environment['HOME'] ?? '/'],
          sortSettings: SortSettings(),
        ),
      ],
      activeTabIndex: 0,
    );
  }
}

class MockDirectoryRepository extends Mock implements DirectoryRepository {}

class MockMediaMetadataDatasource extends Mock
    implements MediaMetadataDatasource {}

class MockDirectorySizeDatasource extends Mock
    implements DirectorySizeDatasource {}

class MockPinnedItemsNotifier extends PinnedItemsNotifier {
  @override
  Future<Map<String, int>> build() async => {'/mock/pinned': 1};
}

void main() {
  setUpAll(() {
    registerFallbackValue(SortOption.aToZ);
  });

  group('Directory Providers Tests', () {
    late ProviderContainer container;
    late MockSettingsRepository mockSettingsRepository;
    late MockDirectoryRepository mockDirectoryRepository;
    late MockMediaMetadataDatasource mockMediaMetadataDatasource;
    late MockDirectorySizeDatasource mockDirectorySizeDatasource;

    setUp(() async {
      mockSettingsRepository = MockSettingsRepository();
      when(
        () => mockSettingsRepository.load(),
      ).thenAnswer((_) async => AppSettings());

      when(
        () => mockSettingsRepository.setFolderSort(any(), any()),
      ).thenAnswer((_) async {});

      mockDirectoryRepository = MockDirectoryRepository();
      when(
        () => mockDirectoryRepository.listDirectory(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockDirectoryRepository.watchDirectory(any()),
      ).thenAnswer((_) => const Stream.empty());

      mockMediaMetadataDatasource = MockMediaMetadataDatasource();
      when(
        () => mockMediaMetadataDatasource.extractAspectRatio(any()),
      ).thenAnswer((_) async => null);
      
      mockDirectorySizeDatasource = MockDirectorySizeDatasource();
      when(
        () => mockDirectorySizeDatasource.getDirectorySize(any()),
      ).thenAnswer((_) async => null);

      final mockDb = getMockDb();

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(mockDb),
          settingsRepositoryProvider.overrideWithValue(mockSettingsRepository),
          settingsProvider.overrideWith(MockSettingsNotifier.new),
          directoryRepositoryProvider.overrideWithValue(
            mockDirectoryRepository,
          ),
          mediaMetadataDatasourceProvider.overrideWithValue(
            mockMediaMetadataDatasource,
          ),
          directorySizeDatasourceProvider.overrideWithValue(
            mockDirectorySizeDatasource,
          ),
          pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
          tabManagerProvider.overrideWith(MockTabManager.new),
          tabIdProvider.overrideWithValue('tab_1'),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('IsSearchActiveNotifier set and toggle', () {
      final isSearchActive = container.read(isSearchActiveProvider);
      expect(isSearchActive, false);

      container.read(isSearchActiveProvider.notifier).set(true);
      expect(container.read(isSearchActiveProvider), true);

      // Early return logic test (does not crash or duplicate update)
      container.read(isSearchActiveProvider.notifier).set(true);
      expect(container.read(isSearchActiveProvider), true);

      container.read(isSearchActiveProvider.notifier).toggle();
      expect(container.read(isSearchActiveProvider), false);
    });

    test('IsAnalysisActiveNotifier set and toggle', () {
      expect(container.read(isAnalysisActiveProvider), false);

      container.read(isAnalysisActiveProvider.notifier).set(true);
      expect(container.read(isAnalysisActiveProvider), true);

      // Early return logic test
      container.read(isAnalysisActiveProvider.notifier).set(true);
      expect(container.read(isAnalysisActiveProvider), true);

      container.read(isAnalysisActiveProvider.notifier).toggle();
      expect(container.read(isAnalysisActiveProvider), false);
    });

    test('IsLocationEditingNotifier set and toggle', () {
      expect(container.read(isLocationEditingProvider), false);

      container.read(isLocationEditingProvider.notifier).set(true);
      expect(container.read(isLocationEditingProvider), true);

      // Early return logic test
      container.read(isLocationEditingProvider.notifier).set(true);
      expect(container.read(isLocationEditingProvider), true);

      container.read(isLocationEditingProvider.notifier).toggle();
      expect(container.read(isLocationEditingProvider), false);
    });

    test('CurrentPathNotifier gets and sets path', () {
      final initialPath = Platform.environment['HOME'] ?? '/';
      expect(container.read(currentPathProvider), initialPath);

      container.read(currentPathProvider.notifier).state = '/new/path';
      expect(container.read(currentPathProvider), '/new/path');
    });

    test('SearchQueryNotifier gets and sets query', () {
      expect(
        container.read(searchQueryProvider),
        '',
      ); // initial is null or empty, depending on tab state but gets mapped to string

      container.read(searchQueryProvider.notifier).state = 'hello';
      expect(container.read(searchQueryProvider), 'hello');
    });

    test('IsRefreshingNotifier sets refreshing state', () {
      expect(container.read(isRefreshingProvider), false);
      container.read(isRefreshingProvider.notifier).state = true;
      expect(container.read(isRefreshingProvider), true);
    });

    test('DirectoryItemsNotifier returns items from repository', () async {
      // Setup mock list
      final mockItems = [
        FileItem(
          path: '/test/a.txt',
          name: 'a.txt',
          type: FileItemType.other,
          modified: DateTime.now(),
        ),
        FileItem(
          path: '/test/.hidden',
          name: '.hidden',
          type: FileItemType.other,
          modified: DateTime.now(),
        ),
        FileItem(
          path: '/test/img.png',
          name: 'img.png',
          type: FileItemType.image,
          modified: DateTime.now(),
        ),
      ];
      when(
        () => mockDirectoryRepository.listDirectory(any()),
      ).thenAnswer((_) async => mockItems);
      when(
        () => mockMediaMetadataDatasource.extractAspectRatio(any()),
      ).thenAnswer((_) async => 1.5);

      // Override current path to a valid test path
      container.read(currentPathProvider.notifier).state =
          Platform.environment['HOME'] ?? '/';

      final itemsAsync = await container.read(directoryItemsProvider.future);
      expect(itemsAsync, isA<List<FileItem>>());
      expect(itemsAsync.length, 3);

      // Wait for the async metadata generator to finish
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Call refresh to test cache invalidation
      await container.read(directoryItemsProvider.notifier).refresh();
      await container.read(directoryItemsProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    test('State Providers basic getters and setters', () {
      expect(container.read(zoomProvider), <String, double>{});
      container.read(zoomProvider.notifier).state = {'/test': 1.5};
      expect(container.read(zoomProvider), {'/test': 1.5});

      container.read(currentPathProvider.notifier).state = '/test';
      expect(container.read(currentZoomProvider), 1.5);

      expect(container.read(isDraggingProvider), false);
      container.read(isDraggingProvider.notifier).state = true;
      expect(container.read(isDraggingProvider), true);

      expect(container.read(draggingPathsProvider), isEmpty);
      container.read(draggingPathsProvider.notifier).state = {'/test/a.txt'};
      expect(container.read(draggingPathsProvider), {'/test/a.txt'});

      expect(container.read(previewFileProvider), isNull);
      final fileItem = FileItem(
        path: '/test/a.txt',
        name: 'a.txt',
        type: FileItemType.other,
        modified: DateTime.now(),
      );
      container.read(previewFileProvider.notifier).state = fileItem;
      expect(container.read(previewFileProvider), fileItem);

      expect(container.read(isMarkerEditorActiveProvider), false);
      container.read(isMarkerEditorActiveProvider.notifier).state = true;
      expect(container.read(isMarkerEditorActiveProvider), true);

      expect(container.read(previewHudVisibleProvider), true);
      container.read(previewHudVisibleProvider.notifier).state = false;
      expect(container.read(previewHudVisibleProvider), false);

      expect(container.read(pathErrorProvider), isNull);
      container.read(pathErrorProvider.notifier).state = 'Error';
      expect(container.read(pathErrorProvider), 'Error');

      expect(container.read(isVirtualPathProvider), false);
      container.read(currentPathProvider.notifier).state = 'virtual:recent';
      expect(container.read(isVirtualPathProvider), true);

      expect(container.read(filterSettingsProvider), isA<FilterSettings>());
    });

    test('filteredDirectoryItemsProvider filters correctly', () async {
      final mockItems = [
        FileItem(
          path: '/test/a.txt',
          name: 'a.txt',
          type: FileItemType.other,
          modified: DateTime.now(),
        ),
        FileItem(
          path: '/test/.hidden',
          name: '.hidden',
          type: FileItemType.other,
          modified: DateTime.now(),
        ),
        FileItem(
          path: '/test/b.png',
          name: 'b.png',
          type: FileItemType.image,
          modified: DateTime.now(),
        ),
      ];

      final localContainer = ProviderContainer(
        overrides: [
          directoryItemsProvider.overrideWith(
            () => _FakeDirectoryItemsNotifier(mockItems),
          ),
          tabIdProvider.overrideWithValue('tab_1'),
          tabManagerProvider.overrideWith(MockTabManager.new),
          settingsProvider.overrideWith(MockSettingsNotifier.new),
          pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
        ],
      );

      await localContainer.read(directoryItemsProvider.future);

      // Test search query filtering
      localContainer.read(searchQueryProvider.notifier).state = 'a.txt';
      final filteredAsync = localContainer.read(filteredDirectoryItemsProvider);
      expect(filteredAsync.value?.length, 1);

      // Reset search
      localContainer.read(searchQueryProvider.notifier).state = '';
    });

    test('sortedDirectoryItemsProvider sorts correctly', () async {
      final mockItems = [
        FileItem(
          path: '/test/b.txt',
          name: 'b.txt',
          type: FileItemType.other,
          modified: DateTime.now(),
        ),
        FileItem(
          path: '/test/a.txt',
          name: 'a.txt',
          type: FileItemType.other,
          modified: DateTime.now(),
        ),
      ];

      final localContainer = ProviderContainer(
        overrides: [
          directoryItemsProvider.overrideWith(
            () => _FakeDirectoryItemsNotifier(mockItems),
          ),
          tabIdProvider.overrideWithValue('tab_1'),
          tabManagerProvider.overrideWith(MockTabManager.new),
          settingsProvider.overrideWith(MockSettingsNotifier.new),
          pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
        ],
      );

      await localContainer.read(directoryItemsProvider.future);
      await localContainer.read(pinnedItemsProvider.future);
      localContainer.read(sortedDirectoryItemsProvider); // start build
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final sortedAsync = localContainer.read(sortedDirectoryItemsProvider);
      if (sortedAsync.hasError) {
        print('Error in sortedAsync: ${sortedAsync.error}');
        print('StackTrace: ${sortedAsync.stackTrace}');
      }
      final sortedItems = sortedAsync.value;
      expect(sortedItems?.length, 2);
      expect(sortedItems?[0].name, 'a.txt'); // Should be sorted alphabetically
    });

    test('Infrastructure providers', () {
      expect(container.read(directoryWatcherProvider), isNotNull);
      expect(container.read(directoryCacheProvider), isNotNull);
      expect(container.read(localFileDatasourceProvider), isNotNull);
      expect(container.read(mediaMetadataDatasourceProvider), isNotNull);
      expect(container.read(directoryRepositoryProvider), isNotNull);
    });
    test('DirectoryItemsNotifier extra methods', () async {
      final mockItems = [
        FileItem(
          path: '/test/a.txt',
          name: 'a.txt',
          type: FileItemType.other,
          modified: DateTime.now(),
        ),
      ];
      final localContainer = ProviderContainer(
        overrides: [
          directoryRepositoryProvider.overrideWithValue(
            mockDirectoryRepository,
          ),
          mediaMetadataDatasourceProvider.overrideWithValue(
            mockMediaMetadataDatasource,
          ),
          tabIdProvider.overrideWithValue('tab_1'),
          tabManagerProvider.overrideWith(MockTabManager.new),
        ],
      );

      when(
        () => mockDirectoryRepository.listDirectory(any()),
      ).thenAnswer((_) async => mockItems);

      final notifier = localContainer.read(directoryItemsProvider.notifier);
      await localContainer.read(directoryItemsProvider.future);

      await notifier.refresh();
      verify(
        () => mockDirectoryRepository.listDirectory(any()),
      ).called(greaterThan(0));
    });

    test('sortedDirectoryItemsProvider extra sorts', () async {
      final now = DateTime.now();
      final mockItems = [
        FileItem(
          path: '/test/b.txt',
          name: 'b.txt',
          type: FileItemType.other,
          modified: now.subtract(const Duration(days: 1)),
          sizeBytes: 100,
        ),
        FileItem(
          path: '/test/a.txt',
          name: 'a.txt',
          type: FileItemType.folder,
          modified: now,
          sizeBytes: 200,
        ),
      ];

      final sortOptions = [
        SortOption.zToA,
        SortOption.firstModified,
        SortOption.lastModified,
        SortOption.sizeSmallToLarge,
        SortOption.sizeLargeToSmall,
        SortOption.filesFirst,
      ];

      for (final option in sortOptions) {
        final localContainer = ProviderContainer(
          overrides: [
            directoryItemsProvider.overrideWith(
              () => _FakeDirectoryItemsNotifier(mockItems),
            ),
            tabIdProvider.overrideWithValue('tab_1'),
            tabManagerProvider.overrideWith(MockTabManager.new),
            settingsProvider.overrideWith(MockSettingsNotifier.new),
            pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
            sortSettingsProvider.overrideWithValue(
              SortSettings(option: option),
            ),
          ],
        );

        await localContainer.read(directoryItemsProvider.future);
        await localContainer.read(pinnedItemsProvider.future);

        localContainer.read(sortedDirectoryItemsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        final sortedItems = localContainer
            .read(sortedDirectoryItemsProvider)
            .value;
        expect(sortedItems, isNotNull);
      }
    });

    test('RefreshCountNotifier tests', () {
      final localContainer = ProviderContainer(
        overrides: [
          tabIdProvider.overrideWithValue('tab_1'),
          tabManagerProvider.overrideWith(MockTabManager.new),
        ],
      );
      final notifier = localContainer.read(refreshCountProvider.notifier);
      expect(localContainer.read(refreshCountProvider), 0);

      notifier.state = 1; // triggers increment in TabManager
      expect(localContainer.read(tabManagerProvider).tabs[0].refreshCount, 1);

      notifier.update((curr) => curr + 1);
      expect(localContainer.read(tabManagerProvider).tabs[0].refreshCount, 2);
    });

    test('ItemKeysNotifier tests', () {
      final notifier = container.read(itemKeysProvider.notifier);
      expect(container.read(itemKeysProvider).isEmpty, true);

      final key = GlobalKey();
      notifier.register('/test/a', key);
      expect(container.read(itemKeysProvider)['/test/a'], key);

      notifier.update((curr) => {});
      expect(container.read(itemKeysProvider).isEmpty, true);
    });

    test('sortedDirectoryItemsProvider hidden files sorting (TDD)', () async {
      final now = DateTime.now();
      final mockItems = [
        FileItem(
          path: '/test/zebra.txt',
          name: 'zebra.txt',
          type: FileItemType.other,
          modified: now,
          sizeBytes: 100,
        ),
        FileItem(
          path: '/test/.hidden',
          name: '.hidden',
          type: FileItemType.other,
          modified: now,
          sizeBytes: 50,
        ),
        FileItem(
          path: '/test/apple.txt',
          name: 'apple.txt',
          type: FileItemType.other,
          modified: now,
          sizeBytes: 200,
        ),
      ];

      final localContainer = ProviderContainer(
        overrides: [
          directoryItemsProvider.overrideWith(
            () => _FakeDirectoryItemsNotifier(mockItems),
          ),
          tabIdProvider.overrideWithValue('tab_1'),
          tabManagerProvider.overrideWith(MockTabManager.new),
          settingsProvider.overrideWith(MockSettingsNotifier.new),
          pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
          sortSettingsProvider.overrideWithValue(
            SortSettings(),
          ),
        ],
      );

      await localContainer.read(directoryItemsProvider.future);
      await localContainer.read(pinnedItemsProvider.future);
      await localContainer.read(settingsProvider.future);
      localContainer.read(sortedDirectoryItemsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final sortedItems = localContainer.read(sortedDirectoryItemsProvider).value!;
      expect(sortedItems.length, 3);
      // Expected A-Z order (ignoring dot): apple.txt, .hidden, zebra.txt
      expect(sortedItems[0].name, 'apple.txt');
      expect(sortedItems[1].name, '.hidden');
      expect(sortedItems[2].name, 'zebra.txt');
    });

    test('DirectoryItemsNotifier asynchronously updates folder sizes (TDD)', () async {
      final now = DateTime.now();
      final mockItems = [
        FileItem(
          path: '/test/folder1',
          name: 'folder1',
          type: FileItemType.folder,
          modified: now,
        ),
      ];
      
      when(
        () => mockDirectoryRepository.listDirectory(any()),
      ).thenAnswer((_) async => mockItems);
      
      when(
        () => mockDirectorySizeDatasource.getDirectorySizes(['/test/folder1']),
      ).thenAnswer((_) async => {'/test/folder1': 9999});

      final localContainer = ProviderContainer(
        overrides: [
          directoryRepositoryProvider.overrideWithValue(
            mockDirectoryRepository,
          ),
          mediaMetadataDatasourceProvider.overrideWithValue(
            mockMediaMetadataDatasource,
          ),
          directorySizeDatasourceProvider.overrideWithValue(
            mockDirectorySizeDatasource,
          ),
          tabIdProvider.overrideWithValue('tab_1'),
          tabManagerProvider.overrideWith(MockTabManager.new),
        ],
      );

      final notifier = localContainer.read(directoryItemsProvider.notifier);
      final itemsAsync = await localContainer.read(directoryItemsProvider.future);
      expect(itemsAsync.length, 1);
      expect(itemsAsync[0].sizeBytes, null);
      
      // Wait for async generation
      await Future<void>.delayed(const Duration(milliseconds: 100));
      
      final updatedAsync = localContainer.read(directoryItemsProvider);
      expect(updatedAsync.value![0].sizeBytes, 9999);
    });

    test('DirectoryItemsNotifier awaits metadata generation when size sorting is active (TDD)', () async {
      final now = DateTime.now();
      final mockItems = [
        FileItem(
          path: '/test/folder1',
          name: 'folder1',
          type: FileItemType.folder,
          modified: now,
        ),
      ];
      
      when(
        () => mockDirectoryRepository.listDirectory(any()),
      ).thenAnswer((_) async => mockItems);
      
      when(
        () => mockDirectorySizeDatasource.getDirectorySizes(['/test/folder1']),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return {'/test/folder1': 9999};
      });

      final localContainer = ProviderContainer(
        overrides: [
          directoryRepositoryProvider.overrideWithValue(
            mockDirectoryRepository,
          ),
          mediaMetadataDatasourceProvider.overrideWithValue(
            mockMediaMetadataDatasource,
          ),
          directorySizeDatasourceProvider.overrideWithValue(
            mockDirectorySizeDatasource,
          ),
          tabIdProvider.overrideWithValue('tab_1'),
          tabManagerProvider.overrideWith(MockTabManager.new),
          sortSettingsProvider.overrideWithValue(
            SortSettings(option: SortOption.sizeLargeToSmall),
          ),
        ],
      );

      final itemsAsync = await localContainer.read(directoryItemsProvider.future);
      
      // Because size sorting is active and sizeBytes is null, it should have awaited the sizes
      expect(itemsAsync.length, 1);
      expect(itemsAsync[0].sizeBytes, 9999);
    });
  });
}

class _FakeDirectoryItemsNotifier extends DirectoryItemsNotifier {
  _FakeDirectoryItemsNotifier(this._items);
  final List<FileItem> _items;

  @override
  Future<List<FileItem>> build() async {
    return _items;
  }
}
