import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_active_downloads.dart';

void main() {
  testWidgets('StandaloneWindowActiveDownloads renders active downloads correctly', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    bool cancelAllTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StandaloneWindowActiveDownloads(
            tasks: [],
            onCancelAll: () => cancelAllTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Active Downloads'), findsOneWidget);
    expect(find.text('No active downloads'), findsOneWidget);
  });
}

void _noop() {}
