import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/pages/gallery_page.dart';

void main() {
  testWidgets('Global Keyboard Shortcuts Propagation', (WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        downloadsPanelOpenProvider.overrideWith((ref) => true),
      ],
    );
    addTearDown(container.dispose);
    
    final listFocusNode = FocusNode();
    final urlFocusNode = FocusNode();
    final externalFocusNode = FocusNode();
    final panelFocusScopeNode = FocusScopeNode();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
                final dOpen = container.read(downloadsPanelOpenProvider);
                if (!dOpen) {
                  container.read(downloadsPanelOpenProvider.notifier).state = true;
                  container.read(backgroundPanelOpenProvider.notifier).state = false;
                  urlFocusNode.requestFocus();
                } else {
                  final isFocused = urlFocusNode.hasFocus;
                  if (!isFocused) {
                    urlFocusNode.requestFocus();
                  } else {
                    container.read(downloadsPanelOpenProvider.notifier).state = false;
                  }
                }
              },
            },
            child: Scaffold(
              body: Column(
                children: [
                  Focus(
                    focusNode: externalFocusNode,
                    child: const SizedBox(height: 100, width: 100, child: Text('External')),
                  ),
                  Expanded(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) {
                        if (!panelFocusScopeNode.hasFocus) {
                          panelFocusScopeNode.requestFocus();
                        }
                      },
                      child: FocusScope(
                        node: panelFocusScopeNode,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            panelFocusScopeNode.requestFocus();
                          },
                          child: Listener(
                            onPointerDown: (_) {
                              listFocusNode.requestFocus();
                            },
                            child: Focus(
                              focusNode: listFocusNode,
                              child: Container(
                                color: Colors.blue,
                                width: 200,
                                height: 200,
                                child: Column(
                                  children: [
                                    TextField(
                                      focusNode: urlFocusNode,
                                      autofocus: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(downloadsPanelOpenProvider), isTrue);

    // Click inside the list focus area (inside the panel)
    await tester.tap(find.byType(Container).last);
    await tester.pump(const Duration(milliseconds: 100));
    
    expect(listFocusNode.hasFocus, isTrue, reason: 'List node should be focused after tap');
    expect(urlFocusNode.hasFocus, isFalse, reason: 'URL node should NOT be focused after tap');

    // Press Ctrl+D
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump(const Duration(milliseconds: 100));

    // Shortcut should STILL trigger and focus the URL!
    expect(urlFocusNode.hasFocus, isTrue, reason: 'Ctrl+D should focus URL when list node is focused');
    
    // Press Ctrl+D again
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(downloadsPanelOpenProvider), isFalse, reason: 'Ctrl+D should close panel');
  });
}
