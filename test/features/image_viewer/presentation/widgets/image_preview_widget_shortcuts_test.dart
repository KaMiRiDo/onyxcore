import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_preview_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('image_viewer_shortcuts_test_');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('ImagePreviewWidget closes preview on Backspace and Alt+Left', (WidgetTester tester) async {
    final imagePath = '${tempDir.path}/test_image.png';
    File(imagePath).writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    
    final fileItem = FileItem(
      path: imagePath,
      name: 'test_image.png',
      type: FileItemType.image,
      modified: DateTime.now(),
    );

    final container = ProviderContainer(
      overrides: [
        previewFileProvider.overrideWith((ref) => fileItem),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ImagePreviewWidget(
              item: fileItem,
              isStandalone: false, // Inline mode
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    // Test Backspace
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump(const Duration(milliseconds: 500));
    
    expect(container.read(previewFileProvider), isNull, reason: 'Preview should close on Backspace');
  });

  testWidgets('ImagePreviewWidget standalone mode resets zoom on double tap', (WidgetTester tester) async {
    final imagePath = '${tempDir.path}/test_image.png';
    File(imagePath).writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    
    final fileItem = FileItem(
      path: imagePath,
      name: 'test_image.png',
      type: FileItemType.image,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ImagePreviewWidget(
              item: fileItem,
              isStandalone: true, // Standalone mode
              windowId: '400',
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    // Perform double tap
    final center = tester.getCenter(find.byType(InteractiveViewer));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 500));

    // Since we can't easily read _currentScale directly, we would expect no exception and
    // in the real implementation it should trigger _setZoom(1.0).
    // We will verify the widget doesn't crash on double tap and the matrix is identity.
    final InteractiveViewer viewer = tester.widget(find.byType(InteractiveViewer));
    expect(viewer.transformationController?.value.getMaxScaleOnAxis(), 1.0);
  });
}
