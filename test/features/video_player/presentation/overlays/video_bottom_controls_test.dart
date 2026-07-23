import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/video_player/domain/entities/video_marker.dart';
import 'package:onyxcore/features/video_player/presentation/overlays/video_bottom_controls.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_markers_provider.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_playlist_providers.dart';
import 'package:onyxcore/features/video_player/presentation/state/video_player_state.dart';

class MockPlayer extends Mock implements Player {}
class FakePlayerState extends Fake implements PlayerState {}
class MockPlayerState extends Mock implements PlayerState {}
class MockPlayerStream extends Mock implements PlayerStream {}
class MockVideoPlayerDisplayState extends Mock implements VideoPlayerDisplayState {}

class MockAppDatabase extends Mock implements AppDatabase {}

class MockSettingsNotifier extends SettingsNotifier {
  bool updateCalled = false;
  AppSettings lastSettings = const AppSettings();

  @override
  Future<AppSettings> build() async => const AppSettings();

  @override
  Future<void> saveSettings(AppSettings newSettings) async {
    updateCalled = true;
    lastSettings = newSettings;
    state = AsyncData(newSettings);
  }
}

class MockVideoFavoritesNotifier extends VideoFavoritesNotifier {
  @override
  Set<String> get state => {};
  
  @override
  void toggleFavorite(String path) {}
}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  group('VideoBottomControls', () {
    late MockPlayer mockPlayer;

    setUpAll(() {
      registerFallbackValue(const Track());
      registerFallbackValue(const Tracks());
      registerFallbackValue(FakePlayerState());
      registerFallbackValue(const SubtitleTrack('id', 'title', 'en'));
      registerFallbackValue(const AudioTrack('id', 'title', 'en'));
      registerFallbackValue(const VideoTrack('id', 'title', 'en'));
    });

    late MockPlayerState mockPlayerState;
    late MockPlayerStream mockStream;

    late VideoPlayerDisplayState displayState;
    late FileItem currentItem;
    late Duration displayPosition;
    late List<MediaFormat> availableFormats;
    late String? selectedFormatId;
    late ValueNotifier<bool> playingNotifier;
    late double playbackSpeed;


    late bool onToggleMuteCalled;
    late bool onToggleFullscreenCalled;
    late bool onNavigateMediaCalled;
    late bool onShowMenuCalled;

    late bool onStepSeekCalled;
    late bool onStartFastSeekCalled;
    late bool onStopFastSeekCalled;

    setUp(() {
      mockPlayer = MockPlayer();
      mockPlayerState = MockPlayerState();
      when(() => mockPlayer.state).thenReturn(mockPlayerState);
            mockStream = MockPlayerStream();
      when(() => mockPlayer.stream).thenReturn(mockStream);
      when(() => mockPlayer.playOrPause()).thenAnswer((_) async {});
      when(() => mockPlayer.play()).thenAnswer((_) async {});
      when(() => mockPlayer.pause()).thenAnswer((_) async {});
      when(() => mockPlayer.seek(any())).thenAnswer((_) async {});
      when(() => mockStream.position).thenAnswer((_) => const Stream.empty());
      when(() => mockStream.buffer).thenAnswer((_) => const Stream.empty());
      when(() => mockStream.volume).thenAnswer((_) => const Stream.empty());
      when(() => mockStream.track).thenAnswer((_) => const Stream.empty());
      when(() => mockPlayerState.duration).thenReturn(const Duration(minutes: 5));
      when(() => mockPlayerState.position).thenReturn(const Duration(minutes: 1));
      when(() => mockPlayerState.buffer).thenReturn(const Duration(minutes: 1));
      when(() => mockPlayerState.playing).thenReturn(true);
      when(() => mockPlayerState.volume).thenReturn(100);
      when(() => mockPlayer.platform).thenReturn(null);

      displayState = MockVideoPlayerDisplayState();
      when(() => displayState.isHudVisible).thenReturn(true);
      when(() => displayState.isMarkerEditorActive).thenReturn(false);
      when(() => displayState.isAudioMenuVisible).thenReturn(false);
      when(() => displayState.isSubtitleMenuVisible).thenReturn(false);
      when(() => displayState.isSpeedMenuVisible).thenReturn(false);
      when(() => displayState.isStandalone).thenReturn(false);
      when(() => displayState.isMuted).thenReturn(false);
      when(() => displayState.isOpening).thenReturn(false);
      when(() => displayState.isSeekLoading).thenReturn(false);
      when(() => displayState.isSeekingToInitial).thenReturn(false);
      when(() => displayState.isSmartBuffering).thenReturn(false);
      when(() => displayState.isMarkerMenuVisible).thenReturn(false);
      when(() => displayState.isNetworkStream).thenReturn(false);
      when(() => displayState.isFastSeeking).thenReturn(false);
      when(() => displayState.isScrubbing).thenReturn(false);
      when(() => displayState.isControlsVisible).thenReturn(true);
      when(() => displayState.isGlobalHudVisible).thenReturn(true);
      when(() => displayState.showRemainingTime).thenReturn(false);
      when(() => displayState.isVolumeOverlayVisible).thenReturn(false);
      when(() => displayState.showSpeedOverlayVisible).thenReturn(false);
      when(() => displayState.isSeekIndicatorVisible).thenReturn(false);
      when(() => displayState.showFlash).thenReturn(false);
      when(() => displayState.showSnapshotToast).thenReturn(false);
      when(() => displayState.isEmpty).thenReturn(false);
      when(() => displayState.hasError).thenReturn(false);
      
      currentItem = FileItem(
        name: 'test.mp4',
        path: '/test.mp4',
        modified: DateTime.now(),
        type: FileItemType.video,
      );
      displayPosition = const Duration(minutes: 1);
      availableFormats = [];
      selectedFormatId = null;
      playingNotifier = ValueNotifier<bool>(true);
      playbackSpeed = 1.0;


      onToggleMuteCalled = false;
      onToggleFullscreenCalled = false;
      onNavigateMediaCalled = false;
      onShowMenuCalled = false;

      onStepSeekCalled = false;
      onStartFastSeekCalled = false;
      onStopFastSeekCalled = false;
    });

    final menuNotifier = ValueNotifier<Widget?>(null);

    Widget buildTestApp(WidgetTester tester, {List<VideoMarker> markers = const []}) {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      return ProviderScope(
        overrides: [
          settingsProvider.overrideWith(MockSettingsNotifier.new),
          databaseProvider.overrideWithValue(MockAppDatabase()),
          videoPlaylistSidebarVisibleProvider.overrideWith((ref) => false),
          videoFavoritesProvider.overrideWith((ref) => MockVideoFavoritesNotifier()),
          videoAutoPlaySessionProvider.overrideWith((ref) => true),
          videoMarkersProvider.overrideWith((ref, id) => markers),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<Widget?>(
              valueListenable: menuNotifier,
              builder: (context, menuChildWidget, _) {
                return Stack(
                  children: [
                    VideoBottomControls(
                  displayState: displayState,
                  player: mockPlayer,
                  currentItem: currentItem,
                  displayPosition: displayPosition,
                  availableFormats: availableFormats,
                  selectedFormatId: selectedFormatId,
                  onResolutionChanged: (f) {},
                  onInteraction: () {},
                  onShowSeekIndicator: () {},
                  onToggleMute: () => onToggleMuteCalled = true,
                  onToggleFullscreen: () => onToggleFullscreenCalled = true,
                  onNavigateMedia: (v) => onNavigateMediaCalled = true,
                  onShowMenu: ({required key, required child, required type}) {
                    onShowMenuCalled = true;
                    Future.microtask(() {
                      menuNotifier.value = child;
                    });
                  },
                  onOpenMarkerEditor: (m) {},
                  audioKey: GlobalKey(),
                  subtitleKey: GlobalKey(),
                  speedKey: GlobalKey(),
                  resolutionKey: GlobalKey(),
                  onMarkerMenuVisibilityChanged: (v) {},
                  onStepSeek: ({required isForward}) => onStepSeekCalled = true,
                  onStartFastSeek: ({required isForward}) => onStartFastSeekCalled = true,
                  onStopFastSeek: () => onStopFastSeekCalled = true,
                  playingNotifier: playingNotifier,
                  playbackSpeed: playbackSpeed,
                ),
                if (menuChildWidget != null)
                  Positioned.fill(child: menuChildWidget),
              ],
            );
          }),
          ),
        ),
      );
    }

    testWidgets('renders current time and progress properly', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());
      
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();

      expect(find.text('01:00'), findsOneWidget); // Position
      expect(find.byType(Slider), findsWidgets);
    });

    testWidgets('play/pause button toggles state based on playingNotifier', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();
      
      expect(find.byIcon(Icons.pause), findsOneWidget);
      
      final gesture = tester.widget<GestureDetector>(
        find.ancestor(
          of: find.byIcon(Icons.pause),
          matching: find.byWidgetPredicate((w) => w is GestureDetector && w.onTap != null),
        ).first
      );
      gesture.onTap!();
      await tester.pumpAndSettle();
      
      verify(() => mockPlayer.playOrPause()).called(1);
    });

    testWidgets('fast seek buttons trigger callbacks', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();
      
      final forwardButton = tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.forward_10), matching: find.byType(IconButton)));
      forwardButton.onPressed!();
      expect(onStepSeekCalled, isTrue);
      
      // Test long press
      final gesture = tester.widget<GestureDetector>(
        find.ancestor(
          of: find.byIcon(Icons.forward_10),
          matching: find.byWidgetPredicate((w) => w is GestureDetector && w.onLongPressStart != null),
        ).first
      );
      gesture.onLongPressStart!(const LongPressStartDetails());
      expect(onStartFastSeekCalled, isTrue);
      
      gesture.onLongPressEnd!(const LongPressEndDetails());
      expect(onStopFastSeekCalled, isTrue);
    });

    testWidgets('volume button triggers toggle mute', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();
      
      final button = tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.volume_up), matching: find.byType(IconButton)));
      button.onPressed!();
      expect(onToggleMuteCalled, isTrue);
    });

    testWidgets('Resolution menu tap', (tester) async {
      when(() => displayState.isNetworkStream).thenReturn(true);
      availableFormats = [const MediaFormat(formatId: '1', formatString: 'mp4', extension: 'mp4', resolution: '1920x1080')];
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();
      
      final buttonFinder = find.byType(PopupMenuButton<MediaFormat>);
      // Pop up menu button does not have an onPressed. It has onSelected, etc. We can just tap it.
      await tester.tap(buttonFinder.first);
      await tester.pumpAndSettle();
    });

    testWidgets('fullscreen button triggers toggle fullscreen', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();
      
      final button = tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.fullscreen_rounded), matching: find.byType(IconButton)));
      button.onPressed!();
      expect(onToggleFullscreenCalled, isTrue);
    });

    testWidgets('remaining time text toggles setting', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final settingsNotifier = MockSettingsNotifier();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(MockAppDatabase()),
            settingsProvider.overrideWith(() => settingsNotifier),
            videoFavoritesProvider.overrideWith((ref) => MockVideoFavoritesNotifier()),
            videoMarkersProvider.overrideWith((ref, path) => []),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  VideoBottomControls(
                displayState: displayState,
                player: mockPlayer,
                currentItem: currentItem,
                displayPosition: displayPosition,
                availableFormats: availableFormats,
                selectedFormatId: selectedFormatId,
                onResolutionChanged: (f) {},
                onInteraction: () {},
                onShowSeekIndicator: () {},
                onToggleMute: () {},
                onToggleFullscreen: () {},
                onNavigateMedia: (_) {},
                onShowMenu: ({required child, required key, required type}) {},
                onOpenMarkerEditor: (_) {},
                audioKey: GlobalKey(),
                subtitleKey: GlobalKey(),
                speedKey: GlobalKey(),
                resolutionKey: GlobalKey(),
                onMarkerMenuVisibilityChanged: (_) {},
                onStepSeek: ({required isForward}) {},
                onStartFastSeek: ({required isForward}) {},
                onStopFastSeek: () {},
                playingNotifier: playingNotifier,
                playbackSpeed: playbackSpeed,
              ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFinder = find.text('05:00');
      expect(textFinder, findsOneWidget);

      final gesture = find.ancestor(of: textFinder, matching: find.byType(GestureDetector)).first;
      await tester.tap(gesture);
      await tester.pumpAndSettle();

      expect(settingsNotifier.updateCalled, isTrue, reason: 'Toggling time text should update settings');
      expect(settingsNotifier.lastSettings.videoShowRemainingTime, isTrue, reason: 'Settings should reflect new state');
    });
    
    testWidgets('progress bar updates immediately on seek', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final settingsNotifier = MockSettingsNotifier();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(MockAppDatabase()),
            settingsProvider.overrideWith(() => settingsNotifier),
            videoFavoritesProvider.overrideWith((ref) => MockVideoFavoritesNotifier()),
            videoMarkersProvider.overrideWith((ref, path) => []),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  VideoBottomControls(
                    displayState: displayState,
                    player: mockPlayer,
                    currentItem: currentItem,
                    displayPosition: displayPosition,
                    availableFormats: availableFormats,
                    selectedFormatId: selectedFormatId,
                    onResolutionChanged: (f) {},
                    onInteraction: () {},
                    onShowSeekIndicator: () {},
                    onToggleMute: () {},
                    onToggleFullscreen: () {},
                    onNavigateMedia: (_) {},
                    onShowMenu: ({required child, required key, required type}) {},
                    onOpenMarkerEditor: (_) {},
                    audioKey: GlobalKey(),
                    subtitleKey: GlobalKey(),
                    speedKey: GlobalKey(),
                    resolutionKey: GlobalKey(),
                    onMarkerMenuVisibilityChanged: (_) {},
                    onStepSeek: ({required isForward}) {},
                    onStartFastSeek: ({required isForward}) {},
                    onStopFastSeek: () {},
                    playingNotifier: playingNotifier,
                    playbackSpeed: playbackSpeed,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(find.byType(Slider).first);
      final initialValue = slider.value;
      expect(initialValue, 1.0 / 5.0); // 1 min / 5 min

      // Tap on the slider at 50%
      await tester.tap(find.byType(Slider).first, pointer: 1);
      await tester.pump(); // Pump once, not pumpAndSettle, because timers might be running!

      final newSlider = tester.widget<Slider>(find.byType(Slider).first);
      expect(newSlider.value, isNot(initialValue), reason: 'Slider value should update immediately on tap');
    });

    testWidgets('renders all HUD controls even if hasError is true', (tester) async {
      when(() => displayState.hasError).thenReturn(true);
      when(() => displayState.isEmpty).thenReturn(false);

      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();

      // Controls should still be visible because we want navigation when error occurs
      expect(find.byType(Slider), findsWidgets); // Timeline
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.playlist_play), findsOneWidget);
    });

    testWidgets('hides HUD controls when isEmpty is true', (tester) async {
      when(() => displayState.hasError).thenReturn(false);
      when(() => displayState.isEmpty).thenReturn(true);

      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();

      // Only playlist button should be visible in empty state
      expect(find.byType(Slider), findsNothing);
      expect(find.byIcon(Icons.skip_next), findsNothing);
      expect(find.byIcon(Icons.skip_previous), findsNothing);
      expect(find.byIcon(Icons.pause), findsNothing);
      expect(find.byIcon(Icons.playlist_play), findsOneWidget);
    });

    testWidgets('slider events (onChangeStart, onChanged, onChangeEnd) cover scrub state and timers', (tester) async {
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();

      final sliderFinder = find.byType(Slider);
      final slider = tester.widget<Slider>(sliderFinder.first);

      // Trigger onChangeStart
      slider.onChangeStart!(0.5);
      await tester.pump();
      verify(() => mockPlayer.pause()).called(1); // pause is called during start

      // Trigger onChanged (twice quickly to test throttle)
      slider.onChanged!(0.6);
      slider.onChanged!(0.7);
      await tester.pump();
      verify(() => mockPlayer.seek(any())).called(greaterThanOrEqualTo(1)); // _performSeek is called

      // Wait for throttle timer
      await tester.pump(const Duration(milliseconds: 150));

      // Trigger onChangeEnd
      slider.onChangeEnd!(0.8);
      await tester.pump();
      
      // Cleanup timer should run after 1 sec
      await tester.pump(const Duration(seconds: 1));
      
      // We can also test didUpdateWidget by pumping a new widget with a different displayState
      final newDisplayState = MockVideoPlayerDisplayState();
      when(() => newDisplayState.isHudVisible).thenReturn(true);
      when(() => newDisplayState.showRemainingTime).thenReturn(true); // Changed
      when(() => newDisplayState.isEmpty).thenReturn(false);
      // add necessary mocks for newDisplayState as well
      when(() => newDisplayState.isMarkerEditorActive).thenReturn(false);
      when(() => newDisplayState.isAudioMenuVisible).thenReturn(false);
      when(() => newDisplayState.isSubtitleMenuVisible).thenReturn(false);
      when(() => newDisplayState.isSpeedMenuVisible).thenReturn(false);
      when(() => newDisplayState.isStandalone).thenReturn(false);
      when(() => newDisplayState.isMuted).thenReturn(false);
      when(() => newDisplayState.isOpening).thenReturn(false);
      when(() => newDisplayState.isSeekLoading).thenReturn(false);
      when(() => newDisplayState.isSeekingToInitial).thenReturn(false);
      when(() => newDisplayState.isSmartBuffering).thenReturn(false);
      when(() => newDisplayState.isMarkerMenuVisible).thenReturn(false);
      when(() => newDisplayState.isNetworkStream).thenReturn(false);
      when(() => newDisplayState.isFastSeeking).thenReturn(false);
      when(() => newDisplayState.isScrubbing).thenReturn(false);
      when(() => newDisplayState.isControlsVisible).thenReturn(true);
      when(() => newDisplayState.isGlobalHudVisible).thenReturn(true);
      when(() => newDisplayState.isVolumeOverlayVisible).thenReturn(false);
      when(() => newDisplayState.showSpeedOverlayVisible).thenReturn(false);
      when(() => newDisplayState.isSeekIndicatorVisible).thenReturn(false);
      when(() => newDisplayState.showFlash).thenReturn(false);
      when(() => newDisplayState.showSnapshotToast).thenReturn(false);
      when(() => newDisplayState.hasError).thenReturn(false);
      
      displayState = newDisplayState;
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();
    });

    testWidgets('mouse region hover and exit events', (tester) async {
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();

      final mouseRegionFinder = find.byType(MouseRegion).first;

      // Simulate enter
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(mouseRegionFinder));
      await tester.pump();

      // Simulate hover at dy = 80 (should trigger hover logic)
      final box = tester.renderObject(mouseRegionFinder) as RenderBox;
      final localPos = Offset(50, 80);
      final globalPos = box.localToGlobal(localPos);
      
      await gesture.moveTo(globalPos);
      await tester.pump();

      // Simulate exit
      await gesture.moveTo(const Offset(-100, -100));
      await tester.pump(const Duration(milliseconds: 300));
      
      await gesture.removePointer();
    });

    testWidgets('fast seek buttons trigger onLongPressCancel', (tester) async {
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();
      
      final gesture = tester.widget<GestureDetector>(
        find.ancestor(
          of: find.byIcon(Icons.forward_10),
          matching: find.byWidgetPredicate((w) => w is GestureDetector && w.onLongPressCancel != null),
        ).first
      );
      gesture.onLongPressCancel!();
      expect(onStopFastSeekCalled, isTrue);
    });
    
    testWidgets('timeline marker interaction (hover, tap, menu)', (tester) async {
      final marker = VideoMarker(id: '1', content: 'Test Marker', timestamp: const Duration(minutes: 2));
      
      await tester.pumpWidget(buildTestApp(tester, markers: [marker]));
      await tester.pumpAndSettle();

      // Ensure marker is rendered
      final markerFinder = find.byType(InkWell); // TimelineMarker uses InkWell inside
      expect(markerFinder, findsWidgets);

      // Simulate tap on marker
      await tester.tap(markerFinder.first);
      await tester.pump();
      
      // Simulate hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(markerFinder.first));
      await tester.pump();
      
      await gesture.moveTo(const Offset(-100, -100));
      await tester.pump();
      await gesture.removePointer();
    });

    testWidgets('covers hours formatting in duration', (tester) async {
      when(() => mockPlayerState.position).thenReturn(const Duration(hours: 1, minutes: 1));
      when(() => mockPlayerState.duration).thenReturn(const Duration(hours: 2));
      
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();
      
      expect(find.text('2:00:00'), findsOneWidget);
    });

    testWidgets('favorites toggle interaction', (tester) async {
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();
      
      final button = tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.favorite_border_rounded), matching: find.byType(IconButton)));
      button.onPressed!();
      await tester.pumpAndSettle();
    });

    testWidgets('autoplay toggle interaction', (tester) async {
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();
      
      final button = tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.autorenew_rounded), matching: find.byType(IconButton)));
      button.onPressed!();
      await tester.pumpAndSettle();
    });

    testWidgets('Subtitle menu tap', (tester) async {
      when(() => mockPlayerState.tracks).thenReturn(
        const Tracks(
          audio: [AudioTrack('1', 'Audio 1', 'en')],
          video: [VideoTrack('1', 'Video 1', 'en')],
          subtitle: [SubtitleTrack('1', 'Subtitle 1', 'en')],
        ),
      );
      when(() => mockPlayerState.track).thenReturn(
        const Track(
          audio: AudioTrack('1', 'Audio 1', 'en'),
          video: VideoTrack('1', 'Video 1', 'en'),
          subtitle: SubtitleTrack('1', 'Subtitle 1', 'en'),
        ),
      );
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();
      
      final button = tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.subtitles_outlined), matching: find.byType(IconButton)).first);
      button.onPressed!();
      await tester.pumpAndSettle();
      
      expect(onShowMenuCalled, isTrue);
    });

    testWidgets('Audio menu tap', (tester) async {
      when(() => mockPlayerState.tracks).thenReturn(
        const Tracks(
          audio: [AudioTrack('1', 'Audio 1', 'en')],
          video: [VideoTrack('1', 'Video 1', 'en')],
          subtitle: [SubtitleTrack('1', 'Subtitle 1', 'en')],
        ),
      );
      when(() => mockPlayerState.track).thenReturn(
        const Track(
          audio: AudioTrack('1', 'Audio 1', 'en'),
          video: VideoTrack('1', 'Video 1', 'en'),
          subtitle: SubtitleTrack('1', 'Subtitle 1', 'en'),
        ),
      );
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();
      
      final button = tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.audiotrack_rounded), matching: find.byType(IconButton)).first);
      button.onPressed!();
      await tester.pumpAndSettle();
      
      expect(onShowMenuCalled, isTrue);
    });

    testWidgets('Speed menu tap', (tester) async {
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();
      
      final button = tester.widget<TextButton>(find.byType(TextButton).first);
      button.onPressed!();
      await tester.pumpAndSettle();
      
      expect(onShowMenuCalled, isTrue);
    });

    testWidgets('Navigate media next/prev interactions', (tester) async {
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();
      
      final nextBtn = tester.widget<IconButton>(find.ancestor(of: find.byTooltip('Next Video'), matching: find.byType(IconButton)).first);
      nextBtn.onPressed!();
      expect(onNavigateMediaCalled, isTrue);
      
      onNavigateMediaCalled = false;
      final prevBtn = tester.widget<IconButton>(find.ancestor(of: find.byTooltip('Previous Video'), matching: find.byType(IconButton)).first);
      prevBtn.onPressed!();
      expect(onNavigateMediaCalled, isTrue);
    });

    testWidgets('Subtitle menu track selection', (tester) async {
      when(() => mockPlayerState.tracks).thenReturn(
        const Tracks(
          audio: [],
          video: [],
          subtitle: [SubtitleTrack('1', 'Sub 1', 'en')],
        ),
      );
      when(() => mockPlayerState.track).thenReturn(const Track());
      when(() => mockPlayer.setSubtitleTrack(any())).thenAnswer((_) async {});
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();

      final button = tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.subtitles_outlined), matching: find.byType(IconButton)).first);
      button.onPressed!();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sub 1'));
      await tester.pumpAndSettle();
      verify(() => mockPlayer.setSubtitleTrack(any())).called(1);
    });

    testWidgets('Audio menu track selection', (tester) async {
      when(() => mockPlayerState.tracks).thenReturn(
        const Tracks(
          audio: [AudioTrack('1', 'Audio 1', 'en')],
          video: [],
          subtitle: [],
        ),
      );
      when(() => mockPlayerState.track).thenReturn(const Track());
      when(() => mockPlayer.setAudioTrack(any())).thenAnswer((_) async {});
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();

      final button = tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.audiotrack_rounded), matching: find.byType(IconButton)).first);
      button.onPressed!();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Audio 1'));
      await tester.pumpAndSettle();
      verify(() => mockPlayer.setAudioTrack(any())).called(1);
    });

    testWidgets('Speed menu selection', (tester) async {
      when(() => mockPlayer.setRate(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();

      final button = tester.widget<TextButton>(find.byType(TextButton).first);
      button.onPressed!();
      await tester.pumpAndSettle();

      await tester.tap(find.text('1.5x'));
      await tester.pumpAndSettle();
      verify(() => mockPlayer.setRate(1.5)).called(1);
    });

    testWidgets('Volume slider change', (tester) async {
      when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});

      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();

      final sliders = find.byType(Slider);
      final volumeSlider = tester.widget<Slider>(sliders.last);
      volumeSlider.onChanged!(150);

      verify(() => mockPlayer.setVolume(150)).called(1);
    });
  });
}