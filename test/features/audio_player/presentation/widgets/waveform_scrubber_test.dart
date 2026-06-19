
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/waveform_scrubber.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';

void main() {
  group('WaveformPainter Unit Tests', () {
    test('shouldRepaint returns true when progress changes (U-AUD-WAVE-01)', () {
      final p1 = WaveformPainter(progress: 0.1, barCount: 10, seed: 1, barWidth: 3, gap: 2);
      final p2 = WaveformPainter(progress: 0.2, barCount: 10, seed: 1, barWidth: 3, gap: 2);
      expect(p2.shouldRepaint(p1), isTrue);
    });

    test('shouldRepaint returns true when barCount changes (U-AUD-WAVE-02)', () {
      final p1 = WaveformPainter(progress: 0.1, barCount: 10, seed: 1, barWidth: 3, gap: 2);
      final p2 = WaveformPainter(progress: 0.1, barCount: 15, seed: 1, barWidth: 3, gap: 2);
      expect(p2.shouldRepaint(p1), isTrue);
    });

    test('shouldRepaint returns false when progress and barCount are the same (U-AUD-WAVE-03)', () {
      final p1 = WaveformPainter(progress: 0.1, barCount: 10, seed: 1, barWidth: 3, gap: 2);
      final p2 = WaveformPainter(progress: 0.1, barCount: 10, seed: 1, barWidth: 3, gap: 2);
      expect(p2.shouldRepaint(p1), isFalse);
    });

    test('shouldRepaint returns false when only seed changes (U-AUD-WAVE-04)', () {
      final p1 = WaveformPainter(progress: 0.1, barCount: 10, seed: 1, barWidth: 3, gap: 2);
      final p2 = WaveformPainter(progress: 0.1, barCount: 10, seed: 2, barWidth: 3, gap: 2);
      expect(p2.shouldRepaint(p1), isFalse);
    });
  });

  group('WaveformScrubber Widget Tests', () {
    Widget buildTestWidget({List<dynamic> overrides = const []}) {
      return ProviderScope(
        overrides: [...overrides.cast()],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 250,
                child: WaveformScrubber(fileName: 'test.mp3'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('display correct current and remaining time strings (W-AUD-WAVE-15)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        audioPositionProvider.overrideWith((ref) => Stream.value(const Duration(seconds: 65))),
        audioDurationProvider.overrideWith((ref) => Stream.value(const Duration(seconds: 125))),
      ]));

      await tester.pump();

      expect(find.text('1:05'), findsOneWidget);
      expect(find.text('-1:00'), findsOneWidget);
    });

    testWidgets('display "0:00" and "-0:00" when both position and duration are zero (W-AUD-WAVE-16)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        audioPositionProvider.overrideWith((ref) => Stream.value(Duration.zero)),
        audioDurationProvider.overrideWith((ref) => Stream.value(Duration.zero)),
      ]));

      await tester.pump();

      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('-0:00'), findsOneWidget);
    });

    testWidgets('handle zero duration safely without DivisionByZero (W-AUD-WAVE-17)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        audioPositionProvider.overrideWith((ref) => Stream.value(Duration.zero)),
        audioDurationProvider.overrideWith((ref) => Stream.value(Duration.zero)),
      ]));

      await tester.pump();

      final customPaintFinder = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is WaveformPainter);
      expect(customPaintFinder, findsOneWidget);
      
      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      final painter = customPaint.painter as WaveformPainter;
      
      expect(painter.progress, 0.0);
    });

    testWidgets('calculate bar count dynamically from width (W-AUD-WAVE-18)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        audioPositionProvider.overrideWith((ref) => Stream.value(Duration.zero)),
        audioDurationProvider.overrideWith((ref) => Stream.value(Duration.zero)),
      ]));

      await tester.pump();

      final customPaintFinder = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is WaveformPainter);
      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      final painter = customPaint.painter as WaveformPainter;
      
      expect(painter.barCount, 50);
    });

    testWidgets('render waveform inside 60px height SizedBox (W-AUD-WAVE-19)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final customPaintFinder = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is WaveformPainter);
      final sizedBoxFinder = find.ancestor(of: customPaintFinder, matching: find.byType(SizedBox)).first;
      
      final sizedBox = tester.widget<SizedBox>(sizedBoxFinder);
      expect(sizedBox.height, 60);
    });

    testWidgets('render time labels with white70 color, 12px font (W-AUD-WAVE-20)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      expect(textWidgets.length, greaterThanOrEqualTo(2));

      final style1 = textWidgets.first.style;
      expect(style1?.color, Colors.white70);
      expect(style1?.fontSize, 12);
    });

    testWidgets('prepend "-" to remaining time text (W-AUD-WAVE-21)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        audioPositionProvider.overrideWith((ref) => Stream.value(const Duration(seconds: 30))),
        audioDurationProvider.overrideWith((ref) => Stream.value(const Duration(seconds: 60))),
      ]));
      await tester.pump();
      expect(find.text('-0:30'), findsOneWidget);
    });

    testWidgets('use fileName.hashCode as seed for WaveformPainter (W-AUD-WAVE-23)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final customPaintFinder = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is WaveformPainter);
      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      final painter = customPaint.painter as WaveformPainter;
      
      expect(painter.seed, 'test.mp3'.hashCode);
    });

    testWidgets('default position/duration to Duration.zero when providers have no value (W-AUD-WAVE-24)', (tester) async {
      await tester.pumpWidget(buildTestWidget(overrides: [
        audioPositionProvider.overrideWith((ref) => const Stream.empty()),
        audioDurationProvider.overrideWith((ref) => const Stream.empty()),
      ]));
      await tester.pump();
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('-0:00'), findsOneWidget);
    });
  });
}
