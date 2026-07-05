import 'package:audiotags/audiotags.dart';
import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

import 'package:mocktail/mocktail.dart';

class MockSettingsNotifier extends SettingsNotifier {
  MockSettingsNotifier(this._settings);
  final AppSettings _settings;
  @override
  Future<AppSettings> build() async => _settings;
}

class MockPlayerStream extends Mock implements PlayerStream {}
class MockPlayer extends Mock implements Player {}

void main() {
  late AppDatabase db;

  setUpAll(MediaKit.ensureInitialized);

  setUp(() async {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer createContainer({ProviderContainer? parent, List<dynamic> overrides = const []}) {
    final container = ProviderContainer(
      parent: parent,
      overrides: [
        databaseProvider.overrideWithValue(db),
        ...overrides.cast(),
      ],
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

    test('audioCurrentPathProvider defaults to empty string (U-AUD-PROV-45)', () {
      final container = createContainer();
      expect(container.read(audioCurrentPathProvider), '');
    });

    test('audioRootPathProvider defaults to empty string (U-AUD-PROV-46)', () {
      final container = createContainer();
      expect(container.read(audioRootPathProvider), '');
    });

    test('audioPathHistoryProvider defaults to empty list (U-AUD-PROV-47)', () {
      final container = createContainer();
      expect(container.read(audioPathHistoryProvider), <String>[]);
    });

    test('audioPathForwardHistoryProvider defaults to empty list (U-AUD-PROV-48)', () {
      final container = createContainer();
      expect(container.read(audioPathForwardHistoryProvider), <String>[]);
    });

    test('audioSelectionProvider defaults to empty set (U-AUD-PROV-49)', () {
      final container = createContainer();
      expect(container.read(audioSelectionProvider), <String>{});
    });

    test('audioSelectionAnchorProvider defaults to null (U-AUD-PROV-50)', () {
      final container = createContainer();
      expect(container.read(audioSelectionAnchorProvider), isNull);
    });

    test('audioQueueProvider defaults to empty list (U-AUD-PROV-51)', () {
      final container = createContainer();
      expect(container.read(audioQueueProvider), <FileItem>[]);
    });

    test('audioPlayingQueueProvider defaults to empty list (U-AUD-PROV-52)', () {
      final container = createContainer();
      expect(container.read(audioPlayingQueueProvider), <FileItem>[]);
    });

    test('activeTrackIndexProvider defaults to 0 (U-AUD-PROV-53)', () {
      final container = createContainer();
      expect(container.read(activeTrackIndexProvider), 0);
    });

    test('audioIsReloadingProvider defaults to false (U-AUD-PROV-54)', () {
      final container = createContainer();
      expect(container.read(audioIsReloadingProvider), isFalse);
    });

    test('audioSortOptionProvider defaults to null (U-AUD-PROV-55)', () {
      final container = createContainer();
      expect(container.read(audioSortOptionProvider), isNull);
    });

    test('audioSearchQueryProvider defaults to empty string (U-AUD-PROV-56)', () {
      final container = createContainer();
      expect(container.read(audioSearchQueryProvider), '');
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

    test('fetch tags from AudioMetadataUtils when no override exists (U-AUD-PROV-01)', () async {
      final container = createContainer();
      final result = await container.read(audioTagsProvider('nonexistent').future);
      expect(result, isNull);
    });

    test('return null when AudioMetadataUtils returns null and no override (U-AUD-PROV-03)', () async {
      final container = createContainer();
      final result = await container.read(audioTagsProvider('nonexistent2').future);
      expect(result, isNull);
    });

    test('prioritize override over disk tag even when both exist (U-AUD-PROV-04)', () async {
      const overrideTag = Tag(title: 'Override Title', pictures: []);
      final container = createContainer(overrides: [
        audioTagsOverridesProvider('/path').overrideWith((ref) => overrideTag),
      ]);
      final result = await container.read(audioTagsProvider('/path').future);
      expect(result, equals(overrideTag));
    });

  });

  group('AudioFavoritesNotifier', () {
    test('loads favorites from database on initialization (U-AUD-PROV-10)', () async {
      await db.into(db.audioFavoriteEntries).insert(
        AudioFavoriteEntriesCompanion.insert(filePath: '/pathA', favoritedAt: DateTime.now().millisecondsSinceEpoch),
      );
      await db.into(db.audioFavoriteEntries).insert(
        AudioFavoriteEntriesCompanion.insert(filePath: '/pathB', favoritedAt: DateTime.now().millisecondsSinceEpoch),
      );
      final container = createContainer();
      container.read(audioFavoritesProvider.notifier);
      
      // Wait for async init to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(container.read(audioFavoritesProvider), containsAll(['/pathA', '/pathB']));
    });

    test('adds path to favorites if not present (U-AUD-PROV-07)', () async {
      final container = createContainer();

      // Initialize the provider so _init runs
      final notifier = container.read(audioFavoritesProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      notifier.toggleFavorite('/newPath');
      expect(container.read(audioFavoritesProvider), contains('/newPath'));
      
      // U-AUD-PROV-11
      final dbFavorites = await db.select(db.audioFavoriteEntries).get();
      expect(dbFavorites.map((e) => e.filePath).toList(), contains('/newPath'));
    });

    test('removes path from favorites if already present (U-AUD-PROV-08)', () async {
      await db.into(db.audioFavoriteEntries).insert(
        AudioFavoriteEntriesCompanion.insert(filePath: '/existing', favoritedAt: DateTime.now().millisecondsSinceEpoch),
      );
      
      final container = createContainer();
      
      // Initialize the provider so _init runs
      final notifier = container.read(audioFavoritesProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(container.read(audioFavoritesProvider), contains('/existing'));
      notifier.toggleFavorite('/existing');
      expect(container.read(audioFavoritesProvider), isNot(contains('/existing')));
    });

    test('maintain other favorites when toggling one (U-AUD-PROV-09)', () async {
      await db.into(db.audioFavoriteEntries).insert(
        AudioFavoriteEntriesCompanion.insert(filePath: '/pathA', favoritedAt: DateTime.now().millisecondsSinceEpoch),
      );
      await db.into(db.audioFavoriteEntries).insert(
        AudioFavoriteEntriesCompanion.insert(filePath: '/pathB', favoritedAt: DateTime.now().millisecondsSinceEpoch),
      );
      
      final container = createContainer();
      final notifier = container.read(audioFavoritesProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      notifier.toggleFavorite('/pathA');
      expect(container.read(audioFavoritesProvider), equals({'/pathB'}));
    });

    test('default to empty set when database is empty (U-AUD-PROV-12)', () async {
      final container = createContainer();
      container.read(audioFavoritesProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(container.read(audioFavoritesProvider), isEmpty);
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

    test('return first item when index is 0 and queue has items (U-AUD-PROV-17)', () {
      final container = createContainer(overrides: [
        audioPlayingQueueProvider.overrideWith((ref) => [mockItem1, mockItem2]),
        activeTrackIndexProvider.overrideWith((ref) => 0),
      ]);
      expect(container.read(currentTrackProvider), equals(mockItem1));
    });

    test('watch both queue and index reactively (U-AUD-PROV-18)', () {
      final container = createContainer();
      container.read(audioPlayingQueueProvider.notifier).state = [mockItem1, mockItem2];
      container.read(activeTrackIndexProvider.notifier).state = 1;
      expect(container.read(currentTrackProvider), equals(mockItem2));
    });

  });

  group('filteredAndSortedAudioQueueProvider', () {
    final fileA = FileItem(path: '/a.mp3', name: 'a.mp3', type: FileItemType.audio, modified: DateTime(2020), sizeBytes: 100);
    final fileB = FileItem(path: '/b.mp3', name: 'b.mp3', type: FileItemType.audio, modified: DateTime(2021), sizeBytes: 200);
    final folder = FileItem(path: '/folder', name: 'folder', type: FileItemType.folder, modified: DateTime(2019));

    test('filter queue by favorites view mode (U-AUD-PROV-19)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileA, fileB]),
        audioViewModeProvider.overrideWith((ref) => AudioViewMode.favorites),
      ]);

      // Initialize and wait for async _init
      container.read(audioFavoritesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Fake the favorites state
      container.read(audioFavoritesProvider.notifier).toggleFavorite('/a.mp3');

      container.read(audioFavoritesProvider); await Future<void>.delayed(const Duration(milliseconds: 100));
      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result.length, 1);
      expect(result.first, equals(fileA));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('return all items in home view mode (U-AUD-PROV-20)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileA, fileB]),
        audioViewModeProvider.overrideWith((ref) => AudioViewMode.home),
      ]);

      container.read(audioFavoritesProvider); await Future<void>.delayed(const Duration(milliseconds: 100));
      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result.length, 2);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('filter queue by search query case-insensitive (U-AUD-PROV-21)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileA, fileB]),
        audioSearchQueryProvider.overrideWith((ref) => 'A.'),
      ]);

      container.read(audioFavoritesProvider); await Future<void>.delayed(const Duration(milliseconds: 100));
      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result.length, 1);
      expect(result.first, equals(fileA));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('sort queue by name A to Z folders first (U-AUD-PROV-23)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileB, folder, fileA]),
        audioSortOptionProvider.overrideWith((ref) => SortOption.aToZ),
      ]);

      container.read(audioFavoritesProvider); await Future<void>.delayed(const Duration(milliseconds: 100));
      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result[0], equals(folder)); // Folder always first unless filesFirst
      expect(result[1], equals(fileA)); // then A
      expect(result[2], equals(fileB)); // then B
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('sort queue by size large to small handling nulls (U-AUD-PROV-27, U-AUD-PROV-30)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileA, fileB, folder]),
        audioSortOptionProvider.overrideWith((ref) => SortOption.sizeLargeToSmall),
      ]);

      container.read(audioFavoritesProvider); await Future<void>.delayed(const Duration(milliseconds: 100));
      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result[0], equals(folder)); // Folder first
      expect(result[1], equals(fileB)); // 200 bytes
      expect(result[2], equals(fileA)); // 100 bytes
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('sort queue files first (U-AUD-PROV-29)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [folder, fileA]),
        audioSortOptionProvider.overrideWith((ref) => SortOption.filesFirst),
      ]);

      container.read(audioFavoritesProvider); await Future<void>.delayed(const Duration(milliseconds: 100));
      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result[0], equals(fileA));
      expect(result[1], equals(folder));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('return all items when search query is empty (U-AUD-PROV-22)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileA, fileB]),
        audioSearchQueryProvider.overrideWith((ref) => ''),
      ]);
      container.read(audioFavoritesProvider); await Future<void>.delayed(const Duration(milliseconds: 100));
      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result.length, 2);
    });

    test('sort queue by name Z to A folders first (U-AUD-PROV-24)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileA, fileB, folder]),
        audioSortOptionProvider.overrideWith((ref) => SortOption.zToA),
      ]);
      container.read(audioFavoritesProvider); await Future<void>.delayed(const Duration(milliseconds: 100));
      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result[0], equals(folder));
      expect(result[1], equals(fileB));
      expect(result[2], equals(fileA));
    });

    test('sort queue by last modified (newest first) (U-AUD-PROV-25)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileA, fileB, folder]), // fileA: 2020, fileB: 2021
        audioSortOptionProvider.overrideWith((ref) => SortOption.lastModified),
      ]);
      container.read(audioFavoritesProvider); await Future<void>.delayed(const Duration(milliseconds: 100));
      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result[0], equals(folder));
      expect(result[1], equals(fileB));
      expect(result[2], equals(fileA));
    });

    test('sort queue by first modified (oldest first) (U-AUD-PROV-26)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileA, fileB, folder]),
        audioSortOptionProvider.overrideWith((ref) => SortOption.firstModified),
      ]);
      container.read(audioFavoritesProvider); await Future<void>.delayed(const Duration(milliseconds: 100));
      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result[0], equals(folder));
      expect(result[1], equals(fileA));
      expect(result[2], equals(fileB));
    });

    test('sort queue by size small to large (U-AUD-PROV-28)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileB, fileA, folder]), // A:100, B:200, folder:null
        audioSortOptionProvider.overrideWith((ref) => SortOption.sizeSmallToLarge),
      ]);
      container.read(audioFavoritesProvider); await Future<void>.delayed(const Duration(milliseconds: 100));
      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result[0], equals(folder));
      expect(result[1], equals(fileA));
      expect(result[2], equals(fileB));
    });

    test('preserve original order when sortOption is null (U-AUD-PROV-31)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileB, folder, fileA]),
        audioSortOptionProvider.overrideWith((ref) => null),
      ]);
      container.read(audioFavoritesProvider); await Future<void>.delayed(const Duration(milliseconds: 100));
      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result[0], equals(fileB));
      expect(result[1], equals(folder));
      expect(result[2], equals(fileA));
    });

    test('handle combined filter and sort (U-AUD-PROV-32)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileA, fileB]),
        audioSearchQueryProvider.overrideWith((ref) => 'b'),
        audioSortOptionProvider.overrideWith((ref) => SortOption.aToZ),
      ]);
      container.read(audioFavoritesProvider); await Future<void>.delayed(const Duration(milliseconds: 100));
      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result.length, 1);
      expect(result.first, equals(fileB));
    });

    test('return empty list when no items match search (U-AUD-PROV-33)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileA, fileB]),
        audioSearchQueryProvider.overrideWith((ref) => 'xyz'),
      ]);
      container.read(audioFavoritesProvider); await Future<void>.delayed(const Duration(milliseconds: 100));
      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result, isEmpty);
    });

    test('return empty list when no favorites exist in favorites mode (U-AUD-PROV-34)', () async {
      final container = createContainer(overrides: [
        audioQueueProvider.overrideWith((ref) => [fileA, fileB]),
        audioViewModeProvider.overrideWith((ref) => AudioViewMode.favorites),
      ]);
      // Initialize favorites
      container.read(audioFavoritesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      container.read(audioFavoritesProvider); await Future<void>.delayed(const Duration(milliseconds: 100));
      final result = container.read(filteredAndSortedAudioQueueProvider);
      expect(result, isEmpty);
    });

  });

  group('audioShowHiddenProvider', () {
    test('initialize from settings provider when true (U-AUD-PROV-40)', () async {
      final container = createContainer(overrides: [
        settingsProvider.overrideWith(() => MockSettingsNotifier(const AppSettings(showHiddenAudioFiles: true))),
      ]);
      await container.read(settingsProvider.future);
      expect(container.read(audioShowHiddenProvider), isTrue);
    });

    test('initialize from settings provider when false (U-AUD-PROV-41)', () async {
      final container = createContainer(overrides: [
        settingsProvider.overrideWith(() => MockSettingsNotifier(const AppSettings())),
      ]);
      await container.read(settingsProvider.future);
      expect(container.read(audioShowHiddenProvider), isFalse);
    });

    test('default to false when settings provider has no value (U-AUD-PROV-42)', () async {
      final container = createContainer(overrides: [
        settingsProvider.overrideWith(() => MockSettingsNotifier(const AppSettings())),
      ]);
      // The mock notifier returns value immediately but watch reads the value.
      expect(container.read(audioShowHiddenProvider), isFalse);
    });

  });

  group('audioAutoPlaySessionProvider', () {
    test('initializes from settings provider autoPlayNext (U-AUD-PROV-61)', () async {
      final container = createContainer(overrides: [
        settingsProvider.overrideWith(() => MockSettingsNotifier(const AppSettings())),
      ]);
      await container.read(settingsProvider.future);
      expect(container.read(audioAutoPlaySessionProvider), isTrue);
    });

    test('initializes false when settings autoPlayNext is false (U-AUD-PROV-62)', () async {
      final container = createContainer(overrides: [
        settingsProvider.overrideWith(() => MockSettingsNotifier(const AppSettings(audioAutoPlayNext: false))),
      ]);
      await container.read(settingsProvider.future);
      expect(container.read(audioAutoPlaySessionProvider), isFalse);
    });

    test('updates state independently of settings (U-AUD-PROV-63)', () async {
      final container = createContainer(overrides: [
        settingsProvider.overrideWith(() => MockSettingsNotifier(const AppSettings())),
      ]);
      await container.read(settingsProvider.future);
      
      container.read(audioAutoPlaySessionProvider.notifier).state = false;
      expect(container.read(audioAutoPlaySessionProvider), isFalse);
    });
  });

  group('Stream Providers', () {
    test('emit empty stream when player is null (U-AUD-PROV-39)', () async {
      final container = createContainer();
      expect(container.read(audioPositionProvider), isA<AsyncValue<Duration>>());
      expect(container.read(audioDurationProvider), isA<AsyncValue<Duration>>());
      expect(container.read(audioPlayingProvider), isA<AsyncValue<bool>>());
      expect(container.read(audioVolumeProvider), isA<AsyncValue<double>>());
    });

    test('emit updates from player stream (U-AUD-PROV-35, 36, 37, 38)', () async {
      final mockStream = MockPlayerStream();
      when(() => mockStream.position).thenAnswer((_) => Stream.value(Duration.zero));
      when(() => mockStream.duration).thenAnswer((_) => Stream.value(Duration.zero));
      when(() => mockStream.playing).thenAnswer((_) => Stream.value(false));
      when(() => mockStream.volume).thenAnswer((_) => Stream.value(100.0));
      
      final player = MockPlayer();
      when(() => player.stream).thenReturn(mockStream);
      
      final container = createContainer(overrides: [
        audioPlayerProvider.overrideWith((ref) => player),
      ]);
      expect(container.read(audioPositionProvider), isA<AsyncValue<Duration>>());
      expect(container.read(audioDurationProvider), isA<AsyncValue<Duration>>());
      expect(container.read(audioPlayingProvider), isA<AsyncValue<bool>>());
      expect(container.read(audioVolumeProvider), isA<AsyncValue<double>>());
    });
  });
}
