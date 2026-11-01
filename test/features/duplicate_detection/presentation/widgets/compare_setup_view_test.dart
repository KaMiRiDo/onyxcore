import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/compare_config_notifier.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/compare_setup_view.dart';

void main() {
  group('CompareSetupView', () {
    testWidgets('renders folder selectors, category chips, and start button', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CompareSetupView(onStart: () {})),
          ),
        ),
      );

      expect(find.text('Source Folder'), findsOneWidget);
      expect(find.text('Destination Folder'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Images'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Start Comparison'), findsOneWidget);
    });

    testWidgets('start button is disabled when configuration is invalid', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: CompareSetupView(onStart: () {})),
          ),
        ),
      );

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('allows changing category', (tester) async {
      late WidgetRef refCapture;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  refCapture = ref;
                  return CompareSetupView(onStart: () {});
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Images'));
      await tester.pump();

      expect(
        refCapture.read(compareConfigProvider).category,
        ComparisonCategory.images,
      );
    });
  });
}
