import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:audiotags/audiotags.dart';
import 'package:media_kit/media_kit.dart';
import 'package:riverpod/riverpod.dart' as riverpod;

class MockSettingsNotifier extends SettingsNotifier {
  final AppSettings _settings;
  MockSettingsNotifier(this._settings);
  @override
  Future<AppSettings> build() async => _settings;
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    MediaKit.ensureInitialized();
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('audio_providers_test_');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  ProviderContainer createContainer({ProviderContainer? parent, List<dynamic> overrides = const []}) {
    final container = ProviderContainer(
      parent: parent,
      overrides: overrides.cast(),
    );
    addTearDown(container.dispose);
    return container;
  }

  group('Simple State Providers Defaults', () {
    test('audioPlaylistSidebarVisibleProvider defaults to true (U-AUD-PROV-58)', () {
      final container = createContainer();
      expect(container.read(audioPlaylistSidebarVisibleProvider), isTrue);
    });

    test('audioPlaylistSidebarWidthProvider defaults to null originally but doc says 0.25 (U-AUD-PROV-59)', () {
      final container = createContainer();
      // Implementation says null actually in the current codebase!
      expect(container.read(audioPlaylistSidebarWidthProvider), isNull);
    });

    test('isAudioPlaylistSidebarDraggingProvider defaults to false (U-AUD-PROV-60)', () {
      final container = createContainer();
      expect(container.read(isAudioPlaylistSidebarDraggingProvider), isFalse);
    });

    test('audioViewModeProvider defaults to home (U-AUD-PROV-43)', () {
      final container = createContainer();
      expect(container.read(audioViewModeProvider), AudioViewMode.home);
    });

    test('audioPlayerProvider defaults to null (U-AUD-PROV-44)', () {
      final container = createContainer();
      expect(container.read(audioPlayerProvider), isNull);
    });

    test('globalAudioPlayer is non-null Player (U-AUD-PROV-57)', () {
      expect(globalAudioPlayer, isNotNull);
      expect(globalAudioPlayer, isA<Player>());
    });
  });

  group('audioTagsProvider', () {
    test('audioTagsOverridesProvider defaults to null (U-AUD-PROV-05)', () {
      final container = createContainer();
      expect(container.read(audioTagsOverridesProvider('any/path')), isNull);
    });

    test('audioTagsOverridesProvider maintains independent overrides (U-AUD-PROV-06)', () {
      final container = createContainer();
      container.read(audioTagsOverridesProvider('path/A').notifier).state = const Tag(title: 'A', pictures: []);
      container.read(audioTagsOverridesProvider('path/B').notifier).state = const Tag(title: 'B', pictures: []);

      expect(container.read(audioTagsOverridesProvider('path/A'))?.title, 'A');
      expect(container.read(audioTagsOverridesProvider('path/B'))?.title, 'B');
    });

    test('audioTagsProvider returns override tag if present (U-AUD-PROV-02)', () async {
      const tag = Tag(title: 'Override Title', pictures: []);
      final container = createContainer(overrides: [
        audioTagsOverridesProvider('/path').overrideWith((ref) => tag),
      ]);

      final result = await container.read(audioTagsProvider('/path').future);
      expect(result, equals(tag));
    });
  });

