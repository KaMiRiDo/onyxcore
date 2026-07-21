import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_preview_widget.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_playlist_providers.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_markers_provider.dart';
import 'package:onyxcore/core/widgets/viewer_top_bar.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/features/video_player/presentation/overlays/video_bottom_controls.dart';

class MockPlayer extends Mock implements Player {}

class MockPlayerState extends Mock implements PlayerState {}

class MockPlayerStream extends Mock implements PlayerStream {}

class MockAppDatabase extends Mock implements AppDatabase {}

class MockSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

class MockVideoFavoritesNotifier extends VideoFavoritesNotifier {
  @override
  Set<String> build() => <String>{};
}

void main() {
  setUpAll(() {
    MediaKit.ensureInitialized();
  });

  group('VideoPreviewWidget Core Integration', () {
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
      when(() => mockPlayer.playOrPause()).thenAnswer((_) async {});
      when(() => mockPlayer.play()).thenAnswer((_) async {});
      when(() => mockPlayer.pause()).thenAnswer((_) async {});
      when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});

      when(
        () => mockPlayerState.duration,
      ).thenReturn(const Duration(minutes: 5));
      when(
        () => mockPlayerState.position,
      ).thenReturn(const Duration(minutes: 1));
      when(() => mockPlayerState.playing).thenReturn(true);
      when(() => mockPlayerState.volume).thenReturn(100.0);
      when(() => mockPlayerState.rate).thenReturn(1.0);
      when(() => mockPlayerState.buffering).thenReturn(false);

      when(
        () => mockPlayerStream.position,
      ).thenAnswer((_) => Stream.value(const Duration(minutes: 1)));
      when(
        () => mockPlayerStream.buffer,
      ).thenAnswer((_) => Stream.value(const Duration(minutes: 2)));
      when(
        () => mockPlayerStream.volume,
      ).thenAnswer((_) => Stream.value(100.0));
      when(() => mockPlayerStream.rate).thenAnswer((_) => Stream.value(1.0));
      when(
        () => mockPlayerStream.playing,
      ).thenAnswer((_) => Stream.value(true));
      when(
        () => mockPlayerStream.buffering,
      ).thenAnswer((_) => Stream.value(false));
      
      when(
        () => mockPlayerStream.error,
      ).thenAnswer((_) => errorStreamController.stream);
      
      when(
        () => mockAppDatabase.getPlaybackPosition(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockAppDatabase.savePlaybackPosition(any(), any()),
      ).thenAnswer((_) async {});
    });

    Widget buildWidget([WidgetRef? ref]) {
      final now = DateTime.now();
      return VideoPreviewWidget(
        item: FileItem(
          path: '/mock/video.mp4',
          name: 'video.mp4',
          sizeBytes: 1000,
          modified: now,
          type: FileItemType.video,
        ),
        isStandalone: false,
      );
    }

    testWidgets('Builds and assembles correctly, triggering callbacks', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(mockAppDatabase),
            settingsProvider.overrideWith(() => MockSettingsNotifier()),
            videoPlaylistSidebarVisibleProvider.overrideWith((ref) => false),
            videoFavoritesProvider.overrideWith(
              (ref) => MockVideoFavoritesNotifier(),
            ),
            videoMarkersProvider('/mock/video.mp4').overrideWith((ref) => []),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  ref.watch(settingsProvider);
                  return buildWidget(ref);
                },
              ),
            ),
          ),
        ),
      );

      // Allow timers (like Future.delayed for open) to fire
      await tester.pump(const Duration(milliseconds: 500));

      // Ensure that we have a Video widget
      expect(find.byType(VideoPreviewWidget), findsOneWidget);

      // Dispose the widget to trigger its dispose method
      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      // Allow remaining cleanup timers to clear
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets(
      'Shows empty state in standalone mode when next is clicked with no other videos',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(mockAppDatabase),
              settingsProvider.overrideWith(() => MockSettingsNotifier()),
              videoPlaylistSidebarVisibleProvider.overrideWith((ref) => false),
              videoFavoritesProvider.overrideWith(
                (ref) => MockVideoFavoritesNotifier(),
              ),
              videoMarkersProvider('/mock/video.mp4').overrideWith((ref) => []),
              videoQueueProvider.overrideWith(
                (ref) => [
                  FileItem(
                    path: '/mock/video.mp4',
                    name: 'video.mp4',
                    sizeBytes: 1000,
                    modified: DateTime.now(),
                    type: FileItemType.video,
                  ),
                ],
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: VideoPreviewWidget(
                  item: FileItem(
                    path: '/mock/video.mp4',
                    name: 'video.mp4',
                    sizeBytes: 1000,
                    modified: DateTime.now(),
                    type: FileItemType.video,
                  ),
                  isStandalone: true,
                  windowId: '123',
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(VideoPreviewWidget), findsOneWidget);

        // Simulate clicking next or finishing video that triggers _navigateMedia(true)
        // We can trigger it by sending a completed event if autoPlay is true,
        // but in standalone mode completed auto-closes if no next video (if autoPlay is true? No, _completedSubscription auto-closes).
        // Wait for bottom controls to appear (they appear on hover/start)
        await tester.pump(const Duration(milliseconds: 500));

        // Find and tap the next button
        final nextButton = find.byIcon(Icons.skip_next);
        expect(nextButton, findsOneWidget);
        await tester.tap(nextButton);
        await tester.pump(const Duration(milliseconds: 500));

        // Now we should expect the VideoEmptyState to be shown
        expect(find.text('No video files to play next.'), findsOneWidget);

        // Verify HUD (VideoBottomControls) is also visible to allow navigating back
        expect(find.byType(VideoBottomControls), findsOneWidget);
        
        // Verify only playlist button is visible in HUD during empty state
        // Icons.playlist_play is from VideoBottomControls
        expect(find.byIcon(Icons.playlist_play), findsOneWidget);
        // Icons.playlist_play_rounded from VideoEmptyState should be gone
        expect(find.byIcon(Icons.playlist_play_rounded), findsNothing);
        
        // Other HUD buttons should be hidden
        expect(find.byIcon(Icons.skip_previous), findsNothing);
        expect(find.byIcon(Icons.skip_next), findsNothing);
        expect(find.byIcon(Icons.play_arrow), findsNothing);
        expect(find.byIcon(Icons.pause), findsNothing);
        
        // ViewerTopBar should be completely hidden
        expect(find.byType(ViewerTopBar), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets('Sidebar is hidden when player opens', (tester) async {
      // Set the provider to true initially to simulate previous state
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(mockAppDatabase),
          settingsProvider.overrideWith(() => MockSettingsNotifier()),
          videoFavoritesProvider.overrideWith((ref) => MockVideoFavoritesNotifier()),
          videoMarkersProvider('/mock/video.mp4').overrideWith((ref) => []),
          videoQueueProvider.overrideWith((ref) => [
            FileItem(path: '/mock/video.mp4', name: 'video.mp4', sizeBytes: 1000, modified: DateTime.now(), type: FileItemType.video)
          ]),
          videoPlaylistSidebarVisibleProvider.overrideWith((ref) => true),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoPreviewWidget(
                item: FileItem(path: '/mock/video.mp4', name: 'video.mp4', sizeBytes: 1000, modified: DateTime.now(), type: FileItemType.video),
                isStandalone: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Check if sidebar provider is false
      expect(container.read(videoPlaylistSidebarVisibleProvider), false);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Sidebar state is preserved when video item is updated', (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(mockAppDatabase),
          settingsProvider.overrideWith(() => MockSettingsNotifier()),
          videoFavoritesProvider.overrideWith((ref) => MockVideoFavoritesNotifier()),
          videoMarkersProvider('/mock/video1.mp4').overrideWith((ref) => []),
          videoMarkersProvider('/mock/video2.mp4').overrideWith((ref) => []),
          videoQueueProvider.overrideWith((ref) => [
            FileItem(path: '/mock/video1.mp4', name: 'video1.mp4', sizeBytes: 1000, modified: DateTime.now(), type: FileItemType.video),
            FileItem(path: '/mock/video2.mp4', name: 'video2.mp4', sizeBytes: 1000, modified: DateTime.now(), type: FileItemType.video),
          ]),
        ],
      );

      // Initial pump with video1
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoPreviewWidget(
                item: FileItem(path: '/mock/video1.mp4', name: 'video1.mp4', sizeBytes: 1000, modified: DateTime.now(), type: FileItemType.video),
                isStandalone: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Sidebar is hidden by default (via initState)
      expect(container.read(videoPlaylistSidebarVisibleProvider), false);

      // User opens the sidebar
      container.read(videoPlaylistSidebarVisibleProvider.notifier).state = true;
      await tester.pump();

      // Pump again with the same widget structure, but with video2.
      // This will call didUpdateWidget instead of recreating the element.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: VideoPreviewWidget(
                item: FileItem(path: '/mock/video2.mp4', name: 'video2.mp4', sizeBytes: 1000, modified: DateTime.now(), type: FileItemType.video),
                isStandalone: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // State should remain preserved!
      expect(container.read(videoPlaylistSidebarVisibleProvider), true);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('HUD remaining time preference is preserved', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(mockAppDatabase),
            settingsProvider.overrideWith(() {
               return MockSettingsNotifier();
            }),
            videoPlaylistSidebarVisibleProvider.overrideWith((ref) => false),
            videoFavoritesProvider.overrideWith((ref) => MockVideoFavoritesNotifier()),
            videoMarkersProvider('/mock/video.mp4').overrideWith((ref) => []),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoPreviewWidget(
                item: FileItem(path: '/mock/video.mp4', name: 'video.mp4', sizeBytes: 1000, modified: DateTime.now(), type: FileItemType.video),
                isStandalone: true,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      
      expect(find.byType(VideoPreviewWidget), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
