import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/playlist/playlist_providers.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_playlist_providers.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:mocktail/mocktail.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockSettingsNotifier extends AsyncNotifier<AppSettings> implements SettingsNotifier {
  @override
  Future<AppSettings> build() async {
    return const AppSettings(showHiddenFiles: true, autoPlayNext: false);
  }

  @override
  Future<void> setAutoPlayNext({required bool value}) async {}
  @override
  Future<void> setShowHiddenFiles({required bool value}) async {}
  @override
  Future<void> setShowHiddenAudioFiles({required bool value}) async {}
  @override
  Future<void> setSnapshotPrefix(String value) async {}
  @override
  Future<void> setDoubleTapSeekSeconds(int value) async {}
  @override
  Future<void> setResumePlayback({required bool value}) async {}
  @override
  Future<void> setSelectedHwDec(String value) async {}
  @override
  Future<void> setCachedResolvedHwDec(String? value) async {}
  @override
  Future<void> setTrackpadSpeedControl({required SpeedControlOption value}) async {}
  @override
  Future<void> setFilePickerDimensions(double width, double height) async {}
  @override
  Future<void> setSettingsDimensions(double width, double height) async {}
  @override
  Future<void> setDownloaderDimensions(double width, double height) async {}
  @override
  Future<void> setDownloadBrowser(String? browser) async {}
  @override
  Future<void> setDownloadToCurrentFolder({required bool value}) async {}
  @override
  Future<void> setFolderSort(String path, dynamic option) async {}
  @override
  Future<void> cleanupFolderSorts(List<String> paths) async {}
  @override
  Future<void> saveSettings(AppSettings settings) async {}
}

void main() {
  group('Video Playlist Providers', () {
    late ProviderContainer container;
    late MockAppDatabase mockDb;

    setUp(() {
      mockDb = MockAppDatabase();
      when(() => mockDb.getVideoFavorites())
          .thenAnswer((_) async => <String>{});
      when(() => mockDb.addVideoFavorite(any()))
          .thenAnswer((_) async {});
      when(() => mockDb.removeVideoFavorite(any()))
          .thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(mockDb),
          settingsProvider.overrideWith(MockSettingsNotifier.new),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('videoFavoritesProvider toggles favorites correctly', () {
      final notifier = container.read(videoFavoritesProvider.notifier);
      expect(container.read(videoFavoritesProvider), isEmpty);

      notifier.toggleFavorite('test.mp4');
      expect(container.read(videoFavoritesProvider), contains('test.mp4'));

      notifier.toggleFavorite('test.mp4');
      expect(container.read(videoFavoritesProvider), isEmpty);
    });

    test('videoViewModeProvider default is home', () {
      expect(container.read(videoViewModeProvider), VideoViewMode.home);
    });

    test('videoShowHiddenProvider reads from settings', () async {
      await container.read(settingsProvider.future);
      expect(container.read(videoShowHiddenProvider), isTrue);
    });

    test('videoAutoPlaySessionProvider reads from settings', () async {
      await container.read(settingsProvider.future);
      expect(container.read(videoAutoPlaySessionProvider), isFalse);
    });

    test('currentVideoProvider returns correct FileItem based on index and queue', () {
      final file1 = FileItem(name: '1.mp4', path: '/1.mp4', sizeBytes: 0, modified: DateTime.now(), type: FileItemType.video);
      final file2 = FileItem(name: '2.mp4', path: '/2.mp4', sizeBytes: 0, modified: DateTime.now(), type: FileItemType.video);
      
      container.read(videoPlayingQueueProvider.notifier).state = [file1, file2];
      container.read(activeVideoIndexProvider.notifier).state = 1;

      expect(container.read(currentVideoProvider), file2);

      // Out of bounds
      container.read(activeVideoIndexProvider.notifier).state = 5;
      expect(container.read(currentVideoProvider), isNull);
    });

    test('filteredAndSortedVideoQueueProvider filters correctly based on search query', () {
      final file1 = FileItem(name: 'apple.mp4', path: '/apple.mp4', sizeBytes: 0, modified: DateTime.now(), type: FileItemType.video);
      final file2 = FileItem(name: 'banana.mp4', path: '/banana.mp4', sizeBytes: 0, modified: DateTime.now(), type: FileItemType.video);
      
      container.read(videoQueueProvider.notifier).state = [file1, file2];
      container.read(videoSearchQueryProvider.notifier).state = 'app';

      final filtered = container.read(filteredAndSortedVideoQueueProvider);
      expect(filtered.length, 1);
      expect(filtered.first.name, 'apple.mp4');
    });

    test('filteredAndSortedVideoQueueProvider handles favorites mode', () {
      final file1 = FileItem(name: 'apple.mp4', path: '/apple.mp4', sizeBytes: 0, modified: DateTime.now(), type: FileItemType.video);
      final file2 = FileItem(name: 'banana.mp4', path: '/banana.mp4', sizeBytes: 0, modified: DateTime.now(), type: FileItemType.video);
      
      container.read(videoQueueProvider.notifier).state = [file1, file2];
      container.read(videoFavoritesProvider.notifier).toggleFavorite('/banana.mp4');
      container.read(videoViewModeProvider.notifier).state = VideoViewMode.favorites;

      final filtered = container.read(filteredAndSortedVideoQueueProvider);
      expect(filtered.length, 1);
      expect(filtered.first.name, 'banana.mp4');
    });

    test('videoPlaylistProviderConfig has correct mappings', () {
      final config = videoPlaylistProviderConfig;
      expect(config.currentPathProvider, videoCurrentPathProvider);
      expect(config.rootPathProvider, videoRootPathProvider);
      expect(config.viewModeProvider, videoViewModeProvider);
      expect(config.favoritesValue, VideoViewMode.favorites);
    });
  });
}
