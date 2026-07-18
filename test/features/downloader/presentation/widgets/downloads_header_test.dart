// ignore_for_file: avoid_dynamic_calls
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_header.dart';

class MockCurrentPathNotifier extends CurrentPathNotifier {
  @override
  String build() => '/test/path';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadsHeader Tests', () {
    final log = <MethodCall>[];

    setUp(log.clear);

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('persistent_viewer'), null);
    });

    testWidgets('W-HDR-01 to W-HDR-03: Open in Window button', (WidgetTester tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('onyxcore/window_manager'),
        (MethodCall methodCall) async {
          log.add(methodCall);
          return 1;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentPathProvider.overrideWith(MockCurrentPathNotifier.new),
            downloadsPanelViewProvider.overrideWith((ref) => DownloadsPanelView.tasks),
          ],
          child: const MaterialApp(home: Scaffold(body: DownloadsHeader())),
        ),
      );

      // W-HDR-01: Rendered
      expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.open_in_new_rounded));
      await tester.pumpAndSettle();
      
      expect(log.length, 1);
      expect(log.first.method, 'create_window');
      
      // We know ViewerType.downloader no longer implies maximize: true
      expect(log.first.arguments['maximize'], false);
    });
  });
}
