import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/video_thumbnail_preview.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

void main() {
  testWidgets('VideoThumbnailPreview handles unplayable video gracefully', (tester) async {
    final item = FileItem(
      path: '/path/to/nonexistent/video.mp4',
      name: 'video.mp4',
      type: FileItemType.video,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoThumbnailPreview(
            item: item,
            zoom: 1.0,
          ),
        ),
      ),
    );

    expect(find.byType(VideoThumbnailPreview), findsOneWidget);
  });
}
