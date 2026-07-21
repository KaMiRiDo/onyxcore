import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/video_player/presentation/controllers/seek_controller.dart';

class MockPlayer extends Mock implements Player {}
class MockPlayerState extends Mock implements PlayerState {}

class MockSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => const AppSettings();
}

void main() {
  group('VideoSeekController', () {
    late MockPlayer mockPlayer;
    late MockPlayerState mockPlayerState;

    late bool mounted;
    late bool isClosing;
    late bool isFastSeeking;
    late bool isScrubbing;
    late Duration? virtualSeekPosition;
    late Duration? virtualScrubPosition;
    late Duration? pendingScrubPosition;
    late bool wasPlayingBeforeScrub;
    late bool isSmartBuffering;
    late String? scrollLockAxis;
    late LogicalKeyboardKey? activeSeekKey;
    late DateTime lastEngineSeekTime;
    late int cleanupRetryCount;

    Timer? engineSeekTimer;
    Timer? virtualSeekCleanupTimer;
    Timer? fastSeekTimer;
    Timer? seekLoaderTimer;

    late bool showSeekIndicatorCalled;
    late bool onInteractionCalled;
    late bool isSeekLoading;
    late Duration? preSeekPosition;
    late DateTime? lastSeekTime;

    late VideoSeekCallbacks callbacks;
    late VideoSeekController controller;

    Widget buildTestApp(WidgetTester tester, Function(WidgetRef) onBuild) {
      return ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, child) {
                onBuild(ref);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    }

    void setupController(WidgetRef ref) {
      mockPlayer = MockPlayer();
      mockPlayerState = MockPlayerState();
      when(() => mockPlayer.state).thenReturn(mockPlayerState);
      when(() => mockPlayerState.duration).thenReturn(const Duration(seconds: 100));
      when(() => mockPlayerState.position).thenReturn(const Duration(seconds: 10));
      when(() => mockPlayerState.playing).thenReturn(true);
      when(() => mockPlayer.pause()).thenAnswer((_) async {});
      when(() => mockPlayer.play()).thenAnswer((_) async {});
      when(() => mockPlayer.seek(any())).thenAnswer((_) async {});

      mounted = true;
      isClosing = false;
      isFastSeeking = false;
      isScrubbing = false;
      virtualSeekPosition = null;
      virtualScrubPosition = null;
      pendingScrubPosition = null;
      wasPlayingBeforeScrub = false;
      isSmartBuffering = false;
      scrollLockAxis = null;
      activeSeekKey = null;
      lastEngineSeekTime = DateTime.fromMillisecondsSinceEpoch(0);
      cleanupRetryCount = 0;

      engineSeekTimer = null;
      virtualSeekCleanupTimer = null;
      fastSeekTimer = null;
      seekLoaderTimer = null;

      showSeekIndicatorCalled = false;
      onInteractionCalled = false;
      isSeekLoading = false;
      preSeekPosition = null;
      lastSeekTime = null;

      callbacks = VideoSeekCallbacks(
        getPlayer: () => mockPlayer,
        getRef: () => ref,
        getMounted: () => mounted,
        getIsClosing: () => isClosing,
        getIsFastSeeking: () => isFastSeeking,
        setIsFastSeeking: (v) => isFastSeeking = v,
        getIsScrubbing: () => isScrubbing,
        setIsScrubbing: (v) => isScrubbing = v,
        getVirtualSeekPosition: () => virtualSeekPosition,
        setVirtualSeekPosition: (v) => virtualSeekPosition = v,
        getVirtualScrubPosition: () => virtualScrubPosition,
        setVirtualScrubPosition: (v) => virtualScrubPosition = v,
        getPendingScrubPosition: () => pendingScrubPosition,
        setPendingScrubPosition: (v) => pendingScrubPosition = v,
        getWasPlayingBeforeScrub: () => wasPlayingBeforeScrub,
        setWasPlayingBeforeScrub: (v) => wasPlayingBeforeScrub = v,
        getIsSmartBuffering: () => isSmartBuffering,
        setIsSmartBuffering: (v) => isSmartBuffering = v,
        getScrollLockAxis: () => scrollLockAxis,
        getActiveSeekKey: () => activeSeekKey,
        setActiveSeekKey: (k) => activeSeekKey = k,
        getLastEngineSeekTime: () => lastEngineSeekTime,
        setLastEngineSeekTime: (t) => lastEngineSeekTime = t,
        getThrottleMs: () => 100,
        getDebounceMs: () => 200,
        getCleanupRetryCount: () => cleanupRetryCount,
        setCleanupRetryCount: (c) => cleanupRetryCount = c,
        getEngineSeekTimer: () => engineSeekTimer,
        setEngineSeekTimer: (t) => engineSeekTimer = t,
        getVirtualSeekCleanupTimer: () => virtualSeekCleanupTimer,
        setVirtualSeekCleanupTimer: (t) => virtualSeekCleanupTimer = t,
        getFastSeekTimer: () => fastSeekTimer,
        setFastSeekTimer: (t) => fastSeekTimer = t,
        getSeekLoaderTimer: () => seekLoaderTimer,
        setSeekLoaderTimer: (t) => seekLoaderTimer = t,
        setIsSeekLoading: (v) => isSeekLoading = v,
        setPreSeekPosition: (v) => preSeekPosition = v,
        setLastSeekTime: (t) => lastSeekTime = t,
        showSeekIndicator: () => showSeekIndicatorCalled = true,
        onInteraction: () => onInteractionCalled = true,
        setStateCallback: (cb) => cb(),
      );

      controller = VideoSeekController(callbacks);
    }
    
    setUpAll(() {
      registerFallbackValue(const Duration(seconds: 0));
    });

    testWidgets('requestEngineSeek updates virtual position instantly and throttles', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupController(ref);
      }));

      final target = const Duration(seconds: 20);
      controller.requestEngineSeek(target);

      expect(virtualSeekPosition, equals(target));
      expect(isScrubbing, isFalse);
      verify(() => mockPlayer.pause()).called(1);
      verify(() => mockPlayer.seek(target)).called(1); // Since throttle time > 100ms from epoch
      
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('startFastSeek starts fast seek timer and performs step', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupController(ref);
      }));

      controller.startFastSeek(isForward: true);

      expect(isFastSeeking, isTrue);
      expect(showSeekIndicatorCalled, isTrue);
      expect(onInteractionCalled, isTrue);
      expect(fastSeekTimer, isNotNull);
      expect(fastSeekTimer!.isActive, isTrue);
      
      controller.stopFastSeek();
      expect(fastSeekTimer, isNull);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('slider handlers update scrub state and perform seek', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupController(ref);
      }));

      // Start
      controller.handleSliderChangeStart();
      expect(isScrubbing, isTrue);
      expect(wasPlayingBeforeScrub, isTrue);
      verify(() => mockPlayer.pause()).called(1);

      // Changed
      controller.handleSliderChanged(0.5); // 50% of 100s = 50s
      expect(virtualScrubPosition, equals(const Duration(seconds: 50)));
      verify(() => mockPlayer.seek(const Duration(seconds: 50))).called(1);

      // End
      controller.handleSliderChangeEnd(0.6); // 60s
      verify(() => mockPlayer.seek(const Duration(seconds: 60))).called(1);
      verify(() => mockPlayer.play()).called(1);

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('cleanupVirtualSeeking resets all temporary seek state', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupController(ref);
      }));

      isFastSeeking = true;
      virtualSeekPosition = const Duration(seconds: 5);
      isScrubbing = true;
      virtualScrubPosition = const Duration(seconds: 10);
      wasPlayingBeforeScrub = true;

      controller.cleanupVirtualSeeking();

      expect(isFastSeeking, isFalse);
      expect(virtualSeekPosition, isNull);
      expect(isScrubbing, isFalse);
      expect(virtualScrubPosition, isNull);
      verify(() => mockPlayer.play()).called(1);

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('requestEngineSeek uses debounce timer if called rapidly', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupController(ref);
      }));

      lastEngineSeekTime = DateTime.now(); // Simulate a seek just happened
      final target = const Duration(seconds: 25);
      
      controller.requestEngineSeek(target);

      // Should set debounce timer, NOT call seek instantly
      expect(engineSeekTimer, isNotNull);
      expect(engineSeekTimer!.isActive, isTrue);
      verifyNever(() => mockPlayer.seek(target));

      // Wait for debounce timer (200ms)
      await tester.pump(const Duration(milliseconds: 250));
      verify(() => mockPlayer.seek(target)).called(1);
      
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('scheduleVirtualStateCleanup retries if engineSeekTimer active', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupController(ref);
      }));

      // Start engine timer to simulate active debouncing
      engineSeekTimer = Timer(const Duration(seconds: 10), () {});

      controller.scheduleVirtualStateCleanup();
      
      // The cleanup timer is 1200ms. If we advance time, it should retry.
      await tester.pump(const Duration(milliseconds: 1250));
      expect(cleanupRetryCount, equals(1));
      
      // Advance enough times to hit max retries (5)
      await tester.pump(const Duration(milliseconds: 1250));
      await tester.pump(const Duration(milliseconds: 1250));
      await tester.pump(const Duration(milliseconds: 1250));
      await tester.pump(const Duration(milliseconds: 1250));
      
      // Once it exceeds retries, it clears state anyway
      expect(virtualSeekPosition, isNull);
      
      engineSeekTimer?.cancel();
    });

    testWidgets('startFastSeek periodic timer continues to seek', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupController(ref);
      }));

      controller.startFastSeek(isForward: true);

      // Initial step seek called
      verify(() => mockPlayer.seek(any())).called(1);

      // Advance by 500ms to allow periodic timer to fire and set debounce timers.
      // Since DateTime.now() doesn't advance in tests automatically, the debounce timer keeps resetting.
      await tester.pump(const Duration(milliseconds: 500));

      // Stop fast seek should force the latest debounced seek to execute
      controller.stopFastSeek();
      
      // Verify seek was called for the updated position
      verify(() => mockPlayer.seek(any())).called(1);
      
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('performStepSeek resets scrub state if scrub was active', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupController(ref);
      }));

      virtualScrubPosition = const Duration(seconds: 50);
      isFastSeeking = true;
      virtualSeekPosition = const Duration(seconds: 5); // Should be ignored/overwritten

      controller.performStepSeek(isForward: true);

      // virtualScrubPosition should be null now
      expect(virtualScrubPosition, isNull);
      // It should seek to 50 + 10 = 60s
      verify(() => mockPlayer.seek(const Duration(seconds: 60))).called(1);
      
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('stopFastSeek forces engine timer to fire immediately', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref) {
        setupController(ref);
      }));

      // Setup a pending debounced seek
      engineSeekTimer = Timer(const Duration(seconds: 5), () {});
      virtualSeekPosition = const Duration(seconds: 35);
      
      controller.stopFastSeek();
      
      // Should immediately dispatch
      verify(() => mockPlayer.seek(const Duration(seconds: 35))).called(1);
      
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
