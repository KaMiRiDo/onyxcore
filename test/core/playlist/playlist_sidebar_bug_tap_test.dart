import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/playlist/playlist_sidebar_base.dart';
import 'package:onyxcore/core/playlist/playlist_providers.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';

class TestPlaylistSidebar extends PlaylistSidebarBase {
  bool doubleTapCalled = false;

  TestPlaylistSidebar({super.key})
      : super(
          config: PlaylistProviderConfig(
            currentPathProvider: StateProvider((ref) => '/tmp'),
            rootPathProvider: StateProvider((ref) => '/tmp'),
            pathHistoryProvider: StateProvider((ref) => []),
            pathForwardHistoryProvider: StateProvider((ref) => []),
            showHiddenProvider: StateProvider((ref) => false),
            selectionProvider: StateProvider((ref) => {}),
            selectionAnchorProvider: StateProvider((ref) => null),
            queueProvider: StateProvider((ref) => [
              FileItem(
                path: '/tmp/test.jpg',
                name: 'test.jpg',
                type: FileItemType.image,
                modified: DateTime.now(),
                accessed: DateTime.now(),
              )
            ]),
            isReloadingProvider: StateProvider((ref) => false),
            sortOptionProvider: StateProvider((ref) => SortOption.aToZ),
            searchQueryProvider: StateProvider((ref) => ''),
            filteredAndSortedQueueProvider: Provider((ref) => [
              FileItem(
                path: '/tmp/test.jpg',
                name: 'test.jpg',
                type: FileItemType.image,
                modified: DateTime.now(),
                accessed: DateTime.now(),
              )
            ]),
            viewModeProvider: StateProvider((ref) => 0),
            favoritesValue: 1,
          ),
          itemBuilder: (context, item, isSelected, isCurrentlyPlaying, onToggleFavorite, isFavorite) {
            return ListTile(title: Text(item.name));
          },
        );

  @override
  void onItemDoubleTap(FileItem item, int realIndex, List<FileItem> queue) {
    doubleTapCalled = true;
  }
}

void main() {
  testWidgets('Playlist single tap should trigger double tap behavior for media playback', (WidgetTester tester) async {
    final sidebar = TestPlaylistSidebar();
    
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: sidebar,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    
    // Tap the item in the list
    await tester.tap(find.text('test.jpg'));
    await tester.pumpAndSettle();
    
    expect(sidebar.doubleTapCalled, true, reason: 'Single tap should call onItemDoubleTap to play the media');
  });
}
