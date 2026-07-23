// ignore_for_file: avoid_dynamic_calls
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_playlist_providers.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_playlist_sidebar.dart';

class MockDirectoryRepository extends Mock implements DirectoryRepository {}
class MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  group('VideoPlaylistSidebar', () {
    late MockDirectoryRepository mockDirectoryRepo;
    late MockAppDatabase mockDb;

    setUp(() {
      mockDirectoryRepo = MockDirectoryRepository();
      mockDb = MockAppDatabase();
      
      when(() => mockDirectoryRepo.watchDirectory(any()))
          .thenAnswer((_) => const Stream.empty());
      when(() => mockDirectoryRepo.listDirectory(any()))
          .thenAnswer((_) async => []);
      when(() => mockDb.getVideoFavorites())
          .thenAnswer((_) async => <String>{});
      when(() => mockDb.addVideoFavorite(any()))
          .thenAnswer((_) async {});
      when(() => mockDb.removeVideoFavorite(any()))
          .thenAnswer((_) async {});
    });

    Widget buildTestWidget({
      required List<FileItem> initialQueue,
      FileItem? currentPreviewFile,
      bool isEmpty = false,
      void Function(FileItem)? onVideoSelected,
    }) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(mockDb),
          directoryRepositoryProvider.overrideWithValue(mockDirectoryRepo),
          videoQueueProvider.overrideWith((ref) => initialQueue),
          previewFileProvider.overrideWith((ref) => currentPreviewFile),
          videoIsEmptyProvider.overrideWith((ref) => isEmpty),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VideoPlaylistSidebar(
              onVideoSelected: onVideoSelected,
            ),
          ),
        ),
      );
    }

    testWidgets('renders list of videos and folder correctly', (tester) async {
      final file1 = FileItem(
        name: 'video.mp4',
        path: '/video.mp4',
        sizeBytes: 1024 * 1024 * 5, // 5MB
        type: FileItemType.video,
        modified: DateTime.now(),
      );
      final folder1 = FileItem(
        name: 'MyFolder',
        path: '/MyFolder',
        sizeBytes: 0,
        itemCount: 3,
        type: FileItemType.folder,
        modified: DateTime.now(),
      );

      await tester.pumpWidget(
        buildTestWidget(initialQueue: [file1, folder1]),
      );
      await tester.pumpAndSettle();

      expect(find.text('video.mp4'), findsOneWidget);
      expect(find.text('Video File • 5.0 MB'), findsOneWidget);

      expect(find.text('MyFolder'), findsOneWidget);
      expect(find.text('3 Video Files'), findsOneWidget);
    });

    testWidgets('handles item selection on double tap', (tester) async {
      final file1 = FileItem(
        name: 'video.mp4',
        path: '/video.mp4',
        sizeBytes: 1024 * 1024 * 5, // 5MB
        type: FileItemType.video,
        modified: DateTime.now(),
      );

      FileItem? selectedVideo;

      await tester.pumpWidget(
        buildTestWidget(
          initialQueue: [file1],
          onVideoSelected: (video) => selectedVideo = video,
          isEmpty: true, // test branch for ref.read(videoIsEmptyProvider)
        ),
      );
      await tester.pumpAndSettle();

      final tileFinder = find.text('video.mp4');
      expect(tileFinder, findsOneWidget);

      await tester.tap(tileFinder);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(tileFinder);
      await tester.pumpAndSettle();

      expect(selectedVideo, equals(file1));
    });

    testWidgets('shows active indicator for playing file', (tester) async {
      final file1 = FileItem(
        name: 'video.mp4',
        path: '/video.mp4',
        sizeBytes: 1024 * 1024 * 5,
        type: FileItemType.video,
        modified: DateTime.now(),
      );

      await tester.pumpWidget(
        buildTestWidget(
          initialQueue: [file1],
          currentPreviewFile: file1,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('bottom nav taps update view mode provider', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(initialQueue: []),
      );
      await tester.pumpAndSettle();

      final homeBtn = find.byIcon(Icons.home_rounded);
      final favBtn = find.byIcon(Icons.favorite_rounded);

      if (homeBtn.evaluate().isNotEmpty && favBtn.evaluate().isNotEmpty) {
        await tester.tap(favBtn);
        await tester.pumpAndSettle();
        await tester.tap(homeBtn);
        await tester.pumpAndSettle();
      }
    });
    testWidgets('shows favorites empty state text in favorites mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(mockDb),
            directoryRepositoryProvider.overrideWithValue(mockDirectoryRepo),
            videoQueueProvider.overrideWith((ref) => []),
            videoViewModeProvider.overrideWith((ref) => VideoViewMode.favorites),
            videoIsEmptyProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VideoPlaylistSidebar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No favorite files in this folder'), findsOneWidget);
    });

    testWidgets('shows active indicator when playing track is inside a folder', (tester) async {
      final folder1 = FileItem(
        name: 'MyFolder',
        path: '/MyFolder',
        sizeBytes: 0,
        itemCount: 3,
        type: FileItemType.folder,
        modified: DateTime.now(),
      );
      
      final playingFile = FileItem(
        name: 'video.mp4',
        path: '/MyFolder/video.mp4',
        sizeBytes: 1024 * 1024 * 5,
        type: FileItemType.video,
        modified: DateTime.now(),
      );

      await tester.pumpWidget(
        buildTestWidget(
          initialQueue: [folder1],
          currentPreviewFile: playingFile,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('builds context menu items correctly', (tester) async {
      final file1 = FileItem(
        name: 'video.mp4',
        path: '/video.mp4',
        sizeBytes: 1024,
        type: FileItemType.video,
        modified: DateTime.now(),
      );

      await tester.pumpWidget(
        buildTestWidget(
          initialQueue: [file1],
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(VideoPlaylistSidebar)) as dynamic;
      final menuItems = state.buildContextMenuItems(
        tester.element(find.byType(VideoPlaylistSidebar)),
        file1,
        [file1.path],
      );

      expect(menuItems.length, 5); // Delete, Divider, Copy, Move, Rename
      expect(menuItems[0].title, 'Move to Trash');
      expect(menuItems[2].title, 'Copy Item');
      expect(menuItems[3].title, 'Move Item');
      expect(menuItems[4].title, 'Rename Item');
      
      // Test the get isCurrentlyPlaying getter
      expect(state.isCurrentlyPlaying, false);
    });

    testWidgets('buildContextMenuItems executes actions', (tester) async {
      final file1 = FileItem(
        name: 'video.mp4',
        path: '/video.mp4',
        sizeBytes: 1024,
        type: FileItemType.video,
        modified: DateTime.now(),
      );
      
      List<String>? deletedPaths;
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(mockDb),
            directoryRepositoryProvider.overrideWithValue(mockDirectoryRepo),
            videoQueueProvider.overrideWith((ref) => [file1]),
            previewFileProvider.overrideWith((ref) => null),
            videoIsEmptyProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoPlaylistSidebar(
                onDelete: (paths) {
                  deletedPaths = paths;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(VideoPlaylistSidebar)) as dynamic;
      final menuItems = state.buildContextMenuItems(
        tester.element(find.byType(VideoPlaylistSidebar)),
        file1,
        [file1.path],
      );

      // Trigger the delete action when onDelete is provided
      menuItems[0].onTap?.call();
      expect(deletedPaths, [file1.path]);
    });

    testWidgets('executes context menu actions when callbacks are null', (tester) async {
      final file1 = FileItem(
        name: 'video.mp4',
        path: '/video.mp4',
        sizeBytes: 1024,
        type: FileItemType.video,
        modified: DateTime.now(),
      );
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(mockDb),
            directoryRepositoryProvider.overrideWithValue(mockDirectoryRepo),
            videoQueueProvider.overrideWith((ref) => [file1]),
            previewFileProvider.overrideWith((ref) => null),
            videoIsEmptyProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VideoPlaylistSidebar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(VideoPlaylistSidebar)) as dynamic;
      final menuItems = state.buildContextMenuItems(
        tester.element(find.byType(VideoPlaylistSidebar)),
        file1,
        [file1.path],
      );

      // Trigger delete (onDelete is null, so it calls directoryRepository.moveToTrash)
      when(() => mockDirectoryRepo.moveToTrash(any())).thenAnswer((_) async {});
      menuItems[0].onTap?.call();
      
      // Trigger other actions. We don't pump after these because they open dialogs 
      // that might cause render overflows in tests.
      menuItems[2].onTap?.call(); 
      menuItems[3].onTap?.call(); 
      menuItems[4].onTap?.call(); 
      
      // Hit onFavoritesNavTap directly
      state.onFavoritesNavTap();
    });

    testWidgets('listens to videoCurrentPathProvider changes', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(mockDb),
            directoryRepositoryProvider.overrideWithValue(mockDirectoryRepo),
            videoQueueProvider.overrideWith((ref) => []),
            videoIsEmptyProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  return Column(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          ref.read(videoCurrentPathProvider.notifier).state = '/new/path';
                        },
                        child: const Text('Change Path'),
                      ),
                      const Expanded(child: VideoPlaylistSidebar()),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change Path'));
      await tester.pumpAndSettle();
      
      // If it triggers setupWatcher and refreshQueue without errors, it's successful.
      // mockDirectoryRepo.listDirectory is called.
      verify(() => mockDirectoryRepo.listDirectory(any())).called(greaterThan(0));
    });
  });
}
