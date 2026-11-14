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

    testWidgets(
      'options container is centered and constrained to at most half viewport width on wide display',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(body: CompareSetupView(onStart: () {})),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final titleFinder = find.text('Cross-Folder Duplicate Detection');
        expect(titleFinder, findsOneWidget);

        final formBoxFinder = find.ancestor(
          of: titleFinder,
          matching: find.byType(ConstrainedBox),
        );
        expect(formBoxFinder, findsWidgets);

        var foundConstrained = false;
        for (final element in tester.widgetList<ConstrainedBox>(formBoxFinder)) {
          if (element.constraints.maxWidth <= 600.0 &&
              element.constraints.maxWidth > 0) {
            foundConstrained = true;
            break;
          }
        }
        expect(
          foundConstrained,
          isTrue,
          reason: 'Form container must have maxWidth <= 50% viewport width (600px)',
        );

        final startButtonFinder = find.widgetWithText(
          FilledButton,
          'Start Comparison',
        );
        expect(startButtonFinder, findsOneWidget);
        final buttonRect = tester.getRect(startButtonFinder);
        expect(buttonRect.width, lessThanOrEqualTo(600.0));
        expect(
          (buttonRect.center.dx - 600).abs(),
          lessThan(20.0),
          reason: 'Options container should be centered in the window',
        );
      },
    );

    testWidgets(
      'options container adapts responsively when window size reduces',
      (tester) async {
        tester.view.physicalSize = const Size(500, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(body: CompareSetupView(onStart: () {})),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Cross-Folder Duplicate Detection'), findsOneWidget);
        expect(find.text('Start Comparison'), findsOneWidget);
      },
    );

    testWidgets(
      'options and fields are enclosed in a styled card box matching app theme',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(body: CompareSetupView(onStart: () {})),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final titleFinder = find.text('Cross-Folder Duplicate Detection');
        expect(titleFinder, findsOneWidget);

        // Find the container enclosing the form Column
        final containerFinder = find.ancestor(
          of: titleFinder,
          matching: find.byType(Container),
        );
        expect(containerFinder, findsWidgets);

        // Find the specific card box with theme decoration
        Container? cardContainer;
        for (final element in tester.widgetList<Container>(containerFinder)) {
          final dec = element.decoration;
          if (dec is BoxDecoration &&
              dec.borderRadius != null &&
              dec.color != null &&
              dec.boxShadow != null) {
            cardContainer = element;
            break;
          }
        }

        expect(
          cardContainer,
          isNotNull,
          reason: 'Options must be in a decorated card container with background, border, radius, and shadow',
        );
        final decoration = cardContainer!.decoration! as BoxDecoration;
        expect(decoration.color, isNotNull);
        expect(decoration.borderRadius, isNotNull);
        expect(decoration.border, isNotNull);
        expect(decoration.boxShadow, isNotEmpty);
      },
    );
  });
}
