import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/video_player/presentation/handlers/gesture_handler.dart';

class MockPlayer extends Mock implements Player {}
class MockPlayerState extends Mock implements PlayerState {}

class MockSettingsNotifier extends SettingsNotifier {
  final AppSettings settings;
  MockSettingsNotifier({this.settings = const AppSettings()});
  
  @override
  Future<AppSettings> build() async => settings;
}

void main() {
  group('VideoGestureHandler', () {
    late MockPlayer mockPlayer;
    late MockPlayerState mockPlayerState;

    late bool mounted;
    late bool isClosing;
    late bool isScrubbing;
    late bool isFastSeeking;
    late Duration? virtualSeekPosition;
    late Duration? virtualScrubPosition;
    late Duration? pendingScrubPosition;
    late double? virtualVolume;
    late double? virtualSpeed;
    late String? scrollLockAxis;
    late bool wasPlayingBeforeScrub;
    late DateTime? lastKeyEventTime;

    Timer? engineSeekTimer;
    Timer? virtualSeekCleanupTimer;
    Timer? fastSeekTimer;
    Timer? scrollResetTimer;
    Timer? scrollVolumeTimer;
    Timer? scrollSpeedTimer;
    Timer? scrubThrottleTimer;

    late bool showVolumeOverlayCalled;
    late bool showSpeedOverlayCalled;
    late bool showSeekIndicatorCalled;
    late bool onInteractionCalled;
    late bool cleanupVirtualSeekingCalled;

    late VideoGestureCallbacks callbacks;
    late VideoGestureHandler handler;

    Widget buildTestApp(WidgetTester tester, Function(WidgetRef) onBuild, {AppSettings? settings}) {
      return ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => MockSettingsNotifier(settings: settings ?? const AppSettings())),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, child) {
                ref.watch(settingsProvider); // Force initialization
                onBuild(ref);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    }

    void setupHandler(WidgetRef ref) {
      mockPlayer = MockPlayer();
      mockPlayerState = MockPlayerState();
      when(() => mockPlayer.state).thenReturn(mockPlayerState);
      when(() => mockPlayerState.duration).thenReturn(const Duration(seconds: 100));
      when(() => mockPlayerState.position).thenReturn(const Duration(seconds: 10));
      when(() => mockPlayerState.playing).thenReturn(true);
      when(() => mockPlayerState.volume).thenReturn(100.0);
      when(() => mockPlayerState.rate).thenReturn(1.0);
      when(() => mockPlayer.pause()).thenAnswer((_) async {});
      when(() => mockPlayer.play()).thenAnswer((_) async {});
      when(() => mockPlayer.seek(any())).thenAnswer((_) async {});
      when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});
      when(() => mockPlayer.setRate(any())).thenAnswer((_) async {});

      mounted = true;
      isClosing = false;
      isScrubbing = false;
      isFastSeeking = false;
      virtualSeekPosition = null;
      virtualScrubPosition = null;
      pendingScrubPosition = null;
      virtualVolume = null;
      virtualSpeed = null;
      scrollLockAxis = null;
      wasPlayingBeforeScrub = false;
      lastKeyEventTime = null;

      engineSeekTimer = null;
      virtualSeekCleanupTimer = null;
      fastSeekTimer = null;
      scrollResetTimer = null;
      scrollVolumeTimer = null;
      scrollSpeedTimer = null;
      scrubThrottleTimer = null;

      showVolumeOverlayCalled = false;
      showSpeedOverlayCalled = false;
      showSeekIndicatorCalled = false;
      onInteractionCalled = false;
      cleanupVirtualSeekingCalled = false;

      callbacks = VideoGestureCallbacks(
        getPlayer: () => mockPlayer,
        getRef: () => ref,
        getMounted: () => mounted,
        getIsClosing: () => isClosing,
        getIsScrubbing: () => isScrubbing,
        setIsScrubbing: (v) => isScrubbing = v,
        getIsFastSeeking: () => isFastSeeking,
        setIsFastSeeking: (v) => isFastSeeking = v,
        getVirtualSeekPosition: () => virtualSeekPosition,
        setVirtualSeekPosition: (v) => virtualSeekPosition = v,
        getVirtualScrubPosition: () => virtualScrubPosition,
        setVirtualScrubPosition: (v) => virtualScrubPosition = v,
        getPendingScrubPosition: () => pendingScrubPosition,
        setPendingScrubPosition: (v) => pendingScrubPosition = v,
        getVirtualVolume: () => virtualVolume,
        setVirtualVolume: (v) => virtualVolume = v,
        getVirtualSpeed: () => virtualSpeed,
        setVirtualSpeed: (v) => virtualSpeed = v,
        getScrollLockAxis: () => scrollLockAxis,
        setScrollLockAxis: (v) => scrollLockAxis = v,
        getWasPlayingBeforeScrub: () => wasPlayingBeforeScrub,
        setWasPlayingBeforeScrub: (v) => wasPlayingBeforeScrub = v,
        getLastKeyEventTime: () => lastKeyEventTime,
        getEngineSeekTimer: () => engineSeekTimer,
        getVirtualSeekCleanupTimer: () => virtualSeekCleanupTimer,
        setVirtualSeekCleanupTimer: (v) => virtualSeekCleanupTimer = v,
        getFastSeekTimer: () => fastSeekTimer,
        getScrollResetTimer: () => scrollResetTimer,
        setScrollResetTimer: (v) => scrollResetTimer = v,
        getScrollVolumeTimer: () => scrollVolumeTimer,
        setScrollVolumeTimer: (v) => scrollVolumeTimer = v,
        getScrollSpeedTimer: () => scrollSpeedTimer,
        setScrollSpeedTimer: (v) => scrollSpeedTimer = v,
        getScrubThrottleTimer: () => scrubThrottleTimer,
        setScrubThrottleTimer: (v) => scrubThrottleTimer = v,
        getContextSize: () => const Size(800, 600),
        showVolumeOverlay: () => showVolumeOverlayCalled = true,
        showSpeedOverlay: () => showSpeedOverlayCalled = true,
        showSeekIndicator: () => showSeekIndicatorCalled = true,
        onInteraction: () => onInteractionCalled = true,
        cleanupVirtualSeeking: () => cleanupVirtualSeekingCalled = true,
        setStateCallback: (cb) => cb(),
      );

      handler = VideoGestureHandler(callbacks);
    }
    
    setUpAll(() {
      registerFallbackValue(const Duration(seconds: 0));
    });

    testWidgets('handlePointerPanZoomUpdate horizontal starts scrubbing', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupHandler(ref);
      }));

      handler.handlePointerPanZoomUpdate(const PointerPanZoomUpdateEvent(
        panDelta: Offset(10.0, 0.0),
        position: Offset(100, 100),
      ));

      expect(scrollLockAxis, equals('h'));
      expect(isScrubbing, isTrue);
      expect(wasPlayingBeforeScrub, isTrue);
      expect(virtualScrubPosition, isNotNull);
      verify(() => mockPlayer.pause()).called(1);
      expect(showSeekIndicatorCalled, isTrue);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('handlePointerPanZoomUpdate vertical starts volume change', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupHandler(ref);
      }));

      handler.handlePointerPanZoomUpdate(const PointerPanZoomUpdateEvent(
        panDelta: Offset(0.0, 10.0),
        position: Offset(100, 100),
      ));

      expect(scrollLockAxis, equals('v'));
      expect(virtualVolume, isNotNull);
      expect(showVolumeOverlayCalled, isTrue);
      
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('handlePointerPanZoomEnd resets trackpad gesture', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupHandler(ref);
      }));

      handler.handlePointerPanZoomUpdate(const PointerPanZoomUpdateEvent(
        panDelta: Offset(10.0, 0.0),
        position: Offset(100, 100),
      ));
      
      expect(scrollLockAxis, equals('h'));
      
      handler.handlePointerPanZoomEnd(const PointerPanZoomEndEvent());

      expect(scrollLockAxis, isNull);
      expect(virtualVolume, isNull);
      expect(virtualSpeed, isNull);
      verify(() => mockPlayer.play()).called(1); // was playing before scrub

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('handlePointerScroll starts discrete scrubbing', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupHandler(ref);
      }));

      handler.handlePointerScroll(const PointerScrollEvent(
        scrollDelta: Offset(10.0, 0.0),
        position: Offset(100, 100),
      ));

      expect(scrollLockAxis, equals('h'));
      expect(isScrubbing, isTrue);
      // Discrete scroll creates a scrollResetTimer
      expect(scrollResetTimer, isNotNull);
      
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('vertical scroll on left half triggers speed control when enabled', (tester) async {
      final settings = const AppSettings(trackpadSpeedControl: SpeedControlOption.releaseToFix);
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupHandler(ref);
      }, settings: settings));
      await tester.pumpAndSettle(); // Wait for settings to load

      handler.handlePointerPanZoomUpdate(const PointerPanZoomUpdateEvent(
        panDelta: Offset(0.0, 10.0),
        position: Offset(100, 100), // width is 800, 100 is left half
      ));

      expect(scrollLockAxis, equals('speed'));
      expect(virtualSpeed, isNotNull);
      expect(showSpeedOverlayCalled, isTrue);
      
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('speed control resets to normal if option is releaseToNormal', (tester) async {
      final settings = const AppSettings(trackpadSpeedControl: SpeedControlOption.releaseToNormal);
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupHandler(ref);
      }, settings: settings));
      await tester.pumpAndSettle(); // Wait for settings to load

      handler.handlePointerPanZoomUpdate(const PointerPanZoomUpdateEvent(
        panDelta: Offset(0.0, -10.0), // increase speed
        position: Offset(100, 100),
      ));
      
      expect(scrollLockAxis, equals('speed'));
      
      handler.handlePointerPanZoomEnd(const PointerPanZoomEndEvent());
      
      verify(() => mockPlayer.setRate(1.0)).called(1);
      expect(scrollLockAxis, isNull);
      
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('blip rejection delays trackpad reset if key recently pressed', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupHandler(ref);
      }));

      handler.handlePointerPanZoomUpdate(const PointerPanZoomUpdateEvent(
        panDelta: Offset(10.0, 0.0),
        position: Offset(100, 100),
      ));
      
      expect(scrollLockAxis, equals('h'));
      
      // Simulate a key press 10ms ago
      lastKeyEventTime = DateTime.now().subtract(const Duration(milliseconds: 10));
      
      handler.handlePointerPanZoomEnd(const PointerPanZoomEndEvent());
      
      // Still 'h' because reset is delayed
      expect(scrollLockAxis, equals('h'));
      
      // Make it old enough so the next timer tick exits the loop
      lastKeyEventTime = DateTime.now().subtract(const Duration(milliseconds: 100));
      
      // Wait for the scheduled timer
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      
      // Now it should be null
      expect(scrollLockAxis, isNull);
      
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('volume scroll correctly bounds volume between 0.0 and 200.0', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupHandler(ref);
      }));

      // Simulate aggressive scroll down (decrease volume below 0)
      handler.handlePointerPanZoomUpdate(const PointerPanZoomUpdateEvent(
        panDelta: Offset(0.0, 5000.0), 
        position: Offset(700, 100), // Right side, triggers volume
      ));
      
      // Step calculation: dy.abs() * 0.05 => 5000 * 0.05 = 250. 
      // 100 - 250 = -150 => clamped to 0.0
      expect(virtualVolume, equals(0.0));

      // Reset and test aggressive scroll up (increase volume above 200)
      virtualVolume = 100.0;
      handler.handlePointerPanZoomUpdate(const PointerPanZoomUpdateEvent(
        panDelta: Offset(0.0, -5000.0), 
        position: Offset(700, 100),
      ));
      
      // Step: 250. 100 + 250 = 350 => clamped to 200.0
      expect(virtualVolume, equals(200.0));
      
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('speed scroll correctly bounds speed between 0.25 and 4.0', (tester) async {
      final settings = const AppSettings(trackpadSpeedControl: SpeedControlOption.releaseToFix);
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupHandler(ref);
      }, settings: settings));
      await tester.pumpAndSettle();

      // Simulate aggressive scroll down (decrease speed below 0.25)
      handler.handlePointerPanZoomUpdate(const PointerPanZoomUpdateEvent(
        panDelta: Offset(0.0, 5000.0), 
        position: Offset(100, 100), // Left side, triggers speed
      ));
      
      // Step calculation: dy.abs() * 0.005 => 5000 * 0.005 = 25. 
      // 1.0 - 25 = -24 => clamped to 0.25
      expect(virtualSpeed, equals(0.25));

      // Reset and test aggressive scroll up (increase speed above 4.0)
      virtualSpeed = 1.0;
      handler.handlePointerPanZoomUpdate(const PointerPanZoomUpdateEvent(
        panDelta: Offset(0.0, -5000.0), 
        position: Offset(100, 100),
      ));
      
      // Step: 25. 1.0 + 25 = 26.0 => clamped to 4.0
      expect(virtualSpeed, equals(4.0));
      
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('scrubbing throttles player seek calls', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupHandler(ref);
      }));

      // Initialize scrub
      handler.handlePointerPanZoomUpdate(const PointerPanZoomUpdateEvent(
        panDelta: Offset(10.0, 0.0),
        position: Offset(100, 100),
      ));

      expect(scrubThrottleTimer, isNotNull);
      expect(scrubThrottleTimer!.isActive, isTrue);
      
      // Fire a ton of events quickly to ensure throttling
      for(int i = 0; i < 50; i++) {
        handler.handlePointerPanZoomUpdate(const PointerPanZoomUpdateEvent(
          panDelta: Offset(10.0, 0.0),
          position: Offset(100, 100),
        ));
      }
      
      // Total seeks should be heavily throttled, not 50
      final count = verify(() => mockPlayer.seek(any())).callCount;
      expect(count < 10, isTrue); 

      // Wait for throttle timer to complete
      await tester.pump(const Duration(milliseconds: 150));
      
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
