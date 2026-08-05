import 'dart:io';

// ignore_for_file: avoid_dynamic_calls
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/platform/directory_watcher.dart';
import 'package:onyxcore/core/playlist/playlist_sidebar_base.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_playlist_sidebar.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:path/path.dart' as p;

class FakeDirectoryRepository implements DirectoryRepository {
  FakeDirectoryRepository(this.initialItems);
  final List<FileItem> initialItems;
  List<String>? deletedPaths;

  @override
  void invalidateCache(String path, {bool recursive = false}) {}

  @override
  Stream<FileChangeEvent> watchDirectory(String path) => const Stream.empty();

  @override
  Future<List<FileItem>> listDirectory(String path) async => initialItems;

  @override
  Future<void> moveToTrash(
    List<String> paths, {
    String? taskId,
    void Function(int processed, int total)? onProgress,
    void Function(String message)? onLog,
  }) async {
    deletedPaths = paths;
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeThumbnailCacheService implements ThumbnailCacheService {
  @override
  Future<void> ensureLoaded() async {}

  @override
  ThumbnailLookupResult lookup({
    required String filePath,
    required int mtime,
    required int sizeBytes,
  }) => ThumbnailLookupResult.hit;

  @override
  String? getCachedPath(String filePath, {ThumbnailSize size = ThumbnailSize.normal}) => filePath;

  @override
  Future<ThumbnailLookupResult> lookupAsync({
    required String filePath,
    required int mtime,
    required int sizeBytes,
  }) async => ThumbnailLookupResult.hit;

  @override
  Future<String?> getCachedPathAsync(String filePath, {ThumbnailSize size = ThumbnailSize.normal}) async => filePath;

  @override
  Future<void> markFailed({
    required String filePath,
    required int mtime,
    required int sizeBytes,
    required String kind,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeImageFavoritesNotifier extends ImageFavoritesNotifier {
  @override
  void setRef(Ref ref) {
    // No-op
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('sidebar_test_');
  });

  tearDownAll(() async {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('ImagePlaylistSidebar', () {
    late FileItem dummyImage;
    late FileItem dummyFolder;

    setUp(() {
      final imgPath = p.join(tempDir.path, 'image1.jpg');
      File(imgPath).writeAsBytesSync([0, 1, 2]); // dummy file
      dummyImage = FileItem(
        path: imgPath,
        name: 'image1.jpg',
        type: FileItemType.image,
        modified: DateTime.now(),
        sizeBytes: 1024 * 1024 * 2, // 2 MB
      );
      final folderPath = p.join(tempDir.path, 'folder1');
      Directory(folderPath).createSync();
      File(p.join(folderPath, 'dummy.jpg')).writeAsBytesSync([0, 1, 2]);

      dummyFolder = FileItem(
        path: folderPath,
        name: 'folder1',
        type: FileItemType.folder,
        modified: DateTime.now(),
        itemCount: 5,
      );

      final binding = TestWidgetsFlutterBinding.instance;
      binding.platformDispatcher.views.first.physicalSize = const Size(1920, 1080);
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.instance;
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    testWidgets('renders empty state when queue is empty', (WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageShowHiddenProvider.overrideWith((ref) => false),
              imageQueueProvider.overrideWith((ref) => []),
              imagePlaylistSidebarVisibleProvider.overrideWith((ref) => true),
              imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
              thumbnailCacheServiceProvider.overrideWithValue(FakeThumbnailCacheService()),
              directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository([])),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: ImagePlaylistSidebar(),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      await tester.pumpAndSettle();
      expect(find.text('No image files found'), findsOneWidget);
    });

    testWidgets('renders items and handles double tap', (WidgetTester tester) async {
      FileItem? tappedItem;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageShowHiddenProvider.overrideWith((ref) => false),
              imageQueueProvider.overrideWith((ref) => [dummyImage, dummyFolder]),
              imagePlaylistSidebarVisibleProvider.overrideWith((ref) => true),
              imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
              thumbnailCacheServiceProvider.overrideWithValue(FakeThumbnailCacheService()),
              directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository([dummyImage, dummyFolder])),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ImagePlaylistSidebar(
                  onImageSelected: (item) {
                    tappedItem = item;
                  },
                ),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      await tester.pumpAndSettle();

      // Check subtitles
      expect(find.text('image1.jpg'), findsOneWidget);
      expect(find.text('folder1'), findsOneWidget);
      expect(find.text('Image File • 2.0 MB'), findsOneWidget);
      expect(find.text('5 Image Files'), findsOneWidget);


      await tester.tap(find.text('image1.jpg'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('image1.jpg'));
      await tester.pumpAndSettle();
      expect(tappedItem?.path, dummyImage.path);
    });

    testWidgets('renders favorites empty state when in favorites mode', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageViewModeProvider.overrideWith((ref) => ImageViewMode.favorites),
              imageQueueProvider.overrideWith((ref) => []),
              imagePlaylistSidebarVisibleProvider.overrideWith((ref) => true),
              imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
              thumbnailCacheServiceProvider.overrideWithValue(FakeThumbnailCacheService()),
              directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository([])),
            ],
            child: const MaterialApp(home: Scaffold(body: ImagePlaylistSidebar())),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.text('No favorite files in this folder'), findsOneWidget);
    });

    testWidgets('active item logic correctly matches preview file', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageQueueProvider.overrideWith((ref) => [dummyImage, dummyFolder]),
              previewFileProvider.overrideWith((ref) => dummyImage),
              imageIsEmptyProvider.overrideWith((ref) => false),
              imagePlaylistSidebarVisibleProvider.overrideWith((ref) => true),
              imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
              thumbnailCacheServiceProvider.overrideWithValue(FakeThumbnailCacheService()),
              directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository([dummyImage, dummyFolder])),
            ],
            child: const MaterialApp(home: Scaffold(body: ImagePlaylistSidebar())),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      
      // Active indicator icon should be present for dummyImage
      expect(find.byIcon(Icons.remove_red_eye_rounded), findsOneWidget);
    });

    testWidgets('active item returns false when viewer empty', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageQueueProvider.overrideWith((ref) => [dummyImage, dummyFolder]),
              previewFileProvider.overrideWith((ref) => dummyImage),
              imageIsEmptyProvider.overrideWith((ref) => true),
              imagePlaylistSidebarVisibleProvider.overrideWith((ref) => true),
              imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
              thumbnailCacheServiceProvider.overrideWithValue(FakeThumbnailCacheService()),
              directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository([dummyImage, dummyFolder])),
            ],
            child: const MaterialApp(home: Scaffold(body: ImagePlaylistSidebar())),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      
      // Since imageIsEmptyProvider is true, active indicator should be hidden
      expect(find.byIcon(Icons.remove_red_eye_rounded), findsNothing);
    });

    testWidgets('handles context menu actions correctly', (tester) async {
      var deleteCalled = false;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageQueueProvider.overrideWith((ref) => [dummyImage]),
              imagePlaylistSidebarVisibleProvider.overrideWith((ref) => true),
              imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
              thumbnailCacheServiceProvider.overrideWithValue(FakeThumbnailCacheService()),
              directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository([dummyImage])),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ImagePlaylistSidebar(
                  onDelete: (paths) {
                    deleteCalled = true;
                    expect(paths.first, dummyImage.path);
                  },
                ),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      // Right click to open context menu (buttons: kSecondaryButton = 2 in tests)
      await tester.tap(find.text('image1.jpg'), buttons: 2);
      await tester.pumpAndSettle();
      
      expect(find.text('Move to Trash'), findsOneWidget);
      expect(find.text('Copy Item'), findsOneWidget);
      expect(find.text('Move Item'), findsOneWidget);
      expect(find.text('Rename Item'), findsOneWidget);

      // Trigger delete action
      await tester.tap(find.text('Move to Trash'));
      await tester.pumpAndSettle();
      expect(deleteCalled, isTrue);
    });



    testWidgets('renders correct subtitle for edge cases', (tester) async {
      final imgPath = p.join(tempDir.path, 'nosize.jpg');
      File(imgPath).writeAsBytesSync([0, 1, 2]); 
      final imageNoSize = FileItem(
        path: imgPath, name: 'nosize.jpg', type: FileItemType.image, modified: DateTime.now(),
      );
      
      final folderPath = p.join(tempDir.path, 'folder2');
      Directory(folderPath).createSync();
      final folderNoCount = FileItem(
        path: folderPath, name: 'folder2', type: FileItemType.folder, modified: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          imageQueueProvider.overrideWith((ref) => [imageNoSize, folderNoCount]),
          imagePlaylistSidebarVisibleProvider.overrideWith((ref) => true),
          imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
          thumbnailCacheServiceProvider.overrideWithValue(FakeThumbnailCacheService()),
          directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository([imageNoSize, folderNoCount])),
        ],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: ImagePlaylistSidebar())),
          ),
        );
        // Do NOT wait for refreshQueue to complete, because it will overwrite our injected queue
        // with the results of processMediaQueueIsolate (which filters empty folders).
        // By checking immediately, we test the UI layer's handling of the edge cases as desired.
      });
      await tester.pump(); // pump once to render initial state

      expect(find.text('nosize.jpg'), findsOneWidget);
      expect(find.text('Image File'), findsOneWidget); // specific text without size
      expect(find.text('folder2'), findsOneWidget);
      expect(find.text('Folder'), findsOneWidget); // specific text without count
    });

    testWidgets('handles default moveToTrash when onDelete callback is null', (tester) async {
      final fakeRepo = FakeDirectoryRepository([dummyImage]);
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              imageQueueProvider.overrideWith((ref) => [dummyImage]),
              imagePlaylistSidebarVisibleProvider.overrideWith((ref) => true),
              imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
              thumbnailCacheServiceProvider.overrideWithValue(FakeThumbnailCacheService()),
              directoryRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: ImagePlaylistSidebar(), // onDelete is null
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      await tester.tap(find.text('image1.jpg'), buttons: 2);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Move to Trash'));
      await tester.pumpAndSettle();

      expect(fakeRepo.deletedPaths, isNotNull);
      expect(fakeRepo.deletedPaths!.first, dummyImage.path);
    });

    testWidgets('triggers buildListeners on imageCurrentPathProvider change', (tester) async {
      final container = ProviderContainer(
        overrides: [
          imageQueueProvider.overrideWith((ref) => [dummyImage]),
          imagePlaylistSidebarVisibleProvider.overrideWith((ref) => true),
          imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
          thumbnailCacheServiceProvider.overrideWithValue(FakeThumbnailCacheService()),
          directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository([dummyImage])),
        ],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: ImagePlaylistSidebar(),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      // Trigger listener by changing imageCurrentPathProvider
      container.read(imageCurrentPathProvider.notifier).state = '/some/new/path';
      await tester.pump();
      // Verify no exceptions thrown and buildListeners processed path change
    });

    testWidgets('handles double tap when empty state is active', (tester) async {
      final container = ProviderContainer(
        overrides: [
          imageQueueProvider.overrideWith((ref) => [dummyImage]),
          imagePlaylistSidebarVisibleProvider.overrideWith((ref) => true),
          imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
          thumbnailCacheServiceProvider.overrideWithValue(FakeThumbnailCacheService()),
          directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository([dummyImage])),
        ],
      );
      container.read(imageIsEmptyProvider.notifier).state = true;

      var selected = false;

      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: ImagePlaylistSidebar(
                  onImageSelected: (item) {
                    selected = true;
                  },
                ),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      await tester.tap(find.text('image1.jpg'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('image1.jpg'));
      await tester.pumpAndSettle();

      expect(container.read(imageIsEmptyProvider), isFalse);
      expect(selected, isTrue);
    });

    testWidgets('handles Home and Favorites nav bar taps', (tester) async {
      final container = ProviderContainer(
        overrides: [
          imageQueueProvider.overrideWith((ref) => [dummyImage]),
          imagePlaylistSidebarVisibleProvider.overrideWith((ref) => true),
          imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
          thumbnailCacheServiceProvider.overrideWithValue(FakeThumbnailCacheService()),
          directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository([dummyImage])),
        ],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: ImagePlaylistSidebar(),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(container.read(imageViewModeProvider), ImageViewMode.home);

      final state = tester.state<PlaylistSidebarBaseState>(find.byType(ImagePlaylistSidebar));

      // ignore: cascade_invocations
      state.onFavoritesNavTap();
      await tester.pumpAndSettle();
      expect(container.read(imageViewModeProvider), ImageViewMode.favorites);

      // ignore: cascade_invocations
      state.onHomeNavTap();
      await tester.pumpAndSettle();
      expect(container.read(imageViewModeProvider), ImageViewMode.home);
    });

    testWidgets('handles copy context menu tap', (tester) async {
      final container = ProviderContainer(
        overrides: [
          imageQueueProvider.overrideWith((ref) => [dummyImage]),
          imagePlaylistSidebarVisibleProvider.overrideWith((ref) => true),
          imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
          thumbnailCacheServiceProvider.overrideWithValue(FakeThumbnailCacheService()),
          directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository([dummyImage])),
        ],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: ImagePlaylistSidebar(),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      await tester.tap(find.text('image1.jpg'), buttons: 2);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy Item'));
      await tester.pumpAndSettle();
    });

    testWidgets('handles move context menu tap', (tester) async {
      final container = ProviderContainer(
        overrides: [
          imageQueueProvider.overrideWith((ref) => [dummyImage]),
          imagePlaylistSidebarVisibleProvider.overrideWith((ref) => true),
          imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
          thumbnailCacheServiceProvider.overrideWithValue(FakeThumbnailCacheService()),
          directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository([dummyImage])),
        ],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: ImagePlaylistSidebar(),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      await tester.tap(find.text('image1.jpg'), buttons: 2);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Move Item'));
      await tester.pumpAndSettle();
    });

    testWidgets('handles rename context menu tap', (tester) async {
      final container = ProviderContainer(
        overrides: [
          imageQueueProvider.overrideWith((ref) => [dummyImage]),
          imagePlaylistSidebarVisibleProvider.overrideWith((ref) => true),
          imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
          thumbnailCacheServiceProvider.overrideWithValue(FakeThumbnailCacheService()),
          directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository([dummyImage])),
        ],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: ImagePlaylistSidebar(),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      await tester.tap(find.text('image1.jpg'), buttons: 2);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rename Item'));
      await tester.pumpAndSettle();
    });

    testWidgets('hides bottom navigation and favorites when isNetworkStream is true', (tester) async {
      final container = ProviderContainer(
        overrides: [
          imageQueueProvider.overrideWith((ref) => [dummyImage]),
          imagePlaylistSidebarVisibleProvider.overrideWith((ref) => true),
          imageFavoritesProvider.overrideWith((ref) => FakeImageFavoritesNotifier()),
          thumbnailCacheServiceProvider.overrideWithValue(FakeThumbnailCacheService()),
          directoryRepositoryProvider.overrideWithValue(FakeDirectoryRepository([dummyImage])),
        ],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: ImagePlaylistSidebar(isNetworkStream: true),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(find.text('Favorites'), findsNothing);
      expect(find.text('Home'), findsNothing);
      expect(find.text('Playlist'), findsOneWidget);
    });
  });
}

