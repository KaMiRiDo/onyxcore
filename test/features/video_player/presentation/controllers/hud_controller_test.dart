import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/video_player/presentation/controllers/hud_controller.dart';

void main() {
  group('VideoHudController', () {
    late bool mounted;
    late bool isClosing;
    late bool isControlsVisible;
    late bool isScrubbing;
    late bool isMarkerEditorActive;
    late bool isHoveringMarker;
    late bool isAnyMenuVisible;
    late bool isAudioMenuVisible;
    late bool isSubtitleMenuVisible;
    late bool isSpeedMenuVisible;
    late bool isVolumeOverlayVisible;
    late bool isSeekIndicatorVisible;
    late bool showSpeedOverlayVisible;
    late String? windowId;

    Timer? hideTimer;
    Timer? volumeOverlayTimer;
    Timer? speedOverlayTimer;
    Timer? seekIndicatorTimer;
    OverlayEntry? activeMenuEntry;

    late VideoHudCallbacks callbacks;
    late VideoHudController controller;

    Widget buildTestApp(WidgetTester tester, void Function(WidgetRef, BuildContext) onBuild) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) {
                    return Consumer(
                      builder: (context, ref, child) {
                        onBuild(ref, context);
                        return const SizedBox();
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    void setupController(WidgetRef ref, BuildContext context) {
      mounted = true;
      isClosing = false;
      isControlsVisible = false;
      isScrubbing = false;
      isMarkerEditorActive = false;
      isHoveringMarker = false;
      isAnyMenuVisible = false;
      isAudioMenuVisible = false;
      isSubtitleMenuVisible = false;
      isSpeedMenuVisible = false;
      isVolumeOverlayVisible = false;
      isSeekIndicatorVisible = false;
      showSpeedOverlayVisible = false;
      windowId = null;

      hideTimer = null;
      volumeOverlayTimer = null;
      speedOverlayTimer = null;
      seekIndicatorTimer = null;
      activeMenuEntry = null;

      callbacks = VideoHudCallbacks(
        getMounted: () => mounted,
        getIsClosing: () => isClosing,
        getIsControlsVisible: () => isControlsVisible,
        setIsControlsVisible: (v) => isControlsVisible = v,
        getIsScrubbing: () => isScrubbing,
        getIsMarkerEditorActive: () => isMarkerEditorActive,
        getIsHoveringMarker: () => isHoveringMarker,
        getIsAnyMenuVisible: () => isAnyMenuVisible,
        getIsAudioMenuVisible: () => isAudioMenuVisible,
        setIsAudioMenuVisible: (v) => isAudioMenuVisible = v,
        getIsSubtitleMenuVisible: () => isSubtitleMenuVisible,
        setIsSubtitleMenuVisible: (v) => isSubtitleMenuVisible = v,
        getIsSpeedMenuVisible: () => isSpeedMenuVisible,
        setIsSpeedMenuVisible: (v) => isSpeedMenuVisible = v,
        getIsVolumeOverlayVisible: () => isVolumeOverlayVisible,
        setIsVolumeOverlayVisible: (v) => isVolumeOverlayVisible = v,
        getIsSeekIndicatorVisible: () => isSeekIndicatorVisible,
        setIsSeekIndicatorVisible: (v) => isSeekIndicatorVisible = v,
        getShowSpeedOverlayVisible: () => showSpeedOverlayVisible,
        setShowSpeedOverlayVisible: (v) => showSpeedOverlayVisible = v,
        getHideTimer: () => hideTimer,
        setHideTimer: (t) => hideTimer = t,
        getVolumeOverlayTimer: () => volumeOverlayTimer,
        setVolumeOverlayTimer: (t) => volumeOverlayTimer = t,
        getSpeedOverlayTimer: () => speedOverlayTimer,
        setSpeedOverlayTimer: (t) => speedOverlayTimer = t,
        getSeekIndicatorTimer: () => seekIndicatorTimer,
        setSeekIndicatorTimer: (t) => seekIndicatorTimer = t,
        getActiveMenuEntry: () => activeMenuEntry,
        setActiveMenuEntry: (e) => activeMenuEntry = e,
        getWindowId: () => windowId,
        getRef: () => ref,
        setStateCallback: (cb) => cb(),
        getOverlayContext: () => context,
      );

      controller = VideoHudController(callbacks);
    }

    testWidgets('startHideTimer cancels existing and creates new timer', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, setupController));
      isControlsVisible = true;
      controller.startHideTimer();
      expect(hideTimer, isNotNull);
      expect(hideTimer!.isActive, isTrue);

      await tester.pump(const Duration(seconds: 2));
      expect(isControlsVisible, isFalse);
    });

    testWidgets('startHideTimer ignores if menus active', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, setupController));
      isControlsVisible = true;
      isAnyMenuVisible = true;
      controller.startHideTimer();
      expect(hideTimer, isNull);
    });

    testWidgets('showVolumeOverlay sets visibility and starts timer', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, setupController));
      controller.showVolumeOverlay();
      expect(isVolumeOverlayVisible, isTrue);
      expect(volumeOverlayTimer, isNotNull);

      await tester.pump(const Duration(seconds: 3));
      expect(isVolumeOverlayVisible, isFalse);
    });

    testWidgets('showVolumeOverlay ignores if unmounted', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, setupController));
      mounted = false;
      controller.showVolumeOverlay();
      expect(isVolumeOverlayVisible, isFalse);
      
      await tester.pump(const Duration(seconds: 3)); // Clear the timer
    });

    testWidgets('showSpeedOverlay sets visibility and starts timer', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, setupController));
      controller.showSpeedOverlay();
      expect(showSpeedOverlayVisible, isTrue);
      expect(speedOverlayTimer, isNotNull);

      await tester.pump(const Duration(seconds: 3));
      expect(showSpeedOverlayVisible, isFalse);
    });

    testWidgets('showSeekIndicator sets visibility and starts timer', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, setupController));
      controller.showSeekIndicator();
      expect(isSeekIndicatorVisible, isTrue);
      expect(seekIndicatorTimer, isNotNull);

      await tester.pump(const Duration(milliseconds: 1200));
      expect(isSeekIndicatorVisible, isFalse);
    });

    testWidgets('onInteraction handles waking up HUD and resetting hide timer', (tester) async {
      late WidgetRef savedRef;
      await tester.pumpWidget(buildTestApp(tester, (ref, ctx) {
        setupController(ref, ctx);
        savedRef = ref;
      }));

      // Set global HUD to false
      Future.microtask(() => savedRef.read(previewHudVisibleProvider.notifier).state = false);
      await tester.pumpAndSettle();

      isControlsVisible = false;
      controller.onInteraction();
      
      expect(savedRef.read(previewHudVisibleProvider), isTrue);
      expect(isControlsVisible, isTrue);
      expect(hideTimer, isNotNull);
      expect(hideTimer!.isActive, isTrue);
      
      await tester.pump(const Duration(seconds: 2)); // Clear hide timer
    });

    testWidgets('onInteraction ignores if closing or unmounted', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, setupController));
      isClosing = true;
      controller.onInteraction();
      expect(isControlsVisible, isFalse);
    });

    testWidgets('onInteraction ignores hide timer if menu visible', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, setupController));
      isAnyMenuVisible = true;
      controller.onInteraction();
      expect(hideTimer, isNull);
    });

    testWidgets('hideMenu removes overlay and resets state', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) {
                      return Consumer(
                        builder: (context, ref, child) {
                          setupController(ref, context);
                          return Align(
                            alignment: Alignment.bottomRight,
                            child: SizedBox(key: key, width: 50, height: 50),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Call showMenu to get a properly inserted OverlayEntry
      controller.showMenu(key: key, child: const Text('Menu'), type: 'audio');
      expect(activeMenuEntry, isNotNull);
      
      controller.hideMenu();
      
      expect(activeMenuEntry, isNull);
      expect(isAudioMenuVisible, isFalse);
      expect(hideTimer, isNotNull);
      
      await tester.pump(const Duration(seconds: 2)); // Clear hide timer
    });

    testWidgets('hideMenu gracefully handles unmounted state', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, setupController));
      
      isAudioMenuVisible = true;
      mounted = false;
      controller.hideMenu();
      
      // If unmounted, setStateCallback is ignored, but hideTimer is still started.
      expect(activeMenuEntry, isNull);
      await tester.pump(const Duration(seconds: 2)); // Clear hide timer
    });

    testWidgets('showMenu creates overlay and positions it correctly', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) {
                      return Consumer(
                        builder: (context, ref, child) {
                          setupController(ref, context);
                          return Align(
                            alignment: Alignment.bottomRight,
                            child: SizedBox(key: key, width: 50, height: 50),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Call showMenu
      controller.showMenu(key: key, child: const Text('Menu'), type: 'audio');

      expect(activeMenuEntry, isNotNull);
      expect(isAudioMenuVisible, isTrue);

      // Verify overlay gets inserted
      await tester.pump();
      expect(find.text('Menu'), findsOneWidget);
    });

    testWidgets('showMenu speed type sets right alignment', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) {
                      return Consumer(
                        builder: (context, ref, child) {
                          setupController(ref, context);
                          return Align(
                            alignment: Alignment.bottomRight,
                            child: SizedBox(key: key, width: 50, height: 50),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Call showMenu with 'speed'
      controller.showMenu(key: key, child: const Text('SpeedMenu'), type: 'speed');

      expect(activeMenuEntry, isNotNull);
      expect(isSpeedMenuVisible, isTrue);
      
      await tester.pump();
      expect(find.text('SpeedMenu'), findsOneWidget);
      
      // Test the background tap correctly closes the menu
      await tester.tapAt(const Offset(10, 10)); // Tap far away from menu
      expect(activeMenuEntry, isNull);
      
      await tester.pump(const Duration(seconds: 2)); // Clear hide timer
    });

    testWidgets('showMenu aborts if unmounted or renderbox missing', (tester) async {
      await tester.pumpWidget(buildTestApp(tester, setupController));
      final key = GlobalKey();
      
      // Missing renderbox
      controller.showMenu(key: key, child: const SizedBox(), type: 'audio');
      expect(activeMenuEntry, isNull);
      
      mounted = false;
      controller.showMenu(key: key, child: const SizedBox(), type: 'audio');
      expect(activeMenuEntry, isNull);
    });

  });
}
