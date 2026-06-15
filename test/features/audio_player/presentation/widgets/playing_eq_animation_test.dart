
import 'package:hive/hive.dart' as import_hive;
import 'dart:io' as import_io;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/playing_eq_animation.dart';
import 'package:onyxcore/core/theme/app_colors.dart';

void main() {
  setUpAll(() {
    try {
      import_hive.Hive.init(import_io.Directory.systemTemp.path);
    } catch (_) {}
  });

  Widget buildTestWidget() {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: PlayingEqAnimation(),
        ),
      ),
    );
  }

  group('PlayingEqAnimation Widget Tests', () {
    testWidgets('render exactly 3 animated bars (W-AUD-EQ-01)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // The _EqBar is private, but we can find its Container by its specific width/color
      final containers = tester.widgetList<Container>(find.byType(Container)).where((container) {
        final box = container.decoration as BoxDecoration?;
        return box?.color == AppColors.magenta && container.constraints?.maxWidth == 3.0;
      });

      expect(containers.length, 3);
    });

    testWidgets('render within 16x16 SizedBox (W-AUD-EQ-05)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final sizedBoxFinder = find.byType(SizedBox).first;
      final sizedBox = tester.widget<SizedBox>(sizedBoxFinder);
      expect(sizedBox.width, 16);
      expect(sizedBox.height, 16);
    });

    testWidgets('align bars to bottom with spaceEvenly distribution (W-AUD-EQ-06)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final rowFinder = find.byType(Row).first;
      final row = tester.widget<Row>(rowFinder);
      
      expect(row.mainAxisAlignment, MainAxisAlignment.spaceEvenly);
      expect(row.crossAxisAlignment, CrossAxisAlignment.end);
    });

    testWidgets('render bars with AppColors.magenta color (W-AUD-EQ-08)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, AppColors.magenta);
    });

    testWidgets('render bars with 3px width (W-AUD-EQ-09)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxWidth, 3);
    });

    testWidgets('render bars with 2px border radius (W-AUD-EQ-10)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(2));
    });

    testWidgets('bars animate and have varying heights (W-AUD-EQ-11, W-AUD-EQ-12)', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Let animation run a bit
      await tester.pump(const Duration(milliseconds: 100));

      final containers = tester.widgetList<Container>(find.byType(Container)).where((container) {
        final box = container.decoration as BoxDecoration?;
        return box?.color == AppColors.magenta;
      }).toList();

      expect(containers.length, 3);

      final height1 = containers[0].constraints?.maxHeight ?? 0;
      final height2 = containers[1].constraints?.maxHeight ?? 0;
      final height3 = containers[2].constraints?.maxHeight ?? 0;

      // Heights should be bound between 4 and 12
      expect(height1, inInclusiveRange(4.0, 12.0));
      expect(height2, inInclusiveRange(4.0, 12.0));
      expect(height3, inInclusiveRange(4.0, 12.0));

      // Due to phase shifts, at any given time (except very specific phases) they should have different heights
      expect(height1 == height2 && height2 == height3, isFalse);
    });
  });
}
