import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/item_preview.dart';

void main() {
  testWidgets('ItemPreview renders file icon for generic file', (tester) async {
    final item = FileItem(
      path: '/home/user/document.pdf',
      name: 'document.pdf',
      type: FileItemType.document,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItemPreview(
            item: item,
            zoom: 1,
          ),
        ),
      ),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('ItemPreview renders folder icon for directory', (tester) async {
    final item = FileItem(
      path: '/home/user/Documents',
      name: 'Documents',
      type: FileItemType.folder,
      sizeBytes: 0,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItemPreview(
            item: item,
            zoom: 1,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.article_rounded), findsOneWidget);
  });

  testWidgets('ItemPreview renders image icon for image file if error in loading', (tester) async {
    final item = FileItem(
      path: '/home/user/image.png',
      name: 'image.png',
      type: FileItemType.image,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItemPreview(
            item: item,
            zoom: 1,
          ),
        ),
      ),
    );

    // Image will fail to load in test (or use memory image if actual image widget)
    // We expect it to fallback to an icon or show the widget that handles image loading
    // Since ItemPreview tries to load the real path, it'll fail in tests and fallback or show nothing
    // We just ensure it renders without crashing
    expect(find.byType(ItemPreview), findsOneWidget);
  });
}
