import 'dart:io';

// ignore_for_file: avoid_dynamic_calls
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/platform/directory_watcher.dart';
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

  @override
  void invalidateCache(String path, {bool recursive = false}) {}

  @override
  Stream<FileChangeEvent> watchDirectory(String path) => const Stream.empty();

  @override
  Future<List<FileItem>> listDirectory(String path) async => initialItems;
  
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
      expect(find.text('1 Image File'), findsOneWidget);

      await tester.tap(find.text('image1.jpg'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('image1.jpg'));
      await tester.pumpAndSettle();
      expect(tappedItem?.path, dummyImage.path);
    });

      });
}
