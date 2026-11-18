import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/filter_settings.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/filter_overlay.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(0.5)),
          child: child!,
        );
      },
      home: Scaffold(body: child),
    );
  }

  testWidgets('FilterOverlay allows selecting Broken Items in File Type dropdown', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    FilterSettings? appliedSettings;

    await tester.pumpWidget(
      buildTestApp(
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () {
                FilterOverlay.show(
                  context: context,
                  position: const Offset(100, 100),
                  initialSettings: const FilterSettings(),
                  onSelected: (settings) {
                    appliedSettings = settings;
                  },
                );
              },
              child: const Text('Show Filter'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Filter'));
    await tester.pumpAndSettle();

    // Select 'Files' to show FILE TYPE
    await tester.tap(find.text('Any').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Files').last);
    await tester.pumpAndSettle();

    expect(find.text('FILE TYPE'), findsOneWidget);

    // Open File Type dropdown
    await tester.tap(find.text('Any').last);
    await tester.pumpAndSettle();

    // Check that 'Broken Items' is in the dropdown
    expect(find.text('Broken Items'), findsOneWidget);

    // Tap 'Broken Items'
    await tester.tap(find.text('Broken Items'));
    await tester.pumpAndSettle();

    // Apply Filter
    await tester.tap(find.text('Apply Filter'));
    await tester.pumpAndSettle();

    expect(appliedSettings?.brokenOnly, isTrue);
  });
}
