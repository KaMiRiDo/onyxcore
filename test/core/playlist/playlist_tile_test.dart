import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/playlist/playlist_tile.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

void main() {
  group('MediaTile', () {
    final testItem = FileItem(
      name: 'test_song.mp3',
      path: '/path/to/test_song.mp3',
      type: FileItemType.audio,
      modified: DateTime.now(),
      sizeBytes: 1024,
    );

    Widget buildTile({
      bool isActive = false,
      bool isSelected = false,
      String subtitle = 'Subtitle',
      VoidCallback? onTap,
      VoidCallback? onDoubleTap,
      void Function(TapDownDetails details, BuildContext context)? onSecondaryTapDown,
      Widget? activeIndicator,
      Widget? coverArt,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: MediaTile(
            item: testItem,
            isActive: isActive,
            isSelected: isSelected,
            subtitle: subtitle,
            defaultMediaIcon: Icons.music_note,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onSecondaryTapDown: onSecondaryTapDown,
            activeIndicator: activeIndicator,
            coverArt: coverArt,
          ),
        ),
      );
    }

    testWidgets('renders basic properties', (tester) async {
      await tester.pumpWidget(buildTile(subtitle: '128 kbps'));

      expect(find.text('test_song.mp3'), findsOneWidget);
      expect(find.text('128 kbps'), findsOneWidget);
      expect(find.byIcon(Icons.music_note), findsOneWidget);
    });

    testWidgets('renders active state with activeIndicator', (tester) async {
      await tester.pumpWidget(buildTile(
        isActive: true,
        activeIndicator: const Icon(Icons.play_arrow),
      ));

      // The text color might change, but the text should still be there
      expect(find.text('test_song.mp3'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('renders custom cover art', (tester) async {
      await tester.pumpWidget(buildTile(
        coverArt: const Icon(Icons.album),
      ));

      expect(find.byIcon(Icons.album), findsOneWidget);
      // The default icon shouldn't be found
      expect(find.byIcon(Icons.music_note), findsNothing);
    });

    testWidgets('triggers onTap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(buildTile(
        onTap: () => tapped = true,
      ));

      await tester.tap(find.byType(MediaTile));
      expect(tapped, isTrue);
    });

    testWidgets('triggers onDoubleTap', (tester) async {
      bool doubleTapped = false;
      await tester.pumpWidget(buildTile(
        onDoubleTap: () => doubleTapped = true,
      ));

      final center = tester.getCenter(find.byType(MediaTile));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pumpAndSettle();

      expect(doubleTapped, isTrue);
    });

    testWidgets('triggers onSecondaryTapDown', (tester) async {
      bool secondaryTapped = false;
      await tester.pumpWidget(buildTile(
        onSecondaryTapDown: (details, context) => secondaryTapped = true,
      ));

      final gesture = tester.widget<GestureDetector>(find.byType(GestureDetector).first);
      gesture.onSecondaryTapDown?.call(TapDownDetails());

      expect(secondaryTapped, isTrue);
    });

    testWidgets('renders folder default icon', (tester) async {
      final folderItem = FileItem(
        name: 'Folder',
        path: '/Folder',
        type: FileItemType.folder,
        modified: DateTime.now(),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MediaTile(
            item: folderItem,
            isActive: false,
            isSelected: false,
            subtitle: 'Folder Subtitle',
            defaultMediaIcon: Icons.music_note,
          ),
        ),
      ));

      expect(find.byIcon(Icons.folder_rounded), findsOneWidget);
    });

    testWidgets('renders thumbnail image and handles errorBuilder', (tester) async {
      final itemWithThumb = FileItem(
        name: 'test_song.mp3',
        path: '/path/to/test_song.mp3',
        thumbnailPath: '/invalid/path/thumb.jpg',
        type: FileItemType.audio,
        modified: DateTime.now(),
        sizeBytes: 1024,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MediaTile(
            item: itemWithThumb,
            isActive: false,
            isSelected: false,
            subtitle: 'Subtitle',
            defaultMediaIcon: Icons.music_note,
          ),
        ),
      ));

      // It should try to render the image
      expect(find.byType(Image), findsOneWidget);
      
      // We can't easily wait for the file read to fail in a generic pump,
      // but providing an invalid path will invoke the errorBuilder.
      // The default icon (music_note) should also be present because 
      // of `hasImage: true` overlay and the errorBuilder rendering it again.
      expect(find.byIcon(Icons.music_note), findsWidgets);
    });
  });
}
