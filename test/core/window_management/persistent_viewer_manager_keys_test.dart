import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PersistentViewerManager Keys', () {
    testWidgets('Widgets are created with viewId as key, not file path', (tester) async {
      await tester.pumpWidget(Container());
      final ctx = tester.element(find.byType(Container));
      const viewId = 999;
      
      final file = FileItem(
        path: '/test/media.mp4', 
        name: 'media.mp4', 
        type: FileItemType.video, 
        modified: DateTime.now(), 
        sizeBytes: 100
      );
      
      final params = WindowParams(
        viewerType: ViewerType.video,
        file: file,
      );

      final widget = PersistentViewerManager.buildView(viewId) as ValueListenableBuilder<WindowParams?>;
      final rootWidget = widget.builder(ctx, params, null) as ProviderScope;
      final app = rootWidget.child as MaterialApp;
      final scaffold = app.home! as Scaffold;
      final content = scaffold.body!;
      
      // Expected failure before implementation: it is currently ValueKey(params.file.path)
      expect(content.key, equals(const ValueKey(viewId)), reason: 'Key should be viewId to preserve widget state on file change');
    });
  });
}