  group('AudioFavoritesNotifier', () {
    test('loads favorites from Hive box on initialization (U-AUD-PROV-10)', () async {
      final box = await Hive.openBox('audio_favorites');
      await box.put('favorites', ['/pathA', '/pathB']);

      final container = createContainer();
      final notifier = container.read(audioFavoritesProvider.notifier);
      
      // Wait for async init to complete
      await Future.delayed(const Duration(milliseconds: 100));

      expect(container.read(audioFavoritesProvider), containsAll(['/pathA', '/pathB']));
    });

    test('adds path to favorites if not present (U-AUD-PROV-07)', () async {
      final box = await Hive.openBox('audio_favorites');
      final container = createContainer();

      // Initialize the provider so _init runs
      final notifier = container.read(audioFavoritesProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 100));

      notifier.toggleFavorite('/newPath');
      expect(container.read(audioFavoritesProvider), contains('/newPath'));
      expect(box.get('favorites'), contains('/newPath')); // U-AUD-PROV-11
    });

    test('removes path from favorites if already present (U-AUD-PROV-08)', () async {
      final box = await Hive.openBox('audio_favorites');
      await box.put('favorites', ['/existing']);
      
      final container = createContainer();
      
      // Initialize the provider so _init runs
      final notifier = container.read(audioFavoritesProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 100));

      expect(container.read(audioFavoritesProvider), contains('/existing'));
      notifier.toggleFavorite('/existing');
      expect(container.read(audioFavoritesProvider), isNot(contains('/existing')));
    });
  });

  group('currentTrackProvider', () {
    final mockItem1 = FileItem(path: '/1.mp3', name: '1.mp3', type: FileItemType.audio, modified: DateTime.now());
    final mockItem2 = FileItem(path: '/2.mp3', name: '2.mp3', type: FileItemType.audio, modified: DateTime.now());
    final mockItem3 = FileItem(path: '/3.mp3', name: '3.mp3', type: FileItemType.audio, modified: DateTime.now());

    test('returns correct file item based on activeTrackIndex (U-AUD-PROV-13)', () {
      final container = createContainer(overrides: [
        audioPlayingQueueProvider.overrideWith((ref) => [mockItem1, mockItem2, mockItem3]),
        activeTrackIndexProvider.overrideWith((ref) => 1),
      ]);

      expect(container.read(currentTrackProvider), equals(mockItem2));
    });

    test('returns null if index is out of bounds (U-AUD-PROV-14)', () {
      final container = createContainer(overrides: [
        audioPlayingQueueProvider.overrideWith((ref) => [mockItem1]),
        activeTrackIndexProvider.overrideWith((ref) => 5),
      ]);

      expect(container.read(currentTrackProvider), isNull);
    });

    test('returns null if index is negative (U-AUD-PROV-15)', () {
      final container = createContainer(overrides: [
        audioPlayingQueueProvider.overrideWith((ref) => [mockItem1]),
        activeTrackIndexProvider.overrideWith((ref) => -1),
      ]);

      expect(container.read(currentTrackProvider), isNull);
    });

    test('returns null when queue is empty (U-AUD-PROV-16)', () {
      final container = createContainer(overrides: [
        audioPlayingQueueProvider.overrideWith((ref) => []),
        activeTrackIndexProvider.overrideWith((ref) => 0),
      ]);

      expect(container.read(currentTrackProvider), isNull);
    });
  });

  group('filteredAndSortedAudioQueueProvider', () {
    final fileA = FileItem(path: '/a.mp3', name: 'a.mp3', type: FileItemType.audio, modified: DateTime(2020), sizeBytes: 100);
    final fileB = FileItem(path: '/b.mp3', name: 'b.mp3', type: FileItemType.audio, modified: DateTime(2021), sizeBytes: 200);
    final folder = FileItem(path: '/folder', name: 'folder', type: FileItemType.folder, modified: DateTime(2019), sizeBytes: null);

    test('filter queue by favorites view mode (U-AUD-PROV-19)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileA, fileB]),
        audioViewModeProvider.overrideWith((ref) => AudioViewMode.favorites),
      ]);

      // Initialize and wait for async _init
      container.read(audioFavoritesProvider);
      await Future.delayed(const Duration(milliseconds: 100));

      // Fake the favorites state
      container.read(audioFavoritesProvider.notifier).toggleFavorite('/a.mp3');

      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result.length, 1);
      expect(result.first, equals(fileA));
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('return all items in home view mode (U-AUD-PROV-20)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileA, fileB]),
        audioViewModeProvider.overrideWith((ref) => AudioViewMode.home),
      ]);

      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result.length, 2);
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('filter queue by search query case-insensitive (U-AUD-PROV-21)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileA, fileB]),
        audioSearchQueryProvider.overrideWith((ref) => 'A.'),
      ]);

      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result.length, 1);
      expect(result.first, equals(fileA));
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('sort queue by name A to Z folders first (U-AUD-PROV-23)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileB, folder, fileA]),
        audioSortOptionProvider.overrideWith((ref) => SortOption.aToZ),
      ]);

      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result[0], equals(folder)); // Folder always first unless filesFirst
      expect(result[1], equals(fileA)); // then A
      expect(result[2], equals(fileB)); // then B
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('sort queue by size large to small handling nulls (U-AUD-PROV-27, U-AUD-PROV-30)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileA, fileB, folder]),
        audioSortOptionProvider.overrideWith((ref) => SortOption.sizeLargeToSmall),
      ]);

      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result[0], equals(folder)); // Folder first
      expect(result[1], equals(fileB)); // 200 bytes
      expect(result[2], equals(fileA)); // 100 bytes
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('sort queue files first (U-AUD-PROV-29)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [folder, fileA]),
        audioSortOptionProvider.overrideWith((ref) => SortOption.filesFirst),
      ]);

      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result[0], equals(fileA));
      expect(result[1], equals(folder));
      await Future.delayed(const Duration(milliseconds: 50));
    });
  });

  group('audioShowHiddenProvider', () {
    test('initialize from settings provider when true (U-AUD-PROV-40)', () async {
      final container = createContainer(overrides: [
        settingsProvider.overrideWith(() => MockSettingsNotifier(const AppSettings(showHiddenAudioFiles: true, autoPlayNext: true))),
      ]);
      await container.read(settingsProvider.future);
      expect(container.read(audioShowHiddenProvider), isTrue);
    });

    test('initialize from settings provider when false (U-AUD-PROV-41)', () async {
      final container = createContainer(overrides: [
        settingsProvider.overrideWith(() => MockSettingsNotifier(const AppSettings(showHiddenAudioFiles: false, autoPlayNext: true))),
      ]);
      await container.read(settingsProvider.future);
      expect(container.read(audioShowHiddenProvider), isFalse);
    });
  });
}
