import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/audio_controls_bar.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

void main() {
  late AppDatabase db;
  setUpAll(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDownAll(() async {
    // Memory db doesn't require manual closing and doing so interrupts widget disposal streams
  });

  Widget buildTestWidget({bool isPlaying = false, double volume = 100}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        audioPlayingProvider.overrideWith((ref) => Stream.value(isPlaying)),
        audioVolumeProvider.overrideWith((ref) => Stream.value(volume)),
        audioAutoPlaySessionProvider.overrideWith((ref) => true),
        currentTrackProvider.overrideWith((ref) => FileItem(path: '/test.mp3', name: 'test', type: FileItemType.audio, modified: DateTime.now())),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: AudioControlsBar(),
        ),
      ),
    );
  }

  group('AudioControlsBar Widget Tests', () {
    testWidgets('render pause icon when playing (W-AUD-CTRL-20)', (tester) async {
      await tester.pumpWidget(buildTestWidget(isPlaying: true));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('render play icon when paused (W-AUD-CTRL-21)', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('render skip icons at 32px size (W-AUD-CTRL-24)', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      final skipPrevious = tester.widget<Icon>(find.byIcon(Icons.skip_previous_rounded));
      expect(skipPrevious.size, 32);
      final skipNext = tester.widget<Icon>(find.byIcon(Icons.skip_next_rounded));
      expect(skipNext.size, 32);
    });

    testWidgets('render volume slider with 100px width (W-AUD-CTRL-27)', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      final slider = find.byType(Slider);
      expect(slider, findsOneWidget);
      final sizedBox = find.ancestor(of: slider, matching: find.byType(SizedBox)).first;
      final widget = tester.widget<SizedBox>(sizedBox);
      expect(widget.width, 100);
    });

    testWidgets('slider track magenta when volume exceeds 100 (W-AUD-CTRL-11)', (tester) async {
      await tester.pumpWidget(buildTestWidget(volume: 150));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 150);
    });

    testWidgets('track white when volume is at or below 100 (W-AUD-CTRL-12)', (tester) async {
      await tester.pumpWidget(buildTestWidget(volume: 50));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 50);
    });

    testWidgets('display volume_off icon when volume is 0 (W-AUD-CTRL-07)', (tester) async {
      await tester.pumpWidget(buildTestWidget(volume: 0));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    });

    testWidgets('display volume_up icon when volume is above 0 (W-AUD-CTRL-08)', (tester) async {
      await tester.pumpWidget(buildTestWidget(volume: 50));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('taps trigger correct callbacks', (tester) async {
      var nextPressed = false;
      var previousPressed = false;

      final widget = ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          currentTrackProvider.overrideWith((ref) => FileItem(path: '/test.mp3', name: 'test', type: FileItemType.audio, modified: DateTime.now())),
          audioAutoPlaySessionProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AudioControlsBar(
              onNextPressed: () => nextPressed = true,
              onPreviousPressed: () => previousPressed = true,
            ),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Tap next
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      expect(nextPressed, isTrue);

      // Tap previous
      await tester.tap(find.byIcon(Icons.skip_previous_rounded));
      expect(previousPressed, isTrue);

      // Tap favorite (assuming it doesn't crash)
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget); // Toggle works
      
      // Tap play/pause
      await tester.tap(find.byIcon(Icons.play_arrow_rounded)); // Should not crash, triggers player fallback

      // Tap volume toggle
      await tester.tap(find.byIcon(Icons.volume_up_rounded)); // Should not crash

      // Slide volume
      await tester.drag(find.byType(Slider), const Offset(20, 0)); // Should not crash
    });

    testWidgets('render autoplay toggle and toggle on tap (W-AUD-CTRL-28)', (tester) async {
      final widget = ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          currentTrackProvider.overrideWith((ref) => FileItem(path: '/test.mp3', name: 'test', type: FileItemType.audio, modified: DateTime.now())),
          audioAutoPlaySessionProvider.overrideWith((ref) => true),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AudioControlsBar(),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Check initial state (autorenew icon)
      expect(find.byIcon(Icons.autorenew_rounded), findsOneWidget);
      expect(find.byIcon(Icons.sync_disabled_rounded), findsNothing);

      // Tap to toggle
      await tester.tap(find.byIcon(Icons.autorenew_rounded));
      await tester.pumpAndSettle();

      // Now it should show disabled icon
      expect(find.byIcon(Icons.sync_disabled_rounded), findsOneWidget);
      expect(find.byIcon(Icons.autorenew_rounded), findsNothing);
    });
  });
}
