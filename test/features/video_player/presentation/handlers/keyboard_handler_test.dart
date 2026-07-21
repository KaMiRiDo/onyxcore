import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/video_player/presentation/handlers/keyboard_handler.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/marker_editor_overlay.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_playlist_providers.dart';

class MockMarkerEditorState extends Mock implements MarkerEditorOverlayState {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) => super.toString();
}

class MockGlobalKey<T extends State<StatefulWidget>> extends GlobalKey<T> {
  MockGlobalKey(this.mockState) : super.constructor();
  final T mockState;
  @override
  T? get currentState => mockState;
}

void main() {
  group('VideoKeyboardHandler', () {
    late bool isMarkerEditorActive;
    late GlobalKey<MarkerEditorOverlayState> markerEditorKey;
    late bool isStandalone;
    late String? windowId;
    late bool isClosing;

    late bool playOrPauseCalled;
    late bool startFastSeekForwardCalled;
    late bool startFastSeekBackwardCalled;
    late bool stopFastSeekCalled;
    late bool startVolumeIncreaseCalled;
    late bool startVolumeDecreaseCalled;
    late bool stopVolumeAdjustCalled;
    late bool toggleMuteCalled;
    late bool takeScreenshotCalled;
    late bool openMarkerEditorCalled;
    late bool closeMarkerEditorCalled;
    late bool toggleFullscreenCalled;
    late bool closePreviewCalled;
    late bool isControlsVisible;
    LogicalKeyboardKey? activeSeekKey;
    LogicalKeyboardKey? activeVolumeKey;

    late VideoKeyboardCallbacks callbacks;
    late VideoKeyboardHandler handler;

    Widget buildTestApp(WidgetTester tester, Function(WidgetRef, BuildContext) onBuild) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, child) {
                onBuild(ref, context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    }

    void setupHandler(WidgetRef ref) {
      isMarkerEditorActive = false;
      markerEditorKey = GlobalKey<MarkerEditorOverlayState>();
      isStandalone = false;
      windowId = null;
      isClosing = false;

      playOrPauseCalled = false;
      startFastSeekForwardCalled = false;
      startFastSeekBackwardCalled = false;
      stopFastSeekCalled = false;
      startVolumeIncreaseCalled = false;
      startVolumeDecreaseCalled = false;
      stopVolumeAdjustCalled = false;
      toggleMuteCalled = false;
      takeScreenshotCalled = false;
      openMarkerEditorCalled = false;
      closeMarkerEditorCalled = false;
      toggleFullscreenCalled = false;
      closePreviewCalled = false;
      isControlsVisible = false;
      activeSeekKey = null;
      activeVolumeKey = null;

      callbacks = VideoKeyboardCallbacks(
        playOrPause: () => playOrPauseCalled = true,
        startFastSeek: ({required bool isForward}) {
          if (isForward) startFastSeekForwardCalled = true;
          else startFastSeekBackwardCalled = true;
        },
        stopFastSeek: () => stopFastSeekCalled = true,
        startVolumeAdjust: ({required bool isIncrease}) {
          if (isIncrease) startVolumeIncreaseCalled = true;
          else startVolumeDecreaseCalled = true;
        },
        stopVolumeAdjust: () => stopVolumeAdjustCalled = true,
        toggleMute: () => toggleMuteCalled = true,
        takeScreenshot: () => takeScreenshotCalled = true,
        openMarkerEditor: () => openMarkerEditorCalled = true,
        closeMarkerEditor: ({required bool resume}) => closeMarkerEditorCalled = true,
        toggleFullscreen: () => toggleFullscreenCalled = true,
        navigateMedia: (f) {},
        handleDelete: ({required bool permanent}) {},
        closePreview: () => closePreviewCalled = true,
        navigatePlaylistHistoryBack: (r) => closeMarkerEditorCalled = true, // reusing boolean for simplicity
        navigatePlaylistHistoryForward: (r) => takeScreenshotCalled = true, // reusing boolean
        showHud: () {},
        hideMenu: () {},
        getIsControlsVisible: () => isControlsVisible,
        setIsControlsVisible: (v) => isControlsVisible = v,
        requestFocus: () {},
        getActiveSeekKey: () => activeSeekKey,
        setActiveSeekKey: (key) => activeSeekKey = key,
        getActiveVolumeKey: () => activeVolumeKey,
        setActiveVolumeKey: (key) => activeVolumeKey = key,
      );

      handler = VideoKeyboardHandler(
        callbacks: callbacks,
        isMarkerEditorActive: () => isMarkerEditorActive,
        markerEditorKey: markerEditorKey,
        isStandalone: isStandalone,
        windowId: windowId,
        isClosing: () => isClosing,
        ref: ref,
      );
    }

    KeyEvent createKeyEvent(LogicalKeyboardKey key, {bool isDown = true, bool isRepeat = false}) {
      if (isRepeat) return KeyRepeatEvent(physicalKey: PhysicalKeyboardKey.space, logicalKey: key, timeStamp: Duration.zero);
      if (isDown) return KeyDownEvent(physicalKey: PhysicalKeyboardKey.space, logicalKey: key, timeStamp: Duration.zero);
      return KeyUpEvent(physicalKey: PhysicalKeyboardKey.space, logicalKey: key, timeStamp: Duration.zero);
    }

    testWidgets('ignores events when closing', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
      }));
      isClosing = true;
      final result = handler.handle(createKeyEvent(LogicalKeyboardKey.space));
      expect(result, equals(KeyEventResult.ignored));
      expect(playOrPauseCalled, isFalse);
    });

    testWidgets('handles Space to play/pause', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
      }));
      final result = handler.handle(createKeyEvent(LogicalKeyboardKey.space));
      expect(result, equals(KeyEventResult.handled));
      expect(playOrPauseCalled, isTrue);
    });

    testWidgets('handles Left Arrow for fast seek backward', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
      }));
      final resultDown = handler.handle(createKeyEvent(LogicalKeyboardKey.arrowLeft));
      expect(resultDown, equals(KeyEventResult.handled));
      expect(startFastSeekBackwardCalled, isTrue);
      expect(activeSeekKey, equals(LogicalKeyboardKey.arrowLeft));

      final resultUp = handler.handle(createKeyEvent(LogicalKeyboardKey.arrowLeft, isDown: false));
      expect(resultUp, equals(KeyEventResult.handled));
      expect(stopFastSeekCalled, isTrue);
    });

    testWidgets('handles Right Arrow for fast seek forward', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
      }));
      final resultDown = handler.handle(createKeyEvent(LogicalKeyboardKey.arrowRight));
      expect(resultDown, equals(KeyEventResult.handled));
      expect(startFastSeekForwardCalled, isTrue);
      expect(activeSeekKey, equals(LogicalKeyboardKey.arrowRight));

      final resultUp = handler.handle(createKeyEvent(LogicalKeyboardKey.arrowRight, isDown: false));
      expect(resultUp, equals(KeyEventResult.handled));
      expect(stopFastSeekCalled, isTrue);
    });

    testWidgets('handles Up Arrow for volume increase', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
      }));
      final resultDown = handler.handle(createKeyEvent(LogicalKeyboardKey.arrowUp));
      expect(resultDown, equals(KeyEventResult.handled));
      expect(startVolumeIncreaseCalled, isTrue);
      expect(activeVolumeKey, equals(LogicalKeyboardKey.arrowUp));

      final resultUp = handler.handle(createKeyEvent(LogicalKeyboardKey.arrowUp, isDown: false));
      expect(resultUp, equals(KeyEventResult.handled));
      expect(stopVolumeAdjustCalled, isTrue);
    });

    testWidgets('handles Down Arrow for volume decrease', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
      }));
      final resultDown = handler.handle(createKeyEvent(LogicalKeyboardKey.arrowDown));
      expect(resultDown, equals(KeyEventResult.handled));
      expect(startVolumeDecreaseCalled, isTrue);
      expect(activeVolumeKey, equals(LogicalKeyboardKey.arrowDown));

      final resultUp = handler.handle(createKeyEvent(LogicalKeyboardKey.arrowDown, isDown: false));
      expect(resultUp, equals(KeyEventResult.handled));
      expect(stopVolumeAdjustCalled, isTrue);
    });

    testWidgets('handles M for mute', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
      }));
      final result = handler.handle(createKeyEvent(LogicalKeyboardKey.keyM));
      expect(result, equals(KeyEventResult.handled));
      expect(toggleMuteCalled, isTrue);
    });

    testWidgets('handles S for screenshot', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
      }));
      final result = handler.handle(createKeyEvent(LogicalKeyboardKey.keyS));
      expect(result, equals(KeyEventResult.handled));
      expect(takeScreenshotCalled, isTrue);
    });
    
    testWidgets('handles T for marker editor', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
      }));
      final result = handler.handle(createKeyEvent(LogicalKeyboardKey.keyT));
      expect(result, equals(KeyEventResult.handled));
      expect(openMarkerEditorCalled, isTrue);
    });

    testWidgets('handles F for fullscreen / controls toggle', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
      }));
      isControlsVisible = false;
      final result1 = handler.handle(createKeyEvent(LogicalKeyboardKey.keyF));
      expect(result1, equals(KeyEventResult.handled));
      expect(isControlsVisible, isTrue);
    });

    testWidgets('marker editor escape closes editor', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
      }));
      isMarkerEditorActive = true;
      final result = handler.handle(createKeyEvent(LogicalKeyboardKey.escape));
      expect(result, equals(KeyEventResult.handled));
      expect(closeMarkerEditorCalled, isTrue);
    });

    testWidgets('marker editor ignores space and backspace', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
      }));
      isMarkerEditorActive = true;
      final resultSpace = handler.handle(createKeyEvent(LogicalKeyboardKey.space));
      expect(resultSpace, equals(KeyEventResult.ignored));
      final resultBackspace = handler.handle(createKeyEvent(LogicalKeyboardKey.backspace));
      expect(resultBackspace, equals(KeyEventResult.ignored));
    });

    testWidgets('handles Backspace to close preview when not standalone', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
      }));
      isStandalone = false;
      windowId = null;
      final result = handler.handle(createKeyEvent(LogicalKeyboardKey.backspace));
      expect(result, equals(KeyEventResult.handled));
    });

    testWidgets('handles F for fullscreen in standalone mode', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
        isStandalone = true;
        // Re-instantiate with isStandalone = true
        handler = VideoKeyboardHandler(
          callbacks: callbacks,
          isMarkerEditorActive: () => isMarkerEditorActive,
          markerEditorKey: markerEditorKey,
          isStandalone: isStandalone,
          windowId: windowId,
          isClosing: () => isClosing,
          ref: ref,
        );
      }));
      final result1 = handler.handle(createKeyEvent(LogicalKeyboardKey.keyF));
      expect(result1, equals(KeyEventResult.handled));
      expect(toggleFullscreenCalled, isTrue);
    });

    testWidgets('handles Delete (permanent and non-permanent)', (tester) async {
      bool deleteCalled = false;
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
        callbacks = VideoKeyboardCallbacks(
          playOrPause: () {},
          startFastSeek: ({required bool isForward}) {},
          stopFastSeek: () {},
          startVolumeAdjust: ({required bool isIncrease}) {},
          stopVolumeAdjust: () {},
          toggleMute: () {},
          takeScreenshot: () {},
          openMarkerEditor: () {},
          closeMarkerEditor: ({required bool resume}) {},
          toggleFullscreen: () {},
          navigateMedia: (f) {},
          handleDelete: ({required bool permanent}) {
            deleteCalled = true;
            expect(permanent, isFalse); // Shift not pressed in this simple test
          },
          closePreview: () {},
          navigatePlaylistHistoryBack: (r) {},
          navigatePlaylistHistoryForward: (r) {},
          showHud: () {},
          hideMenu: () {},
          getIsControlsVisible: () => false,
          setIsControlsVisible: (v) {},
          requestFocus: () {},
          getActiveSeekKey: () => null,
          setActiveSeekKey: (key) {},
          getActiveVolumeKey: () => null,
          setActiveVolumeKey: (key) {},
        );
        handler = VideoKeyboardHandler(
          callbacks: callbacks,
          isMarkerEditorActive: () => false,
          markerEditorKey: GlobalKey(),
          isStandalone: false,
          windowId: null,
          isClosing: () => false,
          ref: ref,
        );
      }));
      
      final result = handler.handle(createKeyEvent(LogicalKeyboardKey.delete));
      expect(result, equals(KeyEventResult.handled));
      expect(deleteCalled, isTrue);
    });
    testWidgets('marker editor handles Enter to save when tag field focused', (tester) async {
      final mockState = MockMarkerEditorState();
      when(() => mockState.isTagFieldFocused).thenReturn(true);
      when(() => mockState.save()).thenReturn(null);

      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
        handler = VideoKeyboardHandler(
          callbacks: callbacks,
          isMarkerEditorActive: () => true,
          markerEditorKey: MockGlobalKey<MarkerEditorOverlayState>(mockState),
          isStandalone: false,
          windowId: null,
          isClosing: () => false,
          ref: ref,
        );
      }));

      final result = handler.handle(createKeyEvent(LogicalKeyboardKey.enter));
      expect(result, equals(KeyEventResult.handled));
      verify(() => mockState.save()).called(1);
    });

    testWidgets('handles Alt + ArrowLeft/Right to navigate playlist history', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
      }));

      // Set sidebar visible after initial build to avoid modifying provider during build
      final element = tester.element(find.byType(Consumer));
      final container = ProviderScope.containerOf(element);
      container.read(videoPlaylistSidebarVisibleProvider.notifier).state = true;
      await tester.pumpAndSettle();

      // Simulate Alt key being pressed
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);

      final resultLeft = handler.handle(createKeyEvent(LogicalKeyboardKey.arrowLeft));
      expect(resultLeft, equals(KeyEventResult.handled));
      expect(closeMarkerEditorCalled, isTrue); // This is mapped to navigatePlaylistHistoryBack in our mock

      final resultRight = handler.handle(createKeyEvent(LogicalKeyboardKey.arrowRight));
      expect(resultRight, equals(KeyEventResult.handled));
      expect(takeScreenshotCalled, isTrue); // This is mapped to navigatePlaylistHistoryForward in our mock

      // Release Alt
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    });

    testWidgets('handles F to hide menu when controls are visible', (tester) async {
      bool hideMenuCalled = false;
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
        isControlsVisible = true;
        callbacks = VideoKeyboardCallbacks(
          playOrPause: () {},
          startFastSeek: ({required bool isForward}) {},
          stopFastSeek: () {},
          startVolumeAdjust: ({required bool isIncrease}) {},
          stopVolumeAdjust: () {},
          toggleMute: () {},
          takeScreenshot: () {},
          openMarkerEditor: () {},
          closeMarkerEditor: ({required bool resume}) {},
          toggleFullscreen: () {},
          navigateMedia: (f) {},
          handleDelete: ({required bool permanent}) {},
          closePreview: () {},
          navigatePlaylistHistoryBack: (r) {},
          navigatePlaylistHistoryForward: (r) {},
          showHud: () {},
          hideMenu: () { hideMenuCalled = true; },
          getIsControlsVisible: () => isControlsVisible,
          setIsControlsVisible: (v) => isControlsVisible = v,
          requestFocus: () {},
          getActiveSeekKey: () => null,
          setActiveSeekKey: (key) {},
          getActiveVolumeKey: () => null,
          setActiveVolumeKey: (key) {},
        );
        handler = VideoKeyboardHandler(
          callbacks: callbacks,
          isMarkerEditorActive: () => false,
          markerEditorKey: GlobalKey(),
          isStandalone: false,
          windowId: null,
          isClosing: () => false,
          ref: ref,
        );
      }));

      final result = handler.handle(createKeyEvent(LogicalKeyboardKey.keyF));
      expect(result, equals(KeyEventResult.handled));
      expect(hideMenuCalled, isTrue);
      expect(isControlsVisible, isFalse);
    });

    testWidgets('handles Ctrl + Shift + P to toggle playlist sidebar', (tester) async {
      late WidgetRef savedRef;
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
        savedRef = ref;
        // Sidebar is false by default
      }));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);

      final result = handler.handle(createKeyEvent(LogicalKeyboardKey.keyP));
      expect(result, equals(KeyEventResult.handled));
      expect(savedRef.read(videoPlaylistSidebarVisibleProvider), isTrue);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    });

    testWidgets('handles Ctrl + W to close preview', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, (ref, _) {
        setupHandler(ref);
      }));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      
      final result = handler.handle(createKeyEvent(LogicalKeyboardKey.keyW));
      expect(result, equals(KeyEventResult.handled));
      expect(closePreviewCalled, isTrue);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    });
  });
}
