import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/widgets/filter_sort_button.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_markers_provider.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_playlist_providers.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_preview_widget.dart';

class MockPlayer extends Mock implements Player {}
class MockPlayerState extends Mock implements PlayerState {}
class MockPlayerStream extends Mock implements PlayerStream {}
class MockAppDatabase extends Mock implements AppDatabase {}

class MockSettingsNotifierEnabled extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings(videoFilterSortEnabled: true);
}

class MockSettingsNotifierDisabled extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

class MockVideoFavoritesNotifier extends VideoFavoritesNotifier {
  Set<String> build() => <String>{};
}

void main() {
  setUpAll(MediaKit.ensureInitialized);

  group('VideoPreviewWidget Filter/Sort UI', () {
    late MockPlayer mockPlayer;
    late MockPlayerState mockPlayerState;
    late MockPlayerStream mockPlayerStream;
    late MockAppDatabase mockAppDatabase;
    late StreamController<String> errorStreamController;

    setUp(() {
      mockPlayer = MockPlayer();
      mockPlayerState = MockPlayerState();
      mockPlayerStream = MockPlayerStream();
      mockAppDatabase = MockAppDatabase();
      errorStreamController = StreamController<String>.broadcast();

      when(() => mockPlayer.state).thenReturn(mockPlayerState);
      when(() => mockPlayer.stream).thenReturn(mockPlayerStream);
      when(() => mockPlayerState.playlist).thenReturn(Playlist([]));
      when(() => mockPlayerState.playing).thenReturn(false);
      when(() => mockPlayerState.position).thenReturn(Duration.zero);
      when(() => mockPlayerState.duration).thenReturn(Duration.zero);
      when(() => mockPlayerState.buffering).thenReturn(false);
      when(() => mockPlayerState.volume).thenReturn(100);
      when(() => mockPlayerState.rate).thenReturn(1);
      when(() => mockPlayerState.videoParams).thenReturn(const VideoParams());
      when(() => mockPlayerState.audioParams).thenReturn(const AudioParams());
      when(() => mockPlayerStream.log).thenAnswer((_) => const Stream.empty());
      when(() => mockPlayerStream.error).thenAnswer((_) => errorStreamController.stream);
      
      when(() => mockAppDatabase.getPlaybackPosition(any())).thenAnswer((_) async => null);
      when(() => mockAppDatabase.savePlaybackPosition(any(), any())).thenAnswer((_) async {});
      when(() => mockAppDatabase.pruneMetadataCache(any())).thenAnswer((_) async => []);
      when(() => mockAppDatabase.getAllMetadataCache()).thenAnswer((_) async => []);
      when(() => mockAppDatabase.getAllThumbnailEntries()).thenAnswer((_) async => []);
    });

    Widget buildWidget({required bool isFilterSortEnabled}) {
      final now = DateTime.now();
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(mockAppDatabase),
          settingsProvider.overrideWith(isFilterSortEnabled ? MockSettingsNotifierEnabled.new : MockSettingsNotifierDisabled.new),
          videoPlaylistSidebarVisibleProvider.overrideWith((ref) => false),
          videoMarkersProvider('/mock/video.mp4').overrideWith((ref) => []),
          videoFavoritesProvider.overrideWith((ref) => MockVideoFavoritesNotifier()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VideoPreviewWidget(
              item: FileItem(
                path: '/mock/video.mp4',
                name: 'video.mp4',
                sizeBytes: 1000,
                modified: now,
                type: FileItemType.video,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows FilterSortButton when videoFilterSortEnabled is true', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildWidget(isFilterSortEnabled: true));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(FilterSortButton), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('hides FilterSortButton when videoFilterSortEnabled is false', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildWidget(isFilterSortEnabled: false));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      
      expect(find.byType(FilterSortButton), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
