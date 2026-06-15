
import 'package:hive/hive.dart' as import_hive;
import 'dart:io' as import_io;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/audio_player/presentation/pages/audio_player_view.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import "package:onyxcore/core/utils/media_uri_helper.dart";
import 'package:riverpod/riverpod.dart' as riverpod;
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    MediaKit.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    try {
      import_hive.Hive.init(import_io.Directory.systemTemp.path);
    } catch (_) {}
    
    // Start local proxy before tests to prevent its internal HttpServer timer from failing a test
    await MediaUriHelper.ensureLocalProxy();
  });

  final dummyFile = FileItem(
    name: 'test.mp3',
    path: '/path/test.mp3',
    type: FileItemType.audio,
    modified: DateTime.now(),
  );

  Widget buildTestWidget({List<dynamic> overrides = const []}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides.cast()
      ],
      child: MaterialApp(
        home: Scaffold(
          body: AudioPlayerView(
            isStandalone: true,
            item: dummyFile,
            
          ),
        ),
      ),
    );
  }

  group('AudioPlayerView Tests', () {
    testWidgets('toggle playlist sidebar visibility on Ctrl+Shift+P (W-AUD-VIEW-58)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        currentTrackProvider.overrideWithValue(dummyFile),
        audioPlaylistSidebarVisibleProvider.overrideWith((ref) => true),
      ]));
      await tester.pump(const Duration(milliseconds: 500));

      final element = tester.element(find.byType(AudioPlayerView));
      final container = ProviderScope.containerOf(element);

      // Verify visible initially
      expect(container.read(audioPlaylistSidebarVisibleProvider), true);

      // Press Ctrl+Shift+P
      await simulateKeyDownEvent(LogicalKeyboardKey.control);
      await simulateKeyDownEvent(LogicalKeyboardKey.shift);
      await simulateKeyDownEvent(LogicalKeyboardKey.keyP);
      
      await tester.pump();
      
      await simulateKeyUpEvent(LogicalKeyboardKey.keyP);
      await simulateKeyUpEvent(LogicalKeyboardKey.shift);
      await simulateKeyUpEvent(LogicalKeyboardKey.control);

      await tester.pump(const Duration(milliseconds: 500));

      // Check state
      expect(container.read(audioPlaylistSidebarVisibleProvider), false);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('toggle playlist sidebar via bottom-left button (W-AUD-VIEW-59)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        currentTrackProvider.overrideWithValue(dummyFile),
      ]));
      
      await tester.pump(const Duration(milliseconds: 500));
      
      final element = tester.element(find.byType(AudioPlayerView));
      final container = ProviderScope.containerOf(element);

      // Verify initially true
      expect(container.read(audioPlaylistSidebarVisibleProvider), true);

      // The toggle button should have the panel_right icon (which we use for sidebar toggle)
      // Actually wait, let's find the IconButton by Tooltip "Hide Playlist"
      final toggleFinder = find.byTooltip('Hide playlist');
      expect(toggleFinder, findsOneWidget);

      await tester.tap(toggleFinder);
      await tester.pump(const Duration(milliseconds: 500));

      // State is false
      expect(container.read(audioPlaylistSidebarVisibleProvider), false);
      
      // Tooltip changes
      expect(find.byTooltip('Show playlist'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('resize sidebar by dragging the handle (W-AUD-VIEW-60)', (tester) async {
      // Setup window size to ensure predictable drag
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(buildTestWidget(overrides: [
        currentTrackProvider.overrideWithValue(dummyFile),
      ]));
      
      await tester.pump(const Duration(milliseconds: 500));

      final element = tester.element(find.byType(AudioPlayerView));
      final container = ProviderScope.containerOf(element);

      // Find the resize handle. It's a GestureDetector that has onHorizontalDragUpdate.
      // We can find it by looking for the MouseRegion with resizeColumn cursor inside a GestureDetector
      final resizeHandleFinder = find.descendant(
        of: find.byType(GestureDetector),
        matching: find.byWidgetPredicate((widget) => 
          widget is MouseRegion && widget.cursor == SystemMouseCursors.resizeColumn
        ),
      ).first;

      expect(resizeHandleFinder, findsOneWidget);

      // Read initial width provider
      final initialWidth = container.read(audioPlaylistSidebarWidthProvider) ?? 250.0;

      // Start drag left by 100 pixels
      await tester.drag(resizeHandleFinder, const Offset(-100, 0));
      await tester.pump(const Duration(milliseconds: 500));

      final updatedWidth = container.read(audioPlaylistSidebarWidthProvider);
      
      // Width should have changed
      expect(updatedWidth, isNot(initialWidth));
      
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      
      await tester.pump(const Duration(seconds: 3));
      
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('lock resizeColumn cursor globally during drag (W-AUD-VIEW-61)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        currentTrackProvider.overrideWithValue(dummyFile),
      ]));
      
      await tester.pump(const Duration(milliseconds: 500));
      
      final element = tester.element(find.byType(AudioPlayerView));
      final container = ProviderScope.containerOf(element);

      expect(container.read(isAudioPlaylistSidebarDraggingProvider), false);

      final resizeHandleFinder = find.descendant(
        of: find.byType(GestureDetector),
        matching: find.byWidgetPredicate((widget) => 
          widget is MouseRegion && widget.cursor == SystemMouseCursors.resizeColumn
        ),
      ).first;

      final gesture = await tester.startGesture(tester.getCenter(resizeHandleFinder));
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump();

      // State is true
      expect(container.read(isAudioPlaylistSidebarDraggingProvider), isTrue);
      
      // We cannot easily test the global cursor because Flutter test framework doesn't expose MouseTracker easily.
      // But we can verify the state changed.
      
      await tester.pump(const Duration(seconds: 3));
      
      final globalRegionFinder = find.byWidgetPredicate((widget) => 
        widget is MouseRegion && widget.cursor == SystemMouseCursors.resizeColumn
      );
      
      // There's the global one and the handle itself
      expect(globalRegionFinder, findsWidgets);
      
      await gesture.up();

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));

      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('clear selection on GestureDetector tap in hero pane (W-AUD-VIEW-55)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        currentTrackProvider.overrideWithValue(dummyFile),
      ]));
      await tester.pump(const Duration(milliseconds: 500));

      final element = tester.element(find.byType(AudioPlayerView));
      final container = ProviderScope.containerOf(element);

      container.read(audioSelectionProvider.notifier).state = {dummyFile.path};
      expect(container.read(audioSelectionProvider), isNotEmpty);

      // Find the hero pane GestureDetector. It covers the Expanded area.
      final expandedHeroFinder = find.ancestor(
        of: find.byIcon(Icons.music_note_rounded), // fallback icon in HeroAudioPlayer
        matching: find.byType(Expanded),
      ).first;

      final gestureDetectorFinder = find.descendant(
        of: expandedHeroFinder,
        matching: find.byType(GestureDetector),
      ).first;

      // We might have multiple GestureDetectors, let's tap the top-left area of the hero pane
      await tester.tapAt(tester.getTopLeft(expandedHeroFinder) + const Offset(10, 10));
      await tester.pump();

      expect(container.read(audioSelectionProvider).isEmpty, true);
      
      await tester.pump(const Duration(milliseconds: 100)); // Let gesture arena resolve
      
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
      
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
