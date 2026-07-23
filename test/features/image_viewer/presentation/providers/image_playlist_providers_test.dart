import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
class TestImageFavoritesNotifier extends ImageFavoritesNotifier {
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  void updateFavorites(Set<String> favs) => state = favs;
}

void main() {
  group('Image Playlist Providers', () {
    test('default states are correct', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(imageViewModeProvider), ImageViewMode.home);
      expect(container.read(imageCurrentPathProvider), '');
      expect(container.read(imageRootPathProvider), '');
      expect(container.read(imagePathHistoryProvider), <String>[]);
      expect(container.read(imagePathForwardHistoryProvider), <String>[]);
      expect(container.read(imageSelectionProvider), <String>{});
      expect(container.read(imageSelectionAnchorProvider), null);
      expect(container.read(imageQueueProvider), <FileItem>[]);
      expect(container.read(imagePlayingQueueProvider), <FileItem>[]);
      expect(container.read(activeImageIndexProvider), 0);
      expect(container.read(imageIsReloadingProvider), false);
      expect(container.read(imagePlaylistSidebarVisibleProvider), false);
      expect(container.read(imagePlaylistSidebarWidthProvider), null);
      expect(container.read(isImagePlaylistSidebarDraggingProvider), false);
      expect(container.read(imageSortOptionProvider), null);
      expect(container.read(imageSearchQueryProvider), '');
      expect(container.read(imageIsEmptyProvider), false);
      expect(container.read(imageRestartSignalProvider), 0);
    });

    test('currentImageProvider returns correct item', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final item1 = FileItem(path: '/test/1.jpg', name: '1.jpg', type: FileItemType.image, modified: DateTime.now());
      final item2 = FileItem(path: '/test/2.jpg', name: '2.jpg', type: FileItemType.image, modified: DateTime.now());

      expect(container.read(currentImageProvider), null);

      container.read(imagePlayingQueueProvider.notifier).state = [item1, item2];
      expect(container.read(currentImageProvider), item1);

      container.read(activeImageIndexProvider.notifier).state = 1;
      expect(container.read(currentImageProvider), item2);

      container.read(activeImageIndexProvider.notifier).state = 5;
      expect(container.read(currentImageProvider), null);
    });

    test('filteredAndSortedImageQueueProvider applies search, sort, and favorites filter', () {
      final container = ProviderContainer(
        overrides: [
          imageFavoritesProvider.overrideWith((ref) => TestImageFavoritesNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final date = DateTime.now();
      final item1 = FileItem(path: '/test/a.jpg', name: 'a.jpg', type: FileItemType.image, modified: date);
      final item2 = FileItem(path: '/test/b.jpg', name: 'b.jpg', type: FileItemType.image, modified: date.add(const Duration(days: 1)));
      final item3 = FileItem(path: '/test/c.png', name: 'c.png', type: FileItemType.image, modified: date.add(const Duration(days: 2)));

      container.read(imageQueueProvider.notifier).state = [item2, item1, item3];

      expect(container.read(filteredAndSortedImageQueueProvider), [item2, item1, item3]);

      container.read(imageSearchQueryProvider.notifier).state = 'png';
      expect(container.read(filteredAndSortedImageQueueProvider), [item3]);
      container.read(imageSearchQueryProvider.notifier).state = '';

      container.read(imageSortOptionProvider.notifier).state = SortOption.aToZ;
      expect(container.read(filteredAndSortedImageQueueProvider), [item1, item2, item3]);

      (container.read(imageFavoritesProvider.notifier) as TestImageFavoritesNotifier).updateFavorites({'/test/b.jpg'});
      container.read(imageViewModeProvider.notifier).state = ImageViewMode.favorites;
      expect(container.read(filteredAndSortedImageQueueProvider), [item2]);
    });

    test('imagePlaylistProviderConfig is properly initialized', () {
      final config = imagePlaylistProviderConfig;
      
      expect(config.currentPathProvider, imageCurrentPathProvider);
      expect(config.rootPathProvider, imageRootPathProvider);
      expect(config.pathHistoryProvider, imagePathHistoryProvider);
      expect(config.pathForwardHistoryProvider, imagePathForwardHistoryProvider);
      expect(config.showHiddenProvider, imageShowHiddenProvider);
      expect(config.selectionProvider, imageSelectionProvider);
      expect(config.selectionAnchorProvider, imageSelectionAnchorProvider);
      expect(config.queueProvider, imageQueueProvider);
      expect(config.isReloadingProvider, imageIsReloadingProvider);
      expect(config.sortOptionProvider, imageSortOptionProvider);
      expect(config.searchQueryProvider, imageSearchQueryProvider);
      expect(config.filteredAndSortedQueueProvider, filteredAndSortedImageQueueProvider);
      expect(config.viewModeProvider, imageViewModeProvider);
      expect(config.favoritesValue, ImageViewMode.favorites);
    });
  });
}
