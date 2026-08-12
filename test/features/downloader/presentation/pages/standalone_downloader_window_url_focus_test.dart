import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/features/downloader/presentation/pages/standalone_downloader_window.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloader_readiness_provider.dart';

class FixedDownloaderReadinessNotifier extends DownloaderReadinessNotifier {
  @override
  Future<DownloaderReadinessState> build() async {
    return const DownloaderReadinessState(isReady: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('StandaloneDownloaderWindow focuses URL text field on urlFocusTrigger',
      (tester) async {
    const windowId = 999;
    final urlFocusTrigger = PersistentViewerManager.getUrlFocusTrigger(windowId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloaderReadinessProvider.overrideWith(FixedDownloaderReadinessNotifier.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: StandaloneDownloaderWindow(
              windowId: windowId,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    // Trigger URL focus
    urlFocusTrigger.value++;
    await tester.pump(const Duration(milliseconds: 50));

    // Verify the TextField has focus
    final textFieldFinder = find.byType(TextField);
    expect(textFieldFinder, findsWidgets);

    final editableText = tester.widget<EditableText>(
      find.descendant(of: textFieldFinder.first, matching: find.byType(EditableText)),
    );
    expect(editableText.focusNode.hasFocus, isTrue);
  });
}
