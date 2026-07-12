import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_header.dart';

void main() {
  testWidgets('StandaloneWindowHeader renders and interacts correctly', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final urlController = TextEditingController();
    final urlFocusNode = FocusNode();
    final gradientController = AnimationController(vsync: const TestVSync());
    var fetchCalled = false;
    var selectedEngine = 'auto';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StandaloneWindowHeader(
            urlController: urlController,
            urlFocusNode: urlFocusNode,
            gradientController: gradientController,
            onFetch: () => fetchCalled = true,
            selectedEngine: selectedEngine,
            onEngineChanged: (engine) => selectedEngine = engine,
          ),
        ),
      ),
    );

    // Verify text field exists
    expect(find.byType(TextField), findsOneWidget);
    
    // Verify fetch button exists and triggers callback
    expect(find.text('Fetch'), findsOneWidget);
    await tester.tap(find.text('Fetch'));
    expect(fetchCalled, isTrue);

    // Verify settings button exists
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}
