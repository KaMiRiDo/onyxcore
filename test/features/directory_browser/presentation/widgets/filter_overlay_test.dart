import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/filter_overlay.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/filter_settings.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

void main() {
  Widget buildTestApp(Widget child) {
    return MaterialApp(
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(0.5),
          ),
          child: child!,
        );
      },
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets('FilterOverlay renders correctly and applies filters', (tester) async {
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
                  onApply: (settings) {
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

    expect(find.text('Advanced Filters'), findsOneWidget);
    expect(find.text('ITEM TYPE'), findsOneWidget);
    // FILE TYPE is only visible when ITEM TYPE is 'Files Only'
    expect(find.text('FILE TYPE'), findsNothing);

    // Tap on ITEM TYPE 'Any' to show dropdown
    await tester.tap(find.text('Any').first);
    await tester.pumpAndSettle();

    // Select 'Folders'
    await tester.tap(find.text('Folders').last);
    await tester.pumpAndSettle();

    // Apply Filter
    await tester.tap(find.text('Apply Filter'));
    await tester.pumpAndSettle();

    expect(appliedSettings?.foldersOnly, true);
  });

  testWidgets('FilterOverlay file type dropdown logic', (tester) async {
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
                  onApply: (settings) {
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

    // First change ITEM TYPE to 'Files Only' to reveal FILE TYPE
    await tester.tap(find.text('Any').first);
    await tester.pumpAndSettle();
    
    // Tap 'Files'
    await tester.tap(find.text('Files').last);
    await tester.pumpAndSettle();

    expect(find.text('FILE TYPE'), findsOneWidget);

    // Open File Type dropdown - there should be an 'Any' text now for the FILE TYPE selector
    await tester.tap(find.text('Any').last);
    await tester.pumpAndSettle();

    // Select 'Image'
    await tester.tap(find.text('Image'));
    await tester.pumpAndSettle();

    // Tap Apply without selecting extension, should show error
    await tester.tap(find.text('Apply Filter'));
    await tester.pumpAndSettle();

    expect(find.text('At least one extension must be selected'), findsOneWidget);

    // Tap Select All
    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();

    // Apply Filter
    await tester.tap(find.text('Apply Filter'));
    await tester.pumpAndSettle();

    expect(appliedSettings?.category, FileItemType.image);
    expect(appliedSettings?.extensions.contains('.jpg'), true);
  });

  testWidgets('FilterOverlay hides on tap outside and close button', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
                  onApply: (settings) {},
                );
              },
              child: const Text('Show Filter'),
            ),
          ),
        ),
      ),
    );

    // Test tap outside
    await tester.tap(find.text('Show Filter'));
    await tester.pumpAndSettle();
    
    // Tap outside the overlay. The button is in the center, overlay is at (100,100).
    // Tap at bottom right corner
    await tester.tapAt(const Offset(1800, 900));
    await tester.pumpAndSettle();
    expect(find.text('Advanced Filters'), findsNothing);

    // Test close button
    await tester.tap(find.text('Show Filter'));
    await tester.pumpAndSettle();

    final closeButton = find.byIcon(Icons.close_rounded);
    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    expect(find.text('Advanced Filters'), findsNothing);
  });
}
