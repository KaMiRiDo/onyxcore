import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/preview_container.dart';

void main() {
  testWidgets('PreviewContainer renders correctly for document', (tester) async {
    final item = FileItem(
      path: '/home/user/document.pdf',
      name: 'document.pdf',
      type: FileItemType.document,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PreviewContainer(
              item: item,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PreviewContainer), findsOneWidget);
    // As it is a pdf, it will show a center with text
    expect(find.text('PDF Preview not yet implemented'), findsOneWidget);
  });

  testWidgets('PreviewContainer renders unsupported message for unknown type', (tester) async {
    final item = FileItem(
      path: '/home/user/unknown.xyz',
      name: 'unknown.xyz',
      type: FileItemType.other,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PreviewContainer(
              item: item,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PreviewContainer), findsOneWidget);
    expect(find.text('Preview not supported for this file type'), findsOneWidget);
  });
}
