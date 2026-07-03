import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/playlist/playlist_providers.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io' as import_io;

void main() {
  group('sortAndFilterQueue', () {
    final now = DateTime.now();
    final itemA = FileItem(name: 'A.mp3', path: '/A.mp3', type: FileItemType.audio, modified: now.subtract(const Duration(days: 1)), sizeBytes: 100);
    final itemB = FileItem(name: 'B.mp3', path: '/B.mp3', type: FileItemType.audio, modified: now.subtract(const Duration(days: 2)), sizeBytes: 200);
    final folder1 = FileItem(name: 'ZFolder', path: '/ZFolder', type: FileItemType.folder, modified: now, sizeBytes: null);
    final itemC = FileItem(name: 'C.mp3', path: '/C.mp3', type: FileItemType.audio, modified: now.subtract(const Duration(days: 3)), sizeBytes: 50);

    final queue = [itemA, itemB, folder1, itemC];

    test('returns original queue when no filters or sort are applied', () {
      final result = sortAndFilterQueue(
        queue: queue,
        searchQuery: '',
        sortOption: null,
        isFavoritesMode: false,
        favorites: {},
      );

      expect(result, queue);
    });

    test('filters by search query', () {
      final result = sortAndFilterQueue(
        queue: queue,
        searchQuery: 'a.mp3',
        sortOption: null,
        isFavoritesMode: false,
        favorites: {},
      );

      expect(result.length, 1);
      expect(result.first, itemA);
    });

    test('filters by favorites mode', () {
      final result = sortAndFilterQueue(
        queue: queue,
        searchQuery: '',
        sortOption: null,
        isFavoritesMode: true,
        favorites: {'/B.mp3', '/ZFolder'},
      );

      expect(result.length, 2);
      expect(result, containsAll([itemB, folder1]));
    });

    test('sorts by A-Z (folders first)', () {
      final result = sortAndFilterQueue(
        queue: queue,
        searchQuery: '',
        sortOption: SortOption.aToZ,
        isFavoritesMode: false,
        favorites: {},
      );

      expect(result.length, 4);
      // Folders always first unless SortOption.filesFirst
      expect(result[0], folder1);
      expect(result[1], itemA);
      expect(result[2], itemB);
      expect(result[3], itemC);
    });

    test('sorts by Z-A (folders first)', () {
      final result = sortAndFilterQueue(
        queue: queue,
        searchQuery: '',
        sortOption: SortOption.zToA,
        isFavoritesMode: false,
        favorites: {},
      );

      expect(result.length, 4);
      expect(result[0], folder1);
      expect(result[1], itemC);
      expect(result[2], itemB);
      expect(result[3], itemA);
    });

    test('sorts by size small to large (folders first)', () {
      final result = sortAndFilterQueue(
        queue: queue,
        searchQuery: '',
        sortOption: SortOption.sizeSmallToLarge,
        isFavoritesMode: false,
        favorites: {},
      );

      expect(result[0], folder1);
      expect(result[1], itemC); // 50
      expect(result[2], itemA); // 100
      expect(result[3], itemB); // 200
    });

    test('sorts by size large to small (folders first)', () {
      final result = sortAndFilterQueue(
        queue: queue,
        searchQuery: '',
        sortOption: SortOption.sizeLargeToSmall,
        isFavoritesMode: false,
        favorites: {},
      );

      expect(result[0], folder1);
      expect(result[1], itemB); // 200
      expect(result[2], itemA); // 100
      expect(result[3], itemC); // 50
    });

    test('sorts by last modified (folders first)', () {
      final result = sortAndFilterQueue(
        queue: queue,
        searchQuery: '',
        sortOption: SortOption.lastModified,
        isFavoritesMode: false,
        favorites: {},
      );

      expect(result[0], folder1);
      expect(result[1], itemA); // -1 day
      expect(result[2], itemB); // -2 days
      expect(result[3], itemC); // -3 days
    });

    test('sorts by first modified (folders first)', () {
      final result = sortAndFilterQueue(
        queue: queue,
        searchQuery: '',
        sortOption: SortOption.firstModified,
        isFavoritesMode: false,
        favorites: {},
      );

      expect(result[0], folder1);
      expect(result[1], itemC); // -3 days
      expect(result[2], itemB); // -2 days
      expect(result[3], itemA); // -1 day
    });

    test('sorts by files first', () {
      final result = sortAndFilterQueue(
        queue: queue,
        searchQuery: '',
        sortOption: SortOption.filesFirst,
        isFavoritesMode: false,
        favorites: {},
      );

      // Files first, then A-Z
      expect(result[0], itemA);
      expect(result[1], itemB);
      expect(result[2], itemC);
      expect(result[3], folder1);
    });
  });

  group('MediaFavoritesNotifier', () {
    setUpAll(() async {
      final directory = await import_io.Directory.systemTemp.createTemp();
      Hive.init(directory.path);
    });

    test('initializes with empty set if box is empty', () async {
      final notifier = MediaFavoritesNotifier('test_box_1');
      // Wait for init to complete
      await Future.delayed(const Duration(milliseconds: 100));
      expect(notifier.state, isEmpty);
    });

    test('toggles favorite status', () async {
      final notifier = MediaFavoritesNotifier('test_box_2');
      await Future.delayed(const Duration(milliseconds: 100));

      notifier.toggleFavorite('/path/to/file.mp3');
      expect(notifier.state, contains('/path/to/file.mp3'));

      notifier.toggleFavorite('/path/to/file.mp3');
      expect(notifier.state, isEmpty);
    });
  });
}
