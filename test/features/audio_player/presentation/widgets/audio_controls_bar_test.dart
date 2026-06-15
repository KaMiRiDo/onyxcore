
import 'package:hive/hive.dart' as import_hive;
import 'dart:io' as import_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/audio_controls_bar.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
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
  });

  final dummyTrack = FileItem(
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
      child: const MaterialApp(
        home: Scaffold(
          body: AudioControlsBar(),
        ),
      ),
    );
  }

  group('AudioControlsBar Favorites', () {
    testWidgets('display filled magenta heart when track is a favorite (W-AUD-CTRL-02)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        currentTrackProvider.overrideWithValue(dummyTrack),
      ]));

      // Fake favorites state
      final element = tester.element(find.byType(AudioControlsBar));
      final container = ProviderScope.containerOf(element);
      container.read(audioFavoritesProvider.notifier).state = {dummyTrack.path};

      await tester.pump();

      final iconFinder = find.byIcon(Icons.favorite_rounded);
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.color, AppColors.magenta);
    });

    testWidgets('display outline white70 heart when track is not a favorite (W-AUD-CTRL-03)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        currentTrackProvider.overrideWithValue(dummyTrack),
      ]));

      final iconFinder = find.byIcon(Icons.favorite_border_rounded);
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.color, Colors.white70);
    });

    testWidgets('show SizedBox placeholder when no current track (W-AUD-CTRL-04)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        currentTrackProvider.overrideWithValue(null),
      ]));

      // Should not find any favorite icon
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
      
      // Should find a SizedBox with width 48 as the first child of the Row
      final sizedBoxFinder = find.descendant(
        of: find.byType(Row).first,
        matching: find.byType(SizedBox),
      ).first;
      
      final sizedBox = tester.widget<SizedBox>(sizedBoxFinder);
      expect(sizedBox.width, 48);
    });
  });

  group('AudioControlsBar Volume', () {
    testWidgets('display volume_off icon when volume is 0 (W-AUD-CTRL-07)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        audioVolumeProvider.overrideWith((ref) => Stream.value(0.0)),
      ]));
      await tester.pump();

      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('display volume_up icon when volume is above 0 (W-AUD-CTRL-08)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        audioVolumeProvider.overrideWith((ref) => Stream.value(75.0)),
      ]));
      await tester.pump();

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('display 200% at max volume (W-AUD-CTRL-16)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        audioVolumeProvider.overrideWith((ref) => Stream.value(200.0)),
      ]));
      await tester.pump();

      expect(find.text('200%'), findsOneWidget);
    });

    testWidgets('render volume slider with 100px width (W-AUD-CTRL-27)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        audioVolumeProvider.overrideWith((ref) => Stream.value(100.0)),
      ]));
      await tester.pump();

      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      final sizedBoxFinder = find.ancestor(of: sliderFinder, matching: find.byType(SizedBox)).first;
      final sizedBox = tester.widget<SizedBox>(sizedBoxFinder);
      expect(sizedBox.width, 100);
    });

    testWidgets('turn slider track magenta when volume exceeds 100 (W-AUD-CTRL-11, W-AUD-CTRL-13)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        audioVolumeProvider.overrideWith((ref) => Stream.value(150.0)),
      ]));
      await tester.pump();

      final sliderThemeFinder = find.ancestor(of: find.byType(Slider), matching: find.byType(SliderTheme)).first;
      final sliderTheme = tester.widget<SliderTheme>(sliderThemeFinder);
      
      expect(sliderTheme.data.activeTrackColor, AppColors.magenta);
      expect(sliderTheme.data.thumbColor, AppColors.magenta);
    });

    testWidgets('keep slider track white when volume is at or below 100 (W-AUD-CTRL-12)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        audioVolumeProvider.overrideWith((ref) => Stream.value(75.0)),
      ]));
      await tester.pump();

      final sliderThemeFinder = find.ancestor(of: find.byType(Slider), matching: find.byType(SliderTheme)).first;
      final sliderTheme = tester.widget<SliderTheme>(sliderThemeFinder);
      
      expect(sliderTheme.data.activeTrackColor, Colors.white);
      expect(sliderTheme.data.thumbColor, Colors.white);
    });
  });

  group('AudioControlsBar Playback Controls', () {
    testWidgets('render pause icon when playing (W-AUD-CTRL-20)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        audioPlayingProvider.overrideWith((ref) => Stream.value(true)),
      ]));
      await tester.pump();

      final iconFinder = find.byIcon(Icons.pause_rounded);
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.color, Colors.black);
    });

    testWidgets('render play icon when paused (W-AUD-CTRL-21)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        audioPlayingProvider.overrideWith((ref) => Stream.value(false)),
      ]));
      await tester.pump();

      final iconFinder = find.byIcon(Icons.play_arrow_rounded);
      expect(iconFinder, findsOneWidget);
      final icon = tester.widget<Icon>(iconFinder);
      expect(icon.color, Colors.black);
    });

    testWidgets('render play/pause button with correct dimensions and white background (W-AUD-CTRL-22, W-AUD-CTRL-23)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final containerFinder = find.ancestor(
        of: find.byIcon(Icons.play_arrow_rounded),
        matching: find.byType(Container),
      ).first;

      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;

      expect(container.constraints?.maxWidth, 64);
      expect(container.constraints?.maxHeight, 48);
      expect(decoration.color, Colors.white);
      expect(decoration.borderRadius, BorderRadius.circular(16));
    });

    testWidgets('render skip icons at 32px size (W-AUD-CTRL-24)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final prevIcon = tester.widget<Icon>(find.byIcon(Icons.skip_previous_rounded));
      final nextIcon = tester.widget<Icon>(find.byIcon(Icons.skip_next_rounded));

      expect(prevIcon.size, 32);
      expect(nextIcon.size, 32);
    });

    testWidgets('place 24px spacing between transport controls (W-AUD-CTRL-26)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Find the row containing the transport controls
      final rowFinder = find.ancestor(
        of: find.byIcon(Icons.skip_previous_rounded),
        matching: find.byType(Row),
      ).first;

      final row = tester.widget<Row>(rowFinder);
      
      // Look for SizedBox(width: 24) in the row's children
      int spacingCount = 0;
      for (final child in row.children) {
        if (child is SizedBox && child.width == 24) {
          spacingCount++;
        }
      }
      
      // There should be 2 spacing boxes (between prev and play, and between play and next)
      expect(spacingCount, 2);
    });

    testWidgets('handle null player gracefully no crash on tap (W-AUD-CTRL-30)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        audioPlayerProvider.overrideWith((ref) => null),
      ]));

      // Tapping should not throw exceptions
      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();
      
      // Test passed if no exception was thrown
      expect(true, isTrue);
    });
  });
}
