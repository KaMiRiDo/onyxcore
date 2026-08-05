import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_media_grid.dart';

void main() {
  Widget buildGrid({
    required List<MediaGroup> groups,
    MediaGroup? currentGroup,
  }) {
    final focusNode = FocusNode();
    return MaterialApp(
      home: Scaffold(
        body: StandaloneWindowMediaGrid(
          listPath: 'default',
          isTrashView: false,
          groups: groups,
          currentGroup: currentGroup,
          selectedIndices: const {},
          downloadingImageIndices: const {},
          getConfig: (g) => DownloadConfig(),
          isHydratingItem: (url) => false,
          onTapItem: (index, {bool isCtrl = false, bool isShift = false}) {},
          onDoubleTapItem: (index, group) {},
          onRestoreTrashItem: (index) {},
          onFormatChanged: (index, format) {},
          onFilterChanged: (index, filter) {},
          onStartDownload: (index) {},
          mainFocusNode: focusNode,
          matchTargetFormat: (formats, target) => null,
          getHeight: (res) => 1080,
          getFormatBytes: (item, format, config) => format?.filesize,
          onTagItem: (index, tag) {},
        ),
      ),
    );
  }

  testWidgets('renders file size on top right badge when available', (tester) async {
    final group = MediaGroup(
      originalUrl: 'https://example.com/item',
      items: [
        MediaInfo(
          id: 'item1',
          title: 'Photo with size',
          originalUrl: 'https://example.com/item1',
          isVideo: false,
          filesize: 10 * 1024 * 1024, // 10 MB
        ),
      ],
    );

    await tester.pumpWidget(buildGrid(groups: [group]));
    await tester.pumpAndSettle();

    expect(find.text('10.00MB'), findsOneWidget);
  });

  testWidgets('renders Unknown and NEVER resolution on badge when size is missing for image', (tester) async {
    final group = MediaGroup(
      originalUrl: 'https://example.com/item',
      items: [
        MediaInfo(
          id: 'item2',
          title: 'Photo without size',
          originalUrl: 'https://example.com/item2',
          isVideo: false,
          width: 1920,
          height: 1080,
        ),
      ],
    );

    await tester.pumpWidget(buildGrid(groups: [group]));
    await tester.pumpAndSettle();

    // Should NOT show resolution 1920x1080
    expect(find.text('1920x1080'), findsNothing);
    // Should show Unknown
    expect(find.text('Unknown'), findsOneWidget);
  });

  testWidgets('renders Unknown and NEVER duration on badge when size is missing for video', (tester) async {
    final group = MediaGroup(
      originalUrl: 'https://example.com/item',
      items: [
        MediaInfo(
          id: 'item3',
          title: 'Video without size',
          originalUrl: 'https://example.com/item3',
          duration: 125, // 2:05
        ),
      ],
    );

    await tester.pumpWidget(buildGrid(groups: [group]));
    await tester.pumpAndSettle();

    // Should NOT show duration 2:05
    expect(find.text('2:05'), findsNothing);
    // Should show Unknown
    expect(find.text('Unknown'), findsOneWidget);
  });

  testWidgets('renders combined file size for multi-item group in root view', (tester) async {
    final group = MediaGroup(
      originalUrl: 'https://example.com/multi',
      items: [
        MediaInfo(
          id: 'itemA',
          title: 'Photo A',
          originalUrl: 'https://example.com/itemA',
          isVideo: false,
          filesize: 2 * 1024 * 1024, // 2 MB
        ),
        MediaInfo(
          id: 'itemB',
          title: 'Photo B',
          originalUrl: 'https://example.com/itemB',
          isVideo: false,
          filesize: 3 * 1024 * 1024, // 3 MB
        ),
      ],
    );

    await tester.pumpWidget(buildGrid(groups: [group]));
    await tester.pumpAndSettle();

    // Combined size 2MB + 3MB = 5.00MB
    expect(find.text('5.00MB'), findsOneWidget);
  });

  testWidgets('renders individual file size in sub-item view', (tester) async {
    final itemA = MediaInfo(
      id: 'subA',
      title: 'Sub Item A',
      originalUrl: 'https://example.com/subA',
      isVideo: false,
      filesize: (2.5 * 1024 * 1024).toInt(), // 2.5 MB
    );
    final group = MediaGroup(
      originalUrl: 'https://example.com/group',
      items: [itemA],
    );

    await tester.pumpWidget(buildGrid(
      groups: [group],
      currentGroup: group,
    ));
    await tester.pumpAndSettle();

    expect(find.text('2.50MB'), findsOneWidget);
  });
}
