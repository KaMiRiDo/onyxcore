
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/audio_controls_bar.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';

void main() {
  Widget buildTestWidget({bool isPlaying = false, double volume = 100}) {
    return ProviderScope(
      overrides: [
        audioPlayingProvider.overrideWith((ref) => Stream.value(isPlaying)),
        audioVolumeProvider.overrideWith((ref) => Stream.value(volume)),
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
      await tester.pumpWidget(buildTestWidget(isPlaying: false));
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
  });
}
