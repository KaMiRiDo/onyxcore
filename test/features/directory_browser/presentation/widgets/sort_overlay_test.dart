import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sort_overlay.dart';

void main() {
  testWidgets('SortOverlay shows correctly and returns selected option', (tester) async {
    SortOption? selectedOption;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                SortOverlay.show(
                  context: context,
                  buttonPosition: const Offset(100, 100),
                  buttonSize: const Size(100, 40),
                  currentOption: SortOption.aToZ,
                  onSelected: (option) {
                    selectedOption = option;
                  },
                );
              },
              child: const Text('Show Sort'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Sort'));
    await tester.pumpAndSettle();

    expect(find.text('A-Z'), findsOneWidget);
    expect(find.text('Z-A'), findsOneWidget);
    expect(find.text('First Modified'), findsOneWidget);

    // Tap another option
    await tester.tap(find.text('Size (Large to Small)'));
    await tester.pumpAndSettle();

    expect(selectedOption, SortOption.sizeLargeToSmall);
    
    // Check overlay is gone
    expect(find.text('Size (Large to Small)'), findsNothing);
  });

  testWidgets('SortOverlay hides on tap outside', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                SortOverlay.show(
                  context: context,
                  buttonPosition: const Offset(100, 100),
                  buttonSize: const Size(100, 40),
                  currentOption: SortOption.aToZ,
                  onSelected: (option) {},
                );
              },
              child: const Text('Show Sort'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Sort'));
    await tester.pumpAndSettle();

    expect(find.text('A-Z'), findsOneWidget);

    // Tap outside (at 10,10 which is far from 100,100)
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('A-Z'), findsNothing);
  });
}
